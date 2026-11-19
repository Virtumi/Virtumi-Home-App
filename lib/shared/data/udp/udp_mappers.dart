import '../../models/cloud_config.dart';
import '../../models/cp_parameter.dart';
import '../../models/device_settings.dart';
import '../../models/general_config.dart';
import '../../models/network_config.dart';
import '../../models/smart_led_strip.dart';
import '../../models/smart_led_trigger.dart';
import '../supabase/mappers/config_mappers.dart';
import '../supabase/mappers/network_config_mapper.dart';

DateTimeConfig mapDateTimeConfigFromUdp(Map<String, dynamic>? json) {
  if (json == null) return const DateTimeConfig();

  final city = json['city'] as String?;
  final country = json['country'] as String?;
  final label = [city, country].where((e) => e != null && e.isNotEmpty).join(', ');

  final date = json['date'] as String?;
  final time = json['time'] as String?;
  final ntpActive = json['ntp_server_active'];
  final automatic = ntpActive is bool
      ? ntpActive
      : intToBool(ntpActive is int ? ntpActive : int.tryParse('$ntpActive'));

  return DateTimeConfig(
    automatic: automatic,
    timezone: label.isNotEmpty
        ? label
        : (json['timezonename'] as String? ??
            json['timezone'] as String? ??
            'Berlin, Deutschland'),
    timezoneTz: json['timezone'] as String? ?? 'Europe/Berlin',
    ntpServer: json['ntp_server'] as String? ?? 'pool.ntp.org',
    secondaryNtpServer: json['ntp_server_2'] as String? ?? '',
    manualDate: date ?? '',
    manualTime: time != null && time.length >= 5 ? time.substring(0, 5) : '',
  );
}

MatterConfig mapMatterConfigFromUdp(Map<String, dynamic>? json) {
  if (json == null) return const MatterConfig();

  return MatterConfig(
    enabled: intToBool(json['pairing_active'] as int?) ||
        (json['is_commissioned'] as bool? ?? false),
    paired: json['is_commissioned'] as bool? ?? false,
    setupCode: json['setup_passcode']?.toString() ?? '',
    qrPayload: json['qr_code']?.toString() ?? '',
    fabricCount: 1,
    threadEnabled: true,
  );
}

GeneralConfig mapGeneralConfigFromUdp(
  Map<String, dynamic>? json, {
  required bool smartLed,
}) {
  if (json == null) return const GeneralConfig();

  final r = json['rgb_color_r'] as int? ?? 0;
  final g = json['rgb_color_g'] as int? ?? 112;
  final b = json['rgb_color_b'] as int? ?? 234;
  final color = 0xFF000000 | (r << 16) | (g << 8) | b;

  final start = json['cmd_start'] as String?;
  final end = json['cmd_end'] as String?;

  return GeneralConfig(
    ledColorValue: color,
    brightness: json['brightness'] as int? ?? 80,
    ledStatus: ledStateFromInt(json['led_state'] as int?),
    commandType: commandTypeFromMode(json['mode'] as int?),
    startTime: start != null && start.length >= 5 ? start.substring(0, 5) : '18:00',
    endTime: end != null && end.length >= 5 ? end.substring(0, 5) : '23:00',
    specificDate: json['cmd_date'] as String?,
  );
}

Map<String, dynamic> generalUdpWritePayloadForKind(
  String deviceCode,
  GeneralConfig config, {
  required bool smartLed,
}) {
  final payload = generalUdpWritePayload(deviceCode, config);
  if (smartLed) {
    payload['logger_active'] = 1;
  } else {
    payload['logger_active'] = false;
  }
  if (smartLed && ledStateToInt(config.ledStatus) != 2) {
    payload.remove('cmd_date');
    payload.remove('cmd_start');
    payload.remove('cmd_end');
  }
  return payload;
}

CloudConfig mapCloudConfigFromUdp({
  Map<String, dynamic>? virtumi,
  Map<String, dynamic>? mqtt,
}) {
  return CloudConfig(
    virtumi: VirtumiCloudConfig(
      enabled: intToBool(virtumi?['active'] as int?),
      status: connectionFromInt(virtumi?['connected'] as int?),
      account: (virtumi?['user_email'] ?? virtumi?['user_mail'])?.toString() ?? '',
      password: virtumi?['user_password']?.toString() ?? '',
    ),
    mqtt: MqttCloudConfig(
      enabled: intToBool(mqtt?['mqtt_active'] as int?),
      status: connectionFromInt(mqtt?['mqtt_connected'] as int?),
      host: mqtt?['mqtt_server']?.toString() ?? '',
      port: mqtt?['mqtt_port'] as int? ?? 1883,
      username: mqtt?['mqtt_user']?.toString() ?? '',
      password: mqtt?['mqtt_password']?.toString() ?? '',
      useTls: (mqtt?['mqtt_port'] as int? ?? 1883) == 8883,
      allowAnonymous: intToBool(mqtt?['mqtt_allow_anonymous'] as int?),
      customerNumber:
          mqtt?['mqtt_customer_number']?.toString() ?? 'VirtumiCloud',
      qosLevel: MqttQosLevel.fromValue(mqtt?['mqtt_qos'] as int? ?? 0),
      retainMessages: intToBool(mqtt?['mqtt_retain'] as int?),
      cleanSession: mqtt?['mqtt_clean_session'] == null
          ? true
          : intToBool(mqtt?['mqtt_clean_session'] as int?),
    ),
  );
}

Map<String, dynamic> virtumiCloudUdpWritePayload({
  required String deviceCode,
  required VirtumiCloudConfig config,
  required String userId,
}) {
  return {
    'protocol_nr': 7,
    'reply_protocol': 7,
    'code': deviceCode,
    'user_id': userId,
    'active': boolToInt(config.enabled),
    'user_email': config.account,
    'user_password': config.password,
  };
}

Map<String, dynamic> mqttCloudUdpWritePayload({
  required String deviceCode,
  required MqttCloudConfig config,
}) {
  return {
    'protocol_nr': 4,
    'reply_protocol': 4,
    'command': 2,
    'code': deviceCode,
    'mqtt_active': boolToInt(config.enabled),
    'mqtt_qos': config.qosLevel.value,
    'mqtt_retain': boolToInt(config.retainMessages),
    'mqtt_clean_session': boolToInt(config.cleanSession),
    'mqtt_allow_anonymous': boolToInt(config.allowAnonymous),
    'mqtt_port': config.port,
    'mqtt_server': config.host,
    'mqtt_customer_number':
        config.customerNumber.isEmpty ? 'VirtumiCloud' : config.customerNumber,
    'mqtt_user': config.username,
    'mqtt_password': config.password,
    'mqtt_connected': config.status == ConnectionStatus.connected ? 1 : 0,
  };
}

Map<String, dynamic> mqttResetUdpPayload(String deviceCode) {
  return {
    'protocol_nr': 4,
    'reply_protocol': 4,
    'command': 1,
    'code': deviceCode,
  };
}

NetworkConfig mapNetworkConfigFromUdp({
  Map<String, dynamic>? modePort,
  Map<String, dynamic>? softAp,
  Map<String, dynamic>? softApDetails,
  Map<String, dynamic>? station,
  Map<String, dynamic>? stationDetails,
}) {
  return mapNetworkConfig(
    network: modePort,
    softAp: softAp,
    softApDetails: softApDetails,
    station: station,
    stationDetails: stationDetails,
  );
}

Map<String, dynamic> networkUdpWritePayload({
  required String deviceCode,
  required int command,
  required NetworkConfig config,
}) {
  return switch (command) {
    1 => {
        'protocol_nr': 8,
        'reply_protocol': 8,
        'command': 1,
        'code': deviceCode,
        'wifi_mode': wifiModeToInt(config.wifiMode),
        'port': int.tryParse(config.port) ?? 80,
      },
    2 => {
        'protocol_nr': 8,
        'reply_protocol': 8,
        'command': 2,
        'code': deviceCode,
        'active_conn': int.tryParse(config.apActiveConnections) ?? 0,
        'ssid': config.apSsid,
        'password': config.apPassword,
        'channel': int.tryParse(config.apChannel) ?? 1,
        'ecn': ecnToInt(config.apEncryption),
      },
    3 => {
        'protocol_nr': 8,
        'reply_protocol': 8,
        'command': 3,
        'code': deviceCode,
        'port': int.tryParse(config.apDetailsPort) ?? 80,
        'networ_type': ipModeToInt(config.apIpMode),
        'mac': config.apMacAddress,
        'ip': config.apIpAddress,
        'netmask': config.apSubnetMask,
        'gwip': config.apGateway,
        'dnsip': config.apDns,
        'dhcpsvrip': config.apDhcpServerIp,
        'websvrip': config.apWebServerIp,
      },
    4 => {
        'protocol_nr': 8,
        'reply_protocol': 8,
        'command': 4,
        'code': deviceCode,
        'active_conn': int.tryParse(config.stationActiveConnections) ?? 0,
        'ssid': config.stationSsid,
        'password': config.stationPassword,
        'channel': int.tryParse(config.stationChannel) ?? 1,
        'ecn': ecnToInt(config.stationEncryption),
      },
    5 => {
        'protocol_nr': 8,
        'reply_protocol': 8,
        'command': 5,
        'code': deviceCode,
        'port': int.tryParse(config.stationDetailsPort) ?? 80,
        'networ_type': ipModeToInt(config.stationIpMode),
        'mac': config.stationMacAddress,
        'ip': config.stationIpAddress,
        'netmask': config.stationSubnetMask,
        'gwip': config.stationGateway,
        'dnsip': config.stationDns,
        'dhcpsvrip': config.stationDhcpServerIp,
        'websvrip': config.stationWebServerIp,
      },
    _ => throw ArgumentError('Invalid network command: $command'),
  };
}

CpParameter mapCpParameterFromUdp(Map<String, dynamic> json, int parameterIndex) {
  final commands = json['commands'];
  var command0Active = 0;
  var command0Exists = 0;
  var command0Function = 0;
  var command0ProtokolNr = 0;
  var command1Active = 0;
  var command1Exists = 0;
  var command1Function = 0;
  var command1ProtokolNr = 0;
  var command2Active = 0;
  var command2Exists = 0;
  var command2Function = 0;
  var command2ProtokolNr = 0;

  if (commands is List) {
    for (var i = 0; i < commands.length && i < 3; i++) {
      final cmd = commands[i];
      if (cmd is! Map<String, dynamic>) continue;
      final active = cmd['active'] as int? ?? 0;
      final exists = cmd['exists'] as int? ?? 0;
      final function = cmd['function'] as int? ?? 0;
      final protokol = cmd['protokol_nr'] as int? ?? 0;
      switch (i) {
        case 0:
          command0Active = active;
          command0Exists = exists;
          command0Function = function;
          command0ProtokolNr = protokol;
        case 1:
          command1Active = active;
          command1Exists = exists;
          command1Function = function;
          command1ProtokolNr = protokol;
        case 2:
          command2Active = active;
          command2Exists = exists;
          command2Function = function;
          command2ProtokolNr = protokol;
      }
    }
  }

  return CpParameter(
    parameterIndex: parameterIndex,
    active: json['active'] as int? ?? 0,
    enabled: json['enabled'] as int? ?? 0,
    init: json['init'] as int? ?? 0,
    mode: json['mode'] as int? ?? 1,
    macAddress: json['mac'] as String? ?? json['mac_address'] as String? ?? '',
    ipAddress: json['ip'] as String? ?? json['ip_address'] as String? ?? '',
    port: json['port'] as int?,
    ipv6: json['ipv6'] as String? ?? '',
    channel: json['channel'] as int? ?? 1,
    name: json['name'] as String? ?? '',
    code: json['device_code'] as String? ?? '',
    resourceName:
        json['recource_name'] as String? ?? json['resource_name'] as String? ?? '',
    deviceType: json['device_type'] as int? ?? 0,
    command0Active: command0Active,
    command0Exists: command0Exists,
    command0Function: command0Function,
    command0ProtokolNr: command0ProtokolNr,
    command1Active: command1Active,
    command1Exists: command1Exists,
    command1Function: command1Function,
    command1ProtokolNr: command1ProtokolNr,
    command2Active: command2Active,
    command2Exists: command2Exists,
    command2Function: command2Function,
    command2ProtokolNr: command2ProtokolNr,
  );
}

Map<String, dynamic> cpParameterUdpWritePayload(
  String deviceCode,
  CpParameter parameter,
) {
  return {
    'protocol_nr': 13,
    'reply_protocol': 13,
    'code': deviceCode,
    'command': parameter.parameterIndex,
    'active': parameter.active,
    'init': parameter.init,
    'enabled': parameter.enabled,
    'mode': parameter.mode,
    'mac': parameter.macAddress,
    'ipv6': parameter.ipv6,
    'ip': parameter.ipAddress,
    if (parameter.port != null) 'port': parameter.port,
    'channel': parameter.channel,
    'name': parameter.name,
    'resource_name': parameter.resourceName,
    'device_code': parameter.code,
    'device_type': parameter.deviceType,
    'commands': [
      {
        'active': parameter.command0Active,
        'exists': parameter.command0Exists,
        'function': parameter.command0Function,
        'protokol_nr': parameter.command0ProtokolNr,
      },
      {
        'active': parameter.command1Active,
        'exists': parameter.command1Exists,
        'function': parameter.command1Function,
        'protokol_nr': parameter.command1ProtokolNr,
      },
      {
        'active': parameter.command2Active,
        'exists': parameter.command2Exists,
        'function': parameter.command2Function,
        'protokol_nr': parameter.command2ProtokolNr,
      },
    ],
  };
}

SmartLedTrigger mapSmartLedTriggerFromUdp(
  Map<String, dynamic> json,
  int parameterIndex,
) {
  final commandTime = json['command_time'];
  final offAutomaticTime = json['off_automatic_time'];
  final commandDate = json['command_date'];

  int hour = 0, minute = 0, second = 0;
  int offHour = 0, offMinute = 0, offSecond = 0;
  int day = 1, month = 1, year = 2026;

  if (commandTime is Map) {
    hour = commandTime['hour'] as int? ?? 0;
    minute = commandTime['minute'] as int? ?? 0;
    second = commandTime['second'] as int? ?? 0;
  }
  if (offAutomaticTime is Map) {
    offHour = offAutomaticTime['hour'] as int? ?? 0;
    offMinute = offAutomaticTime['minute'] as int? ?? 0;
    offSecond = offAutomaticTime['second'] as int? ?? 0;
  }
  if (commandDate is Map) {
    day = commandDate['day'] as int? ?? 1;
    month = commandDate['month'] as int? ?? 1;
    year = commandDate['year'] as int? ?? 2026;
  }

  return SmartLedTrigger(
    parameterIndex: parameterIndex,
    active: json['active'] as int? ?? 0,
    done: json['done'] as int? ?? 0,
    changeSwitchState: json['change_switch_state'] as int? ?? 0,
    changeBrightness: json['change_brightness'] as int? ?? 0,
    changeOffAutomatic: json['change_off_automatic'] as int? ?? 0,
    lampOn: json['on'] as int? ?? 0,
    offAutomatic: json['off_automatic'] as int? ?? 0,
    changeLedEffect: json['change_mode_led'] as int? ?? 0,
    brightness: json['brightness'] as int? ?? 0,
    effectNumber: json['effectNumber'] as int? ?? json['mode_led'] as int? ?? 0,
    triggerType: json['trigger_type'] as int? ?? 1,
    name: json['name'] as String? ?? '',
    commandTimeHour: hour,
    commandTimeMinute: minute,
    commandTimeSecond: second,
    offAutomaticTimeHour: offHour,
    offAutomaticTimeMinute: offMinute,
    offAutomaticTimeSecond: offSecond,
    commandDateDay: day,
    commandDateMonth: month,
    commandDateYear: year,
  );
}

Map<String, dynamic> smartLedTriggerUdpWritePayload(
  String deviceCode,
  SmartLedTrigger trigger,
) {
  return {
    'protocol_nr': 13,
    'reply_protocol': 13,
    'code': deviceCode,
    'command': trigger.parameterIndex,
    'parameter_index': trigger.parameterIndex,
    'active': trigger.active,
    'done': trigger.done,
    'change_switch_state': trigger.changeSwitchState,
    'change_brightness': trigger.changeBrightness,
    'change_off_automatic': trigger.changeOffAutomatic,
    'on': trigger.lampOn,
    'off_automatic': trigger.offAutomatic,
    'change_mode_led': trigger.changeLedEffect,
    'brightness': trigger.brightness,
    'mode_led': trigger.effectNumber,
    'trigger_type': trigger.triggerType,
    'effectNumber': trigger.effectNumber,
    'command_time': {
      'hour': trigger.commandTimeHour,
      'minute': trigger.commandTimeMinute,
      'second': trigger.commandTimeSecond,
    },
    'off_automatic_time': {
      'hour': trigger.offAutomaticTimeHour,
      'minute': trigger.offAutomaticTimeMinute,
      'second': trigger.offAutomaticTimeSecond,
    },
    'command_date': {
      'day': trigger.commandDateDay,
      'month': trigger.commandDateMonth,
      'year': trigger.commandDateYear,
    },
    'name': trigger.name,
  };
}

SmartLedStrip mapSmartLedStripFromUdp(Map<String, dynamic> json) {
  return SmartLedStrip(
    ledIndex: json['led_index'] as int? ?? 1,
    ledCount: json['led_count'] as int? ?? 1,
    rgbColorR: json['rgb_color_r'] as int? ?? 0,
    rgbColorG: json['rgb_color_g'] as int? ?? 0,
    rgbColorB: json['rgb_color_b'] as int? ?? 0,
    rgbColorR2: json['rgb_color_r2'] as int? ?? 0,
    rgbColorG2: json['rgb_color_g2'] as int? ?? 0,
    rgbColorB2: json['rgb_color_b2'] as int? ?? 0,
    speed: json['speed'] as int? ?? 0,
    effectNumber: json['effect_number'] as int? ?? 0,
    ledOn: json['led_on'] as int? ?? 0,
    available: json['available'] as int? ?? 0,
    autoMode: json['auto_mode'] as int? ?? 0,
    autoModeTime: json['auto_mode_time'] as int? ?? 0,
    ledFunctionNr: json['led_function_nr'] as int? ?? 0,
    brightness: json['brightness'] as int? ?? 10,
    offAutomatic: json['off_automatic'] as int? ?? 0,
    maxBrightness: json['max_brightness'] as int? ?? 100,
    offTime: json['off_time'] as String? ?? '',
  );
}

Map<String, dynamic> smartLedStripUdpWritePayload(
  String deviceCode,
  SmartLedStrip strip, {
  bool quickControl = false,
}) {
  final payload = <String, dynamic>{
    'protocol_nr': 17,
    'reply_protocol': 17,
    'code': deviceCode,
    'led_index': strip.ledIndex,
    'led_on': strip.ledOn,
    'rgb_color_r': strip.rgbColorR,
    'rgb_color_g': strip.rgbColorG,
    'rgb_color_b': strip.rgbColorB,
    // Secondary color is needed for dual-color effects on the room card.
    'rgb_color_r2': strip.rgbColorR2,
    'rgb_color_g2': strip.rgbColorG2,
    'rgb_color_b2': strip.rgbColorB2,
    'brightness': strip.brightness,
    'effect_number': strip.effectNumber,
    'speed': strip.speed,
    'auto_mode': strip.autoMode,
    'auto_mode_time': strip.autoModeTime,
  };

  if (!quickControl) {
    payload.addAll({
      'led_count': strip.ledCount,
      'led_mode': 0,
      'led_function_nr': strip.ledFunctionNr,
      'off_automatic': strip.offAutomatic,
      'max_brightness': strip.maxBrightness,
    });
    if (strip.offAutomatic == 1 && strip.offTime.isNotEmpty) {
      payload['off_time'] = strip.offTime;
    }
  }

  return payload;
}

DeviceLocation mapDeviceLocationFromUdp(Map<String, dynamic>? json) {
  if (json == null) return const DeviceLocation();
  return DeviceLocation(
    deviceName: json['name'] as String? ?? '',
    houseName: json['home'] as String? ?? '',
    floorName: json['floor'] as String? ?? '',
    roomName: json['room'] as String? ?? '',
  );
}

Map<String, dynamic> dateTimeUdpWritePayloadExtended(
  String deviceCode,
  DateTimeConfig config,
) {
  final payload = dateTimeUdpWritePayload(deviceCode, config);
  payload['timezonename'] = config.timezone;
  payload['time_change_active'] = !config.automatic;
  return payload;
}
