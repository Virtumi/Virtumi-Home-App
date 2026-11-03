import 'package:flutter/widgets.dart';

/// Date & time configuration for a device.
@immutable
class DateTimeConfig {
  const DateTimeConfig({
    this.automatic = true,
    this.timezone = 'Berlin, Deutschland',
    this.timezoneTz = 'CET-1CEST,M3.5.0,M10.5.0/3',
    this.ntpServer = 'pool.ntp.org',
    this.secondaryNtpServer = 'time.google.com',
    this.use24HourFormat = true,
    this.dateFormat = 'DD.MM.YYYY',
    this.manualDate = '',
    this.manualTime = '',
  });

  final bool automatic;

  /// Human-readable timezone/location label ("Stadt, Land").
  final String timezone;

  /// POSIX TZ string of the selected location.
  final String timezoneTz;
  final String ntpServer;
  final String secondaryNtpServer;
  final bool use24HourFormat;
  final String dateFormat;

  /// Manually set date ("dd.MM.yyyy") and time ("HH:mm:ss"), used when
  /// [automatic] is disabled.
  final String manualDate;
  final String manualTime;

  DateTimeConfig copyWith({
    bool? automatic,
    String? timezone,
    String? timezoneTz,
    String? ntpServer,
    String? secondaryNtpServer,
    bool? use24HourFormat,
    String? dateFormat,
    String? manualDate,
    String? manualTime,
  }) {
    return DateTimeConfig(
      automatic: automatic ?? this.automatic,
      timezone: timezone ?? this.timezone,
      timezoneTz: timezoneTz ?? this.timezoneTz,
      ntpServer: ntpServer ?? this.ntpServer,
      secondaryNtpServer: secondaryNtpServer ?? this.secondaryNtpServer,
      use24HourFormat: use24HourFormat ?? this.use24HourFormat,
      dateFormat: dateFormat ?? this.dateFormat,
      manualDate: manualDate ?? this.manualDate,
      manualTime: manualTime ?? this.manualTime,
    );
  }
}

/// Matter / Thread smart-home protocol configuration.
@immutable
class MatterConfig {
  const MatterConfig({
    this.enabled = false,
    this.paired = false,
    this.setupCode = '',
    this.qrPayload = '',
    this.fabricCount = 0,
    this.threadEnabled = false,
  });

  final bool enabled;
  final bool paired;
  final String setupCode;

  /// Raw Matter onboarding payload encoded in the pairing QR code.
  final String qrPayload;
  final int fabricCount;
  final bool threadEnabled;

  /// True when the device provided a QR payload or a manual setup code.
  bool get hasPairingData =>
      qrPayload.trim().isNotEmpty || setupCode.trim().isNotEmpty;

  MatterConfig copyWith({
    bool? enabled,
    bool? paired,
    String? setupCode,
    String? qrPayload,
    int? fabricCount,
    bool? threadEnabled,
  }) {
    return MatterConfig(
      enabled: enabled ?? this.enabled,
      paired: paired ?? this.paired,
      setupCode: setupCode ?? this.setupCode,
      qrPayload: qrPayload ?? this.qrPayload,
      fabricCount: fabricCount ?? this.fabricCount,
      threadEnabled: threadEnabled ?? this.threadEnabled,
    );
  }
}

/// Physical location assignment of a device.
@immutable
class DeviceLocation {
  const DeviceLocation({
    this.deviceName = '',
    this.houseName = '',
    this.houseIconKey = 'haus',
    this.floorName = '',
    this.floorIconKey = 'obergeschoss',
    this.roomName = '',
    this.roomIconKey = 'buero',
    this.note = '',
  });

  final String deviceName;
  final String houseName;
  final String houseIconKey;
  final String floorName;
  final String floorIconKey;
  final String roomName;
  final String roomIconKey;
  final String note;

  DeviceLocation copyWith({
    String? deviceName,
    String? houseName,
    String? houseIconKey,
    String? floorName,
    String? floorIconKey,
    String? roomName,
    String? roomIconKey,
    String? note,
  }) {
    return DeviceLocation(
      deviceName: deviceName ?? this.deviceName,
      houseName: houseName ?? this.houseName,
      houseIconKey: houseIconKey ?? this.houseIconKey,
      floorName: floorName ?? this.floorName,
      floorIconKey: floorIconKey ?? this.floorIconKey,
      roomName: roomName ?? this.roomName,
      roomIconKey: roomIconKey ?? this.roomIconKey,
      note: note ?? this.note,
    );
  }
}
