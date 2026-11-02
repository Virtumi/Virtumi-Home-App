import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/models.dart';
import '../../application/new_device_wizard_controller.dart';
import '../../application/new_device_wizard_state.dart';
import '../../models/wizard_found_device.dart';
import '../../models/wizard_step.dart';
import '../../services/ble_device_service.dart';
import '../../services/network_info_service.dart';
import 'steps/wizard_date_time_step.dart';
import 'steps/wizard_general_step.dart';
import 'steps/wizard_location_step.dart';
import 'steps/wizard_password_step.dart';
import 'steps/wizard_update_step.dart';

class WizardStepContent extends StatefulWidget {
  const WizardStepContent({
    super.key,
    required this.state,
    required this.controller,
  });

  final NewDeviceWizardState state;
  final NewDeviceWizardController controller;

  @override
  State<WizardStepContent> createState() => _WizardStepContentState();
}

class _WizardStepContentState extends State<WizardStepContent> {
  late final TextEditingController _passwordController;
  late final TextEditingController _broadcastController;
  late final TextEditingController _portController;
  late final TextEditingController _ssidController;
  late final TextEditingController _wifiPasswordController;
  late final TextEditingController _manualIpController;
  late final TextEditingController _manualPortController;
  late final TextEditingController _accountPasswordController;

  var _obscurePassword = true;
  var _obscureAccountPassword = true;
  var _waitCountdown = wifiPostConnectWaitSec;
  var _waitStarted = false;

  @override
  void initState() {
    super.initState();
    _passwordController =
        TextEditingController(text: widget.state.devicePassword);
    _broadcastController = TextEditingController(
      text: widget.state.broadcastIp ?? NetworkInfoService.fallbackBroadcast,
    );
    _portController =
        TextEditingController(text: widget.state.targetPort.toString());
    _ssidController = TextEditingController();
    _wifiPasswordController = TextEditingController();
    _manualIpController = TextEditingController();
    _manualPortController = TextEditingController(text: '6000');
    _accountPasswordController = TextEditingController();
  }

  @override
  void didUpdateWidget(covariant WizardStepContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.step != widget.state.step) {
      if (widget.state.step == WizardStep.btWait && !_waitStarted) {
        _waitStarted = true;
        _startWaitCountdown();
      }
    }
    if (widget.state.broadcastIp != null &&
        widget.state.broadcastIp != oldWidget.state.broadcastIp) {
      _broadcastController.text = widget.state.broadcastIp!;
    }
  }

  Future<void> _startWaitCountdown() async {
    setState(() => _waitCountdown = wifiPostConnectWaitSec);
    for (var i = wifiPostConnectWaitSec; i > 0; i--) {
      if (!mounted || widget.state.step != WizardStep.btWait) return;
      await Future<void>.delayed(const Duration(seconds: 1));
      if (mounted) setState(() => _waitCountdown = i - 1);
    }
    if (mounted && widget.state.step == WizardStep.btWait) {
      await widget.controller.checkBleWifiStatus(afterWait: false);
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _broadcastController.dispose();
    _portController.dispose();
    _ssidController.dispose();
    _wifiPasswordController.dispose();
    _manualIpController.dispose();
    _manualPortController.dispose();
    _accountPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return switch (widget.state.step) {
      WizardStep.password => _passwordStep(),
      WizardStep.searchType => _searchTypeStep(),
      WizardStep.lanScan => _lanScanStep(),
      WizardStep.btPick => _btPickStep(),
      WizardStep.btWifi => _btWifiStep(),
      WizardStep.btWait => _btWaitStep(),
      WizardStep.btResolve => _btResolveStep(),
      WizardStep.location => WizardLocationStep(
          state: widget.state,
          controller: widget.controller,
        ),
      WizardStep.dateTime => WizardDateTimeStep(
          state: widget.state,
          controller: widget.controller,
        ),
      WizardStep.general => WizardGeneralStep(
          state: widget.state,
          controller: widget.controller,
        ),
      WizardStep.update => WizardUpdateStep(
          state: widget.state,
          controller: widget.controller,
        ),
      WizardStep.passwordOpt => WizardPasswordStep(
          state: widget.state,
          controller: widget.controller,
        ),
      WizardStep.supabase => _supabaseStep(),
      WizardStep.credentials => _credentialsStep(),
      WizardStep.done => _doneStep(),
    };
  }

  Widget _passwordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeaderCard(
          title: 'Geräte-Passwort',
          subtitle: 'Passwort des ESP32-Geräts (nicht Ihr Account-Passwort)',
          icon: Symbols.lock,
          accent: AppColors.accentSky,
        ),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'Geräte-Passwort',
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Symbols.visibility : Symbols.visibility_off,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          onChanged: widget.controller.setDevicePassword,
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: widget.state.isBusy ? null : widget.controller.goToSearchType,
          child: const Text('Weiter'),
        ),
      ],
    );
  }

  Widget _searchTypeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeaderCard(
          title: 'Suchart',
          subtitle: 'Wie möchten Sie das Gerät finden?',
          icon: Symbols.radar,
          accent: AppColors.accentSky,
        ),
        const SizedBox(height: AppSpacing.lg),
        _SearchTypeCard(
          icon: Symbols.wifi,
          title: 'Lokales Netzwerk',
          subtitle: 'Broadcast IP & Port',
          color: AppColors.accentGreen,
          onTap: widget.controller.chooseLan,
        ),
        const SizedBox(height: AppSpacing.md),
        _SearchTypeCard(
          icon: Symbols.bluetooth,
          title: 'Bluetooth',
          subtitle: 'Verbinden, WLAN, warten',
          color: AppColors.accentBlue,
          onTap: widget.controller.chooseBluetooth,
        ),
      ],
    );
  }

  Widget _lanScanStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeaderCard(
          title: 'Netzwerk scannen',
          subtitle: 'UDP-Broadcast im lokalen WiFi',
          icon: Symbols.wifi_find,
          accent: AppColors.accentGreen,
        ),
        if (widget.state.localIp != null)
          Text('Lokale IP: ${widget.state.localIp}'),
        TextField(
          controller: _broadcastController,
          decoration: const InputDecoration(labelText: 'Broadcast-IP'),
        ),
        TextField(
          controller: _portController,
          decoration: const InputDecoration(labelText: 'Port'),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          onPressed: widget.state.isBusy
              ? null
              : () {
                  final port =
                      (int.tryParse(_portController.text.trim()) ?? 6000)
                          .clamp(1, 65535);
                  widget.controller.scanLan(
                    broadcastIp: _broadcastController.text.trim(),
                    port: port,
                  );
                },
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accentGreen,
            foregroundColor: AppColors.onPrimary,
          ),
          icon: const Icon(Symbols.wifi_find, fill: 1, size: 22),
          label: const Text('Netzwerk scannen'),
        ),
        if (widget.state.discoveredDevices.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          const AppSectionLabel('Gefundene Geräte'),
          for (var i = 0; i < widget.state.discoveredDevices.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.cardGap),
            _DiscoveredLanDeviceCard(
              device: widget.state.discoveredDevices[i],
              isFlashing: widget.state.flashingDeviceKeys.contains(
                widget.state.discoveredDevices[i].flashKey,
              ),
              isBusy: widget.state.isBusy,
              onSelect: () => widget.controller.selectLanDevice(
                widget.state.discoveredDevices[i],
              ),
              onToggleFlash: () => widget.controller.toggleFlashDevice(
                widget.state.discoveredDevices[i],
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _btPickStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeaderCard(
          title: 'Bluetooth-Gerät',
          subtitle: 'ESP32 in der Nähe auswählen',
          icon: Symbols.bluetooth_searching,
          accent: AppColors.accentBlue,
        ),
        OutlinedButton.icon(
          onPressed:
              widget.state.isBusy ? null : widget.controller.startBleScan,
          icon: const Icon(Symbols.search),
          label: const Text('Bluetooth scannen'),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final result in widget.state.scanResults)
          ListTile(
            leading: const Icon(Symbols.bluetooth),
            title: Text(
              isEmsTypeName(result.device.platformName) ||
                      isEmsStoredName(result.device.platformName)
                  ? emsDisplayName
                  : (result.device.platformName.isNotEmpty
                      ? result.device.platformName
                      : 'Unbekanntes Gerät'),
            ),
            subtitle: Text(result.device.remoteId.str),
            onTap: widget.state.isBusy
                ? null
                : () => widget.controller.connectBleDevice(result.device),
          ),
      ],
    );
  }

  Widget _btWifiStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeaderCard(
          title: 'WLAN konfigurieren',
          subtitle: 'Zugangsdaten an das Gerät senden',
          icon: Symbols.wifi_password,
          accent: AppColors.accentBlue,
        ),
        TextField(
          controller: _ssidController,
          decoration: const InputDecoration(labelText: 'WLAN-SSID'),
        ),
        TextField(
          controller: _wifiPasswordController,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'WLAN-Passwort'),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: widget.state.isBusy
              ? null
              : () => widget.controller.sendBleWifi(
                    _ssidController.text.trim(),
                    _wifiPasswordController.text,
                  ),
          child: const Text('WLAN senden'),
        ),
      ],
    );
  }

  Widget _btWaitStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeaderCard(
          title: 'WLAN-Verbindung',
          subtitle: 'Warte $_waitCountdown s …',
          icon: Symbols.hourglass_top,
          accent: AppColors.accentBlue,
        ),
        OutlinedButton(
          onPressed: widget.state.isBusy
              ? null
              : () => widget.controller.checkBleWifiStatus(),
          child: const Text('Status prüfen'),
        ),
      ],
    );
  }

  Widget _btResolveStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeaderCard(
          title: 'IP ermitteln',
          subtitle: 'Fallback wenn keine IP per WLAN-Status',
          icon: Symbols.lan,
          accent: AppColors.accentBlue,
        ),
        FilledButton(
          onPressed:
              widget.state.isBusy ? null : widget.controller.resolveBleViaProtocol1,
          child: const Text('Geräteinfo per Bluetooth (Protokoll 1)'),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _manualIpController,
          decoration: const InputDecoration(labelText: 'Manuelle IPv4'),
        ),
        TextField(
          controller: _manualPortController,
          decoration: const InputDecoration(labelText: 'Port'),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton(
          onPressed: widget.state.isBusy
              ? null
              : () {
                  final port =
                      int.tryParse(_manualPortController.text.trim()) ?? 6000;
                  widget.controller.resolveManualIp(
                    _manualIpController.text.trim(),
                    port,
                  );
                },
          child: const Text('IP per UDP abfragen'),
        ),
      ],
    );
  }

  Widget _supabaseStep() {
    final device = widget.state.selectedDevice;
    final loc = widget.state.deviceLocation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeaderCard(
          title: 'In Supabase speichern',
          subtitle: 'Gerät in der Cloud registrieren',
          icon: Symbols.cloud_upload,
          accent: AppColors.accentSky,
        ),
        if (device != null && loc != null) ...[
          ListTile(
            title: const Text('Name'),
            subtitle: Text(
              isEmsTypeName(device.devicetype)
                  ? emsDisplayName
                  : loc.deviceName,
            ),
          ),
          ListTile(title: const Text('IP'), subtitle: Text(device.ipAddress)),
          ListTile(title: const Text('MAC'), subtitle: Text(device.macAddress)),
          ListTile(
            title: const Text('Standort'),
            subtitle: Text(
              '${loc.houseName} / ${loc.floorName} / ${loc.roomName}',
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed:
              widget.state.isBusy ? null : widget.controller.saveToSupabase,
          child: const Text('In Supabase speichern'),
        ),
      ],
    );
  }

  Widget _credentialsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeaderCard(
          title: 'Cloud-Anmeldedaten',
          subtitle: 'Supabase-Account-Passwort ans Gerät senden (Protokoll 7)',
          icon: Symbols.cloud_sync,
          accent: AppColors.accentSky,
        ),
        TextField(
          controller: _accountPasswordController,
          obscureText: _obscureAccountPassword,
          decoration: InputDecoration(
            labelText: 'Supabase-Account-Passwort',
            suffixIcon: IconButton(
              icon: Icon(_obscureAccountPassword
                  ? Symbols.visibility
                  : Symbols.visibility_off),
              onPressed: () => setState(
                () => _obscureAccountPassword = !_obscureAccountPassword,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: widget.state.isBusy
              ? null
              : () => widget.controller.sendCredentials(
                    _accountPasswordController.text,
                  ),
          child: const Text('Anmeldedaten senden'),
        ),
      ],
    );
  }

  Widget _doneStep() {
    final loc = widget.state.deviceLocation;
    return SectionHeaderCard(
      title: 'Gerät erfolgreich hinzugefügt!',
      subtitle: loc != null
          ? '${isEmsStoredName(loc.deviceName) || isEmsTypeName(widget.state.selectedDevice?.devicetype) ? emsDisplayName : loc.deviceName} · ${loc.houseName} / ${loc.roomName}'
          : 'Fertig',
      icon: Symbols.check_circle,
      accent: AppColors.accentGreen,
      filled: true,
    );
  }
}

class _DiscoveredLanDeviceCard extends StatelessWidget {
  const _DiscoveredLanDeviceCard({
    required this.device,
    required this.isFlashing,
    required this.isBusy,
    required this.onSelect,
    required this.onToggleFlash,
  });

  final WizardFoundDevice device;
  final bool isFlashing;
  final bool isBusy;
  final VoidCallback onSelect;
  final VoidCallback onToggleFlash;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isEmsTypeName(device.devicetype)
                ? emsDisplayName
                : device.devicename,
            style: context.text.titleSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            isEmsTypeName(device.devicetype)
                ? device.ipAddress
                : '${device.devicetype} · ${device.ipAddress}',
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'MAC: ${device.macAddress} · ${device.hostname}',
            style: context.text.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.gutter),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: isBusy ? null : onSelect,
                  icon: const Icon(Symbols.check_circle, size: 20),
                  label: const Text('Auswählen'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: isFlashing
                    ? FilledButton.icon(
                        onPressed: isBusy ? null : onToggleFlash,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accentAmber,
                          foregroundColor: context.colors.onSurface,
                        ),
                        icon: const Icon(Symbols.flare, fill: 1, size: 20),
                        label: const Text('Blinkt'),
                      )
                    : FilledButton.icon(
                        onPressed: isBusy ? null : onToggleFlash,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.surfaceContainerHigh,
                          foregroundColor: context.colors.primary,
                        ),
                        icon: const Icon(Symbols.flare, size: 20),
                        label: const Text('Blinken'),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SearchTypeCard extends StatelessWidget {
  const _SearchTypeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          IconBox(icon: icon, color: color, size: AppSizes.iconBoxMd),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleSmall),
                Text(subtitle, style: context.text.bodySmall),
              ],
            ),
          ),
          Icon(Symbols.chevron_right, color: context.colors.onSurfaceVariant),
        ],
      ),
    );
  }
}