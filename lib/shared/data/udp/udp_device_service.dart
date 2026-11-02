import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../features/add_device/models/wizard_found_device.dart';
import 'udp_read_echo.dart';

/// Native UDP communication with Virtumi ESP32 devices (port 6000).
class UdpDeviceService {
  static const defaultPort = 6000;

  /// Broadcast scan: protocol 0 → reply 1, plus legacy discover fallback.
  Future<List<WizardFoundDevice>> discoverDevices({
    required String broadcastIp,
    required int port,
    required String deviceCode,
    Duration maxTimeout = const Duration(seconds: 30),
    Duration quietPeriod = const Duration(milliseconds: 600),
  }) async {
    if (!Platform.isAndroid && !Platform.isIOS && !Platform.isWindows) {
      return [];
    }

    final results = <String, WizardFoundDevice>{};
    RawDatagramSocket? socket;
    Timer? maxTimer;
    Timer? quietTimer;

    void addDevice(WizardFoundDevice device) {
      if (device.ipAddress.isEmpty) return;
      results[device.ipAddress] = device;
    }

    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;

      final completer = Completer<void>();
      late StreamSubscription<RawSocketEvent> sub;

      void finish() {
        if (completer.isCompleted) return;
        completer.complete();
      }

      void scheduleQuietFinish() {
        quietTimer?.cancel();
        quietTimer = Timer(quietPeriod, finish);
      }

      sub = socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = socket!.receive();
        if (datagram == null) return;

        try {
          final json =
              jsonDecode(utf8.decode(datagram.data)) as Map<String, dynamic>;
          if (isBareReadRequestEcho(json, 1)) return;
          final device = WizardFoundDevice.fromJson(
            json,
            fallbackIp: datagram.address.address,
          );
          final previousCount = results.length;
          addDevice(device);
          if (results.length > previousCount) {
            scheduleQuietFinish();
          }
        } catch (_) {}
      });

      void sendBroadcast(String targetIp, Map<String, dynamic> message) {
        final data = utf8.encode(jsonEncode(message));
        socket!.send(data, InternetAddress(targetIp), port);
      }

      final protocolScan = {
        'protocol_nr': 0,
        'reply_protocol': 1,
        'code': deviceCode,
      };
      const legacyDiscover = {'cmd': 'discover'};

      void sendAllProbes() {
        sendBroadcast(broadcastIp, protocolScan);
        sendBroadcast(broadcastIp, legacyDiscover);
        if (!Platform.isIOS) {
          sendBroadcast('255.255.255.255', protocolScan);
          sendBroadcast('255.255.255.255', legacyDiscover);
        }
      }

      sendAllProbes();
      Timer(const Duration(milliseconds: 350), () {
        if (socket == null || completer.isCompleted) return;
        sendAllProbes();
      });
      if (Platform.isIOS) {
        Timer(const Duration(milliseconds: 900), () {
          if (socket == null || completer.isCompleted) return;
          sendAllProbes();
        });
      }

      maxTimer = Timer(maxTimeout, finish);

      await completer.future;
      await sub.cancel();
    } finally {
      quietTimer?.cancel();
      maxTimer?.cancel();
      socket?.close();
    }

    return results.values.toList();
  }

  /// Unicast send and wait for first matching JSON response.
  Future<Map<String, dynamic>> sendAndWait({
    required String targetIp,
    required int port,
    required Map<String, dynamic> message,
    required bool Function(Map<String, dynamic>) matches,
    int? expectedReplyProtocol,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);

      final completer = Completer<Map<String, dynamic>>();
      late StreamSubscription<RawSocketEvent> sub;

      sub = socket.listen((event) {
        if (event != RawSocketEvent.read || completer.isCompleted) return;
        final datagram = socket!.receive();
        if (datagram == null) return;
        if (datagram.address.address != targetIp) return;

        try {
          final json =
              jsonDecode(utf8.decode(datagram.data)) as Map<String, dynamic>;
          if (expectedReplyProtocol != null &&
              isBareReadRequestEcho(json, expectedReplyProtocol)) {
            return;
          }
          if (matches(json)) {
            completer.complete(json);
          }
        } catch (_) {}
      });

      final data = utf8.encode(jsonEncode(message));
      socket.send(data, InternetAddress(targetIp), port);

      final timer = Timer(timeout, () {
        if (!completer.isCompleted) {
          completer.completeError(
            TimeoutException('UDP-Timeout nach ${timeout.inSeconds}s'),
          );
        }
      });

      try {
        return await completer.future;
      } finally {
        timer.cancel();
        await sub.cancel();
      }
    } finally {
      socket?.close();
    }
  }

  /// Alias for [sendFireAndForget] (legacy wizard API).
  Future<void> sendUnicast({
    required String targetIp,
    required int port,
    required Map<String, dynamic> message,
  }) =>
      sendFireAndForget(targetIp: targetIp, port: port, message: message);

  /// Fire-and-forget unicast (no reply expected).
  Future<void> sendFireAndForget({
    required String targetIp,
    required int port,
    required Map<String, dynamic> message,
  }) async {
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      final data = utf8.encode(jsonEncode(message));
      socket.send(data, InternetAddress(targetIp), port);
    } finally {
      socket?.close();
    }
  }

  Future<Map<String, dynamic>> readProtocol({
    required String targetIp,
    required int port,
    required String deviceCode,
    required int replyProtocol,
    int? command,
    int? ledIndex,
    Duration timeout = const Duration(seconds: 15),
    bool Function(Map<String, dynamic>)? matches,
  }) {
    final message = <String, dynamic>{
      'protocol_nr': 0,
      'reply_protocol': replyProtocol,
      'code': deviceCode,
    };
    if (command != null) message['command'] = command;
    if (ledIndex != null) message['led_index'] = ledIndex;

    return sendAndWait(
      targetIp: targetIp,
      port: port,
      message: message,
      expectedReplyProtocol: replyProtocol,
      timeout: timeout,
      matches: matches ??
          (json) {
            if (isBareReadRequestEcho(json, replyProtocol)) return false;
            return json['reply_protocol'] == replyProtocol ||
                json.containsKey('ok') ||
                json.containsKey('success');
          },
    );
  }

  Future<Map<String, dynamic>> writeProtocol({
    required String targetIp,
    required int port,
    required Map<String, dynamic> payload,
    required int expectedReplyProtocol,
    Duration timeout = const Duration(seconds: 10),
    bool Function(Map<String, dynamic>)? matches,
  }) {
    return sendAndWait(
      targetIp: targetIp,
      port: port,
      message: payload,
      expectedReplyProtocol: expectedReplyProtocol,
      timeout: timeout,
      matches: matches ??
          (json) {
            if (expectedReplyProtocol != 0 &&
                isBareReadRequestEcho(json, expectedReplyProtocol)) {
              return false;
            }
            return json['reply_protocol'] == expectedReplyProtocol ||
                json.containsKey('ok') ||
                json.containsKey('success') ||
                json.isNotEmpty;
          },
    );
  }

  Future<void> flashDevice({
    required String targetIp,
    required int port,
    required String deviceCode,
    required int flashState,
  }) {
    return sendFireAndForget(
      targetIp: targetIp,
      port: port,
      message: {
        'protocol_nr': 9,
        'reply_protocol': 0,
        'code': deviceCode,
        'flash_state': flashState,
      },
    );
  }

  /// Climate sample. Firmware expects protocol 10, not the generic read (0).
  Future<Map<String, dynamic>> readEmsSensor({
    required String targetIp,
    required int port,
    required String deviceCode,
    Duration timeout = const Duration(seconds: 3),
  }) {
    return sendAndWait(
      targetIp: targetIp,
      port: port,
      timeout: timeout,
      expectedReplyProtocol: 10,
      message: {
        'protocol_nr': 10,
        'reply_protocol': 10,
        'code': deviceCode,
      },
      matches: (json) {
        if (isBareReadRequestEcho(json, 10)) return false;
        return json.containsKey('iaq') ||
            json.containsKey('accuracy') ||
            json.containsKey('raw_temperature') ||
            json.containsKey('raw_pressure') ||
            json.containsKey('raw_humidity') ||
            json.containsKey('co2_equivalent');
      },
    );
  }

  Future<Map<String, dynamic>> readDeviceInfo({
    required String targetIp,
    required int port,
    required String deviceCode,
    Duration timeout = const Duration(seconds: 15),
  }) {
    return readProtocol(
      targetIp: targetIp,
      port: port,
      deviceCode: deviceCode,
      replyProtocol: 1,
      timeout: timeout,
      matches: (json) =>
          json.containsKey('devicename') && json.containsKey('ip_address'),
    );
  }

  Future<void> sendButtonPress({
    required String targetIp,
    required int port,
    required String deviceCode,
    required int command,
  }) {
    return sendFireAndForget(
      targetIp: targetIp,
      port: port,
      message: {
        'protocol_nr': 3,
        'reply_protocol': 0,
        'code': deviceCode,
        'command': command,
      },
    );
  }

  Future<Map<String, dynamic>> readNetworkCommand({
    required String targetIp,
    required int port,
    required String deviceCode,
    required int command,
  }) {
    return readProtocol(
      targetIp: targetIp,
      port: port,
      deviceCode: deviceCode,
      replyProtocol: 8,
      command: command,
      timeout: const Duration(seconds: 15),
      matches: _networkMatches(command),
    );
  }

  Future<Map<String, dynamic>> writeNetworkCommand({
    required String targetIp,
    required int port,
    required Map<String, dynamic> payload,
  }) {
    return writeProtocol(
      targetIp: targetIp,
      port: port,
      payload: payload,
      expectedReplyProtocol: 8,
      timeout: const Duration(seconds: 15),
      matches: _networkMatches(payload['command'] as int? ?? 1),
    );
  }

  Future<void> pingNetworkCommand({
    required String targetIp,
    required int port,
    required String deviceCode,
    required int command,
    Duration timeout = const Duration(seconds: 2),
  }) async {
    await readNetworkCommand(
      targetIp: targetIp,
      port: port,
      deviceCode: deviceCode,
      command: command,
    );
  }

  Future<Map<String, dynamic>> readMqtt({
    required String targetIp,
    required int port,
    required String deviceCode,
  }) {
    return readProtocol(
      targetIp: targetIp,
      port: port,
      deviceCode: deviceCode,
      replyProtocol: 4,
      timeout: const Duration(seconds: 10),
      matches: (json) =>
          json.containsKey('mqtt_active') || json.containsKey('mqtt_server'),
    );
  }

  Future<Map<String, dynamic>> readVirtumiCloud({
    required String targetIp,
    required int port,
    required String deviceCode,
  }) {
    return readProtocol(
      targetIp: targetIp,
      port: port,
      deviceCode: deviceCode,
      replyProtocol: 7,
      timeout: const Duration(seconds: 10),
      matches: (json) =>
          json.containsKey('active') ||
          json.containsKey('user_email') ||
          json.containsKey('user_mail'),
    );
  }

  Future<Map<String, dynamic>> readMatter({
    required String targetIp,
    required int port,
    required String deviceCode,
  }) {
    return readProtocol(
      targetIp: targetIp,
      port: port,
      deviceCode: deviceCode,
      replyProtocol: 16,
      timeout: const Duration(seconds: 15),
      matches: (json) =>
          json.containsKey('vendor_id') || json.containsKey('discriminator'),
    );
  }

  Future<void> writeMatterCommand({
    required String targetIp,
    required int port,
    required String deviceCode,
    required int pairingMode,
    required int factoryReset,
  }) {
    return sendFireAndForget(
      targetIp: targetIp,
      port: port,
      message: {
        'protocol_nr': 16,
        'reply_protocol': 0,
        'code': deviceCode,
        'matter_pairing_mode': pairingMode,
        'matter_factory_reset': factoryReset,
      },
    );
  }

  Future<Map<String, dynamic>> readCpParameter({
    required String targetIp,
    required int port,
    required String deviceCode,
    required int slotCommand,
    Duration timeout = const Duration(seconds: 2),
  }) {
    return readProtocol(
      targetIp: targetIp,
      port: port,
      deviceCode: deviceCode,
      replyProtocol: 13,
      command: slotCommand,
      timeout: timeout,
      matches: (json) =>
          json.containsKey('commands') || json.containsKey('enabled'),
    );
  }

  Future<void> writeCpParameter({
    required String targetIp,
    required int port,
    required Map<String, dynamic> payload,
  }) {
    return sendFireAndForget(
      targetIp: targetIp,
      port: port,
      message: payload,
    );
  }

  Future<Map<String, dynamic>> readSmartLedTrigger({
    required String targetIp,
    required int port,
    required String deviceCode,
    required int triggerIndex,
    Duration timeout = const Duration(seconds: 2),
  }) {
    return readProtocol(
      targetIp: targetIp,
      port: port,
      deviceCode: deviceCode,
      replyProtocol: 13,
      command: triggerIndex,
      timeout: timeout,
      matches: (json) =>
          json.containsKey('change_switch_state') ||
          json.containsKey('trigger_type') ||
          json.containsKey('parameter_index'),
    );
  }

  Future<void> writeSmartLedTrigger({
    required String targetIp,
    required int port,
    required Map<String, dynamic> payload,
  }) {
    return sendFireAndForget(
      targetIp: targetIp,
      port: port,
      message: payload,
    );
  }

  Future<Map<String, dynamic>> readLedStrip({
    required String targetIp,
    required int port,
    required String deviceCode,
    required int ledIndex,
    Duration timeout = const Duration(seconds: 2),
  }) {
    return readProtocol(
      targetIp: targetIp,
      port: port,
      deviceCode: deviceCode,
      replyProtocol: 17,
      ledIndex: ledIndex,
      timeout: timeout,
      matches: (json) =>
          json.containsKey('led_index') &&
          (json.containsKey('led_on') ||
              json.containsKey('available') ||
              json.containsKey('brightness')),
    );
  }

  Future<void> writeLedStrip({
    required String targetIp,
    required int port,
    required Map<String, dynamic> payload,
  }) {
    return sendFireAndForget(
      targetIp: targetIp,
      port: port,
      message: payload,
    );
  }

  Future<Map<String, dynamic>> readLocation({
    required String targetIp,
    required int port,
    required String deviceCode,
  }) {
    return readProtocol(
      targetIp: targetIp,
      port: port,
      deviceCode: deviceCode,
      replyProtocol: 14,
      timeout: const Duration(seconds: 15),
      matches: (json) => json.containsKey('name'),
    );
  }

  Future<void> writeLocation({
    required String targetIp,
    required int port,
    required Map<String, dynamic> payload,
  }) {
    return sendFireAndForget(
      targetIp: targetIp,
      port: port,
      message: payload,
    );
  }

  Future<Map<String, dynamic>> readDateTime({
    required String targetIp,
    required int port,
    required String deviceCode,
  }) {
    return readProtocol(
      targetIp: targetIp,
      port: port,
      deviceCode: deviceCode,
      replyProtocol: 5,
      timeout: const Duration(seconds: 10),
      matches: (json) => json.containsKey('ntp_server_active'),
    );
  }

  Future<void> writeDateTime({
    required String targetIp,
    required int port,
    required Map<String, dynamic> payload,
  }) {
    return sendFireAndForget(
      targetIp: targetIp,
      port: port,
      message: payload,
    );
  }

  Future<Map<String, dynamic>> readGeneral({
    required String targetIp,
    required int port,
    required String deviceCode,
  }) {
    return readProtocol(
      targetIp: targetIp,
      port: port,
      deviceCode: deviceCode,
      replyProtocol: 6,
      timeout: const Duration(seconds: 10),
      matches: (json) =>
          json.containsKey('mode') ||
          json.containsKey('brightness') ||
          json.containsKey('effect_number'),
    );
  }

  Future<void> writeGeneral({
    required String targetIp,
    required int port,
    required Map<String, dynamic> payload,
  }) {
    return sendFireAndForget(
      targetIp: targetIp,
      port: port,
      message: payload,
    );
  }

  Future<Map<String, dynamic>> readUpdate({
    required String targetIp,
    required int port,
    required String deviceCode,
  }) {
    return readProtocol(
      targetIp: targetIp,
      port: port,
      deviceCode: deviceCode,
      replyProtocol: 12,
      command: 1,
      timeout: const Duration(seconds: 10),
      matches: (json) =>
          json.containsKey('active') ||
          json.containsKey('current_version') ||
          json.containsKey('mode'),
    );
  }

  Future<void> writeUpdateSchedule({
    required String targetIp,
    required int port,
    required Map<String, dynamic> payload,
  }) {
    return sendFireAndForget(
      targetIp: targetIp,
      port: port,
      message: payload,
    );
  }

  /// Alias for [writeUpdateSchedule] (legacy wizard API).
  Future<void> writeUpdate({
    required String targetIp,
    required int port,
    required Map<String, dynamic> payload,
  }) =>
      writeUpdateSchedule(targetIp: targetIp, port: port, payload: payload);

  Future<void> startManualUpdate({
    required String targetIp,
    required int port,
    required String deviceCode,
  }) {
    return sendFireAndForget(
      targetIp: targetIp,
      port: port,
      message: {
        'protocol_nr': 12,
        'reply_protocol': 12,
        'code': deviceCode,
        'command': 2,
      },
    );
  }

  Future<Map<String, dynamic>> changeDevicePassword({
    required String targetIp,
    required int port,
    required String deviceCode,
    required String newPassword,
  }) {
    return sendAndWait(
      targetIp: targetIp,
      port: port,
      message: {
        'protocol_nr': 2,
        'reply_protocol': 2,
        'code': deviceCode,
        'code_new': newPassword,
      },
      expectedReplyProtocol: 2,
      matches: (json) => json['code_changed'] == 'ok',
      timeout: const Duration(seconds: 15),
    );
  }

  Future<Map<String, dynamic>> sendCloudCredentials({
    required String targetIp,
    required int port,
    required String deviceCode,
    required String userEmail,
    required String userPassword,
    required String userId,
    bool active = true,
  }) {
    return writeProtocol(
      targetIp: targetIp,
      port: port,
      payload: {
        'protocol_nr': 7,
        'reply_protocol': 7,
        'code': deviceCode,
        'active': active ? 1 : 0,
        'user_email': userEmail,
        'user_password': userPassword,
        'user_id': userId,
      },
      expectedReplyProtocol: 7,
      timeout: const Duration(seconds: 10),
      matches: (json) =>
          json.containsKey('active') ||
          json.containsKey('user_email') ||
          json.containsKey('user_mail'),
    );
  }

  Future<void> writeMqtt({
    required String targetIp,
    required int port,
    required Map<String, dynamic> payload,
  }) {
    return sendFireAndForget(
      targetIp: targetIp,
      port: port,
      message: payload,
    );
  }

  bool Function(Map<String, dynamic>) _networkMatches(int command) {
    return (json) {
      return switch (command) {
        1 => json.containsKey('wifi_mode') || json.containsKey('port'),
        2 || 4 =>
          json.containsKey('ssid') || json.containsKey('active_conn'),
        3 || 5 => json.containsKey('ip') || json.containsKey('mac'),
        _ => json.isNotEmpty,
      };
    };
  }
}
