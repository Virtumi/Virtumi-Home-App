import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/models.dart';

/// Shows system notifications while the app is running (Phase 1 of the
/// device access request feature). Real push via FCM is a later phase.
///
/// Only Android and iOS are supported; on every other platform all calls are
/// silent no-ops, so callers never have to check the platform themselves.
class LocalNotificationService {
  LocalNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _channelId = 'device_access';
  static const _channelName = 'Freigabeanfragen';
  static const _channelDescription =
      'Anfragen und Antworten zu Geräte-Freigaben';

  final FlutterLocalNotificationsPlugin _plugin;
  Future<bool>? _initialization;

  bool get _isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Initializes the plugin and asks for the notification permission once.
  Future<bool> ensureInitialized() {
    if (!_isSupported) return Future.value(false);
    return _initialization ??= _initialize();
  }

  Future<bool> _initialize() async {
    try {
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      );
      await _plugin.initialize(settings: settings);

      if (defaultTargetPlatform == TargetPlatform.android) {
        await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission();
      }
      return true;
    } catch (error, stackTrace) {
      debugPrint('Lokale Benachrichtigungen nicht verfügbar: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  /// Shows a notification for a freshly received inbox entry.
  Future<void> showInboxEntry({
    required AppNotificationType type,
    required String deviceName,
    String? notificationId,
  }) async {
    if (!await ensureInitialized()) return;

    final (title, body) = switch (type) {
      AppNotificationType.deviceAccessRequest => (
        'Neue Freigabeanfrage',
        'Jemand möchte Zugriff auf „$deviceName“.',
      ),
      AppNotificationType.deviceAccessApproved => (
        'Freigabe genehmigt',
        'Du hast jetzt Zugriff auf „$deviceName“.',
      ),
      AppNotificationType.deviceAccessDeclined => (
        'Freigabe abgelehnt',
        'Deine Anfrage für „$deviceName“ wurde abgelehnt.',
      ),
    };

    try {
      await _plugin.show(
        id: (notificationId ?? '$title$deviceName').hashCode & 0x7fffffff,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (error) {
      debugPrint('Benachrichtigung konnte nicht angezeigt werden: $error');
    }
  }
}

final localNotificationServiceProvider = Provider<LocalNotificationService>(
  (ref) => LocalNotificationService(),
);
