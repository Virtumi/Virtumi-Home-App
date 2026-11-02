import 'dart:async';
import 'dart:io';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';
import '../../../shared/data/supabase/mappers/config_mappers.dart';
import '../../../shared/models/models.dart';
import '../../../shared/providers/data_providers.dart';
import '../models/wizard_found_device.dart';
import '../models/wizard_step.dart';
import '../repositories/device_setup_repository.dart';
import '../services/ble_device_service.dart';
import '../services/network_info_service.dart';
import '../services/udp_device_service.dart';
import 'new_device_wizard_state.dart';

final networkInfoServiceProvider = Provider<NetworkInfoService>((ref) {
  return NetworkInfoService();
});

final udpDeviceServiceProvider = Provider<UdpDeviceService>((ref) {
  return UdpDeviceService();
});

final bleDeviceServiceProvider = Provider<BleDeviceService>((ref) {
  return BleDeviceService();
});

final deviceSetupRepositoryProvider = Provider<DeviceSetupRepository>((ref) {
  return DeviceSetupRepository(ref.watch(supabaseClientProvider));
});

final newDeviceWizardControllerProvider =
    NotifierProvider<NewDeviceWizardController, NewDeviceWizardState>(
      NewDeviceWizardController.new,
    );

class NewDeviceWizardController extends Notifier<NewDeviceWizardState> {
  @override
  NewDeviceWizardState build() => const NewDeviceWizardState();

  UdpDeviceService get _udp => ref.read(udpDeviceServiceProvider);
  BleDeviceService get _ble => ref.read(bleDeviceServiceProvider);
  NetworkInfoService get _network => ref.read(networkInfoServiceProvider);
  DeviceSetupRepository get _setup => ref.read(deviceSetupRepositoryProvider);
  SupabaseClient get _client => ref.read(supabaseClientProvider);

  DeviceLocation _withStoredEmsName(
    WizardFoundDevice device,
    DeviceLocation location,
  ) {
    if (!isEmsTypeName(device.devicetype)) return location;
    return location.copyWith(deviceName: emsStoredName);
  }

  DeviceLocation _defaultLocation(WizardFoundDevice device) {
    final location = deviceLocationDefaults(
      deviceName: isEmsTypeName(device.devicetype)
          ? emsStoredName
          : device.devicename,
      home: device.home.isNotEmpty ? device.home : 'Mein Zuhause',
      floor: device.floor.isNotEmpty ? device.floor : 'Erdgeschoss',
      room: device.room.isNotEmpty ? device.room : 'Wohnzimmer',
    );
    return _withStoredEmsName(device, location);
  }

  Future<void> requestPermissions() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    await [
      Permission.locationWhenInUse,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();
  }

  void setDevicePassword(String value) {
    state = state.copyWith(devicePassword: value, clearError: true);
  }

  void goToSearchType() {
    if (state.devicePassword.trim().isEmpty) {
      state = state.copyWith(error: 'Bitte Geräte-Passwort eingeben');
      return;
    }
    state = state.copyWith(step: WizardStep.searchType, clearError: true);
  }

  Future<void> chooseLan() async {
    state = state.copyWith(
      step: WizardStep.lanScan,
      usedLanPath: true,
      clearError: true,
      isBusy: true,
    );
    try {
      final localIp = await _network.getLocalIp();
      final broadcastIp = await _network.getBroadcastIp();
      state = state.copyWith(
        localIp: localIp,
        broadcastIp: broadcastIp,
        isBusy: false,
      );
    } catch (e) {
      state = state.copyWith(isBusy: false, error: e.toString());
    }
  }

  void chooseBluetooth() {
    state = state.copyWith(
      step: WizardStep.btPick,
      usedLanPath: false,
      clearError: true,
    );
  }

  Future<void> scanLan({required String broadcastIp, required int port}) async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final devices = await _udp.discoverDevices(
        broadcastIp: broadcastIp,
        port: port,
        deviceCode: state.devicePassword.trim(),
        maxTimeout: const Duration(seconds: 5),
        quietPeriod: const Duration(milliseconds: 600),
      );
      state = state.copyWith(
        discoveredDevices: devices,
        flashingDeviceKeys: const {},
        broadcastIp: broadcastIp,
        targetPort: port,
        isBusy: false,
        error: devices.isEmpty
            ? 'Keine Geräte gefunden. Passwort, Broadcast-IP und WLAN prüfen.'
            : null,
      );
    } catch (e) {
      state = state.copyWith(isBusy: false, error: e.toString());
    }
  }

  Future<void> toggleFlashDevice(WizardFoundDevice device) async {
    final key = device.flashKey;
    final activate = !state.flashingDeviceKeys.contains(key);
    final keys = Set<String>.from(state.flashingDeviceKeys);
    if (activate) {
      keys.add(key);
    } else {
      keys.remove(key);
    }
    state = state.copyWith(flashingDeviceKeys: keys, clearError: true);

    try {
      await _udp.flashDevice(
        targetIp: device.ipAddress,
        port: device.port,
        deviceCode: state.devicePassword.trim(),
        flashState: activate ? 1 : 0,
      );
    } catch (e) {
      final reverted = Set<String>.from(state.flashingDeviceKeys);
      if (activate) {
        reverted.remove(key);
      } else {
        reverted.add(key);
      }
      state = state.copyWith(
        flashingDeviceKeys: reverted,
        error: 'Blinken fehlgeschlagen: $e',
      );
    }
  }

  Future<void> _stopFlashingDevices([
    Iterable<WizardFoundDevice>? devices,
  ]) async {
    final targets =
        devices?.toList() ??
        state.discoveredDevices
            .where((d) => state.flashingDeviceKeys.contains(d.flashKey))
            .toList();
    if (targets.isEmpty) return;

    for (final device in targets) {
      try {
        await _udp.flashDevice(
          targetIp: device.ipAddress,
          port: device.port,
          deviceCode: state.devicePassword.trim(),
          flashState: 0,
        );
      } catch (_) {}
    }
    final keys = Set<String>.from(state.flashingDeviceKeys);
    for (final device in targets) {
      keys.remove(device.flashKey);
    }
    state = state.copyWith(flashingDeviceKeys: keys);
  }

  void selectLanDevice(WizardFoundDevice device) {
    unawaited(_stopFlashingDevices([device]));
    state = state.copyWith(
      selectedDevice: device,
      targetPort: device.port,
      deviceLocation: _defaultLocation(device),
      locationPreviousStep: WizardStep.lanScan,
      step: WizardStep.location,
      clearError: true,
    );
  }

  Future<void> startBleScan() async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await requestPermissions();
      await FlutterBluePlus.stopScan();

      final sub = FlutterBluePlus.scanResults.listen((results) {
        state = state.copyWith(scanResults: List.of(results));
      });

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 12));
      while (FlutterBluePlus.isScanningNow) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      await sub.cancel();

      state = state.copyWith(isBusy: false);
    } catch (e) {
      state = state.copyWith(isBusy: false, error: e.toString());
    }
  }

  Future<void> connectBleDevice(BluetoothDevice device) async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await _ble.stopScan();
      final connection = await _ble.connect(device);
      state = state.copyWith(
        bleConnection: connection,
        step: WizardStep.btWifi,
        isBusy: false,
      );
    } catch (e) {
      state = state.copyWith(isBusy: false, error: e.toString());
    }
  }

  Future<void> sendBleWifi(String ssid, String password) async {
    final connection = state.bleConnection;
    if (connection == null) return;
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await _ble.sendWifi(
        connection.characteristic,
        state.devicePassword.trim(),
        ssid,
        password,
      );
      state = state.copyWith(step: WizardStep.btWait, isBusy: false);
    } catch (e) {
      state = state.copyWith(isBusy: false, error: e.toString());
    }
  }

  Future<void> checkBleWifiStatus({bool afterWait = false}) async {
    final connection = state.bleConnection;
    if (connection == null) return;

    if (afterWait) {
      await Future<void>.delayed(
        const Duration(seconds: wifiPostConnectWaitSec),
      );
    }

    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final status = await _ble.readWifiStatus(
        connection.characteristic,
        state.devicePassword.trim(),
      );

      if (status.isConnected) {
        var device = status.toFoundDevice(port: state.targetPort);
        if (device.currentVersion.isEmpty || device.serialNumber.isEmpty) {
          try {
            final info = WizardFoundDevice.fromJson(
              await _ble.getDeviceInfo(
                connection.characteristic,
                state.devicePassword.trim(),
              ),
            );
            device = device.withIdentityFrom(info);
          } catch (_) {}
        }

        await _ble.stopBluetooth(
          connection.characteristic,
          state.devicePassword.trim(),
        );
        await connection.disconnect();
        state = state.copyWith(
          selectedDevice: device,
          deviceLocation: _defaultLocation(device),
          locationPreviousStep: WizardStep.btWait,
          step: WizardStep.location,
          clearBleConnection: true,
          isBusy: false,
        );
      } else {
        state = state.copyWith(
          step: WizardStep.btResolve,
          isBusy: false,
          error: 'WLAN nicht verbunden (wifistate=${status.wifistate})',
        );
      }
    } catch (e) {
      state = state.copyWith(
        step: WizardStep.btResolve,
        isBusy: false,
        error: e.toString(),
      );
    }
  }

  Future<void> resolveBleViaProtocol1() async {
    final connection = state.bleConnection;
    if (connection == null) return;
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final json = await _ble.getDeviceInfo(
        connection.characteristic,
        state.devicePassword.trim(),
      );
      await _ble.stopBluetooth(
        connection.characteristic,
        state.devicePassword.trim(),
      );
      await connection.disconnect();

      final device = WizardFoundDevice.fromJson(json);
      if (device.ipAddress.isEmpty) {
        throw StateError('Keine IP in BLE-Antwort');
      }

      state = state.copyWith(
        selectedDevice: device,
        targetPort: device.port,
        deviceLocation: _defaultLocation(device),
        locationPreviousStep: WizardStep.btResolve,
        step: WizardStep.location,
        clearBleConnection: true,
        isBusy: false,
      );
    } catch (e) {
      state = state.copyWith(isBusy: false, error: e.toString());
    }
  }

  Future<void> resolveManualIp(String ip, int port) async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final json = await _udp.readDeviceInfo(
        targetIp: ip,
        port: port,
        deviceCode: state.devicePassword.trim(),
      );
      final device = WizardFoundDevice.fromJson({
        ...json,
        'ip_address': ip,
        'port': port,
      });
      await state.bleConnection?.disconnect();

      state = state.copyWith(
        selectedDevice: device,
        targetPort: port,
        deviceLocation: _defaultLocation(device),
        locationPreviousStep: WizardStep.btResolve,
        step: WizardStep.location,
        clearBleConnection: true,
        isBusy: false,
      );
    } catch (e) {
      state = state.copyWith(isBusy: false, error: e.toString());
    }
  }

  Future<void> loadLocationStep() async {
    final device = state.selectedDevice;
    if (device == null || device.ipAddress.isEmpty) return;

    state = state.copyWith(isBusy: true, clearError: true);
    try {
      var selected = device;
      if (selected.macAddress.isEmpty) {
        final info = await _udp.readDeviceInfo(
          targetIp: selected.ipAddress,
          port: state.targetPort,
          deviceCode: state.devicePassword.trim(),
        );
        selected = WizardFoundDevice.fromJson({
          ...info,
          'ip_address': selected.ipAddress,
        }).withIdentityFrom(selected);
      }

      final json = await _udp.readLocation(
        targetIp: selected.ipAddress,
        port: state.targetPort,
        deviceCode: state.devicePassword.trim(),
      );

      final loaded = mapDeviceLocation(json);
      state = state.copyWith(
        selectedDevice: selected,
        deviceLocation: _withStoredEmsName(
          selected,
          loaded.deviceName.isNotEmpty ? loaded : _defaultLocation(selected),
        ),
        isBusy: false,
      );
    } catch (_) {
      state = state.copyWith(
        deviceLocation: _defaultLocation(device),
        isBusy: false,
      );
    }
  }

  void updateDeviceLocation(DeviceLocation location) {
    final device = state.selectedDevice;
    state = state.copyWith(
      deviceLocation: device == null
          ? location
          : _withStoredEmsName(device, location),
    );
  }

  Future<void> saveLocationAndContinue() async {
    final device = state.selectedDevice;
    final loc = state.deviceLocation;
    if (device == null || loc == null) return;

    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await _udp.writeLocation(
        targetIp: device.ipAddress,
        port: state.targetPort,
        payload: deviceLocationUdpWritePayload(
          state.devicePassword.trim(),
          loc,
        ),
      );
      state = state.copyWith(step: WizardStep.dateTime, isBusy: false);
      await loadDateTimeStep();
    } catch (e) {
      state = state.copyWith(isBusy: false, error: e.toString());
    }
  }

  Future<void> loadDateTimeStep() async {
    final device = state.selectedDevice;
    if (device == null) return;
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final json = await _udp.readDateTime(
        targetIp: device.ipAddress,
        port: state.targetPort,
        deviceCode: state.devicePassword.trim(),
      );
      state = state.copyWith(
        dateTimeConfig: mapDateTimeConfig(json),
        isBusy: false,
      );
    } catch (_) {
      state = state.copyWith(
        dateTimeConfig: const DateTimeConfig(),
        isBusy: false,
      );
    }
  }

  void updateDateTimeConfig(DateTimeConfig config) {
    state = state.copyWith(dateTimeConfig: config);
  }

  Future<void> saveDateTimeAndContinue() async {
    final device = state.selectedDevice;
    final config = state.dateTimeConfig;
    if (device == null || config == null) return;
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await _udp.writeDateTime(
        targetIp: device.ipAddress,
        port: state.targetPort,
        payload: dateTimeUdpWritePayload(state.devicePassword.trim(), config),
      );
      state = state.copyWith(step: WizardStep.general, isBusy: false);
      await loadGeneralStep();
    } catch (e) {
      state = state.copyWith(isBusy: false, error: e.toString());
    }
  }

  Future<void> loadGeneralStep() async {
    final device = state.selectedDevice;
    if (device == null) return;
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final json = await _udp.readGeneral(
        targetIp: device.ipAddress,
        port: state.targetPort,
        deviceCode: state.devicePassword.trim(),
      );
      state = state.copyWith(
        generalConfig: mapGeneralConfig(json),
        isBusy: false,
      );
    } catch (_) {
      state = state.copyWith(
        generalConfig: const GeneralConfig(),
        isBusy: false,
      );
    }
  }

  void updateGeneralConfig(GeneralConfig config) {
    state = state.copyWith(generalConfig: config);
  }

  Future<void> saveGeneralAndContinue() async {
    final device = state.selectedDevice;
    final config = state.generalConfig;
    if (device == null || config == null) return;
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await _udp.writeGeneral(
        targetIp: device.ipAddress,
        port: state.targetPort,
        payload: generalUdpWritePayload(state.devicePassword.trim(), config),
      );
      state = state.copyWith(step: WizardStep.update, isBusy: false);
      await loadUpdateStep();
    } catch (e) {
      state = state.copyWith(isBusy: false, error: e.toString());
    }
  }

  Future<void> loadUpdateStep() async {
    final device = state.selectedDevice;
    if (device == null) return;
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final json = await _udp.readUpdate(
        targetIp: device.ipAddress,
        port: state.targetPort,
        deviceCode: state.devicePassword.trim(),
      );
      state = state.copyWith(
        updateConfig: mapUpdateConfigFromUdp(json),
        isBusy: false,
      );
    } catch (_) {
      state = state.copyWith(updateConfig: const UpdateConfig(), isBusy: false);
    }
  }

  void updateUpdateConfig(UpdateConfig config) {
    state = state.copyWith(updateConfig: config);
  }

  Future<void> saveUpdateAndContinue() async {
    final device = state.selectedDevice;
    final config = state.updateConfig;
    if (device == null || config == null) return;
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await _udp.writeUpdate(
        targetIp: device.ipAddress,
        port: state.targetPort,
        payload: updateUdpWritePayload(state.devicePassword.trim(), config),
      );
      state = state.copyWith(step: WizardStep.passwordOpt, isBusy: false);
    } catch (e) {
      state = state.copyWith(isBusy: false, error: e.toString());
    }
  }

  void setChangeDevicePassword(bool value) {
    state = state.copyWith(changeDevicePassword: value);
  }

  void setNewPasswords(String newPassword, String confirm) {
    state = state.copyWith(
      newDevicePassword: newPassword,
      confirmDevicePassword: confirm,
    );
  }

  Future<void> savePasswordOptAndContinue() async {
    final device = state.selectedDevice;
    if (device == null) return;

    if (state.changeDevicePassword) {
      final newPw = state.newDevicePassword.trim();
      final confirm = state.confirmDevicePassword.trim();
      if (newPw.isEmpty || newPw.length > 16) {
        state = state.copyWith(
          error: 'Neues Passwort: 1–16 Zeichen erforderlich',
        );
        return;
      }
      if (newPw != confirm) {
        state = state.copyWith(error: 'Passwörter stimmen nicht überein');
        return;
      }

      state = state.copyWith(isBusy: true, clearError: true);
      try {
        await _udp.changeDevicePassword(
          targetIp: device.ipAddress,
          port: state.targetPort,
          deviceCode: state.devicePassword.trim(),
          newPassword: newPw,
        );
        state = state.copyWith(
          devicePassword: newPw,
          step: WizardStep.supabase,
          isBusy: false,
        );
      } catch (e) {
        state = state.copyWith(isBusy: false, error: e.toString());
      }
    } else {
      state = state.copyWith(step: WizardStep.supabase, clearError: true);
    }
  }

  void skipPasswordOpt() {
    state = state.copyWith(step: WizardStep.supabase, clearError: true);
  }

  Future<void> saveToSupabase() async {
    final device = state.selectedDevice;
    final loc = state.deviceLocation;
    if (device == null || loc == null) return;

    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final settings = await ref.read(appSettingsProvider.future);
      final deviceId = await _setup.saveUdpDevice(
        deviceCode: state.devicePassword.trim(),
        selectedDevice: device,
        deviceLocation: loc,
        connectionMode: settings?.connectionMode ?? 'cloud',
      );
      state = state.copyWith(
        savedDeviceId: deviceId,
        step: WizardStep.credentials,
        isBusy: false,
      );
    } catch (e) {
      state = state.copyWith(isBusy: false, error: e.toString());
    }
  }

  Future<void> sendCredentials(String accountPassword) async {
    final device = state.selectedDevice;
    final user = _client.auth.currentUser;
    if (device == null || user == null) {
      state = state.copyWith(error: 'Nicht angemeldet oder kein Gerät');
      return;
    }

    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await _udp.sendCloudCredentials(
        targetIp: device.ipAddress,
        port: state.targetPort,
        deviceCode: state.devicePassword.trim(),
        userEmail: user.email ?? '',
        userPassword: accountPassword,
        userId: user.id,
      );
      state = state.copyWith(step: WizardStep.done, isBusy: false);
      Future.microtask(() => ref.invalidate(housesProvider));
    } catch (e) {
      state = state.copyWith(isBusy: false, error: e.toString());
    }
  }

  Future<void> goBack() async {
    switch (state.step) {
      case WizardStep.password:
        return;
      case WizardStep.searchType:
        state = state.copyWith(step: WizardStep.password, clearError: true);
      case WizardStep.lanScan:
        await _stopFlashingDevices();
        state = state.copyWith(step: WizardStep.searchType, clearError: true);
      case WizardStep.btPick:
        await _ble.stopScan();
        state = state.copyWith(step: WizardStep.searchType, clearError: true);
      case WizardStep.btWifi:
        state = state.copyWith(step: WizardStep.btPick, clearError: true);
      case WizardStep.btWait:
        state = state.copyWith(step: WizardStep.btWifi, clearError: true);
      case WizardStep.btResolve:
        state = state.copyWith(step: WizardStep.btWait, clearError: true);
      case WizardStep.location:
        state = state.copyWith(
          step: state.locationPreviousStep,
          clearError: true,
        );
      case WizardStep.dateTime:
        state = state.copyWith(step: WizardStep.location, clearError: true);
      case WizardStep.general:
        state = state.copyWith(step: WizardStep.dateTime, clearError: true);
      case WizardStep.update:
        state = state.copyWith(step: WizardStep.general, clearError: true);
      case WizardStep.passwordOpt:
        state = state.copyWith(step: WizardStep.update, clearError: true);
      case WizardStep.supabase:
        state = state.copyWith(step: WizardStep.passwordOpt, clearError: true);
      case WizardStep.credentials:
        state = state.copyWith(step: WizardStep.supabase, clearError: true);
      case WizardStep.done:
        return;
    }
  }

  Future<void> cleanup() async {
    await _ble.stopScan();
    await state.bleConnection?.disconnect();
  }
}
