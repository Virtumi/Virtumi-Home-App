import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/theme.dart';
import '../../../shared/models/models.dart';

/// Icon + accent color for a notification type.
({IconData icon, Color color}) notificationVisual(
  BuildContext context,
  AppNotificationType type,
) {
  final palette = context.palette;
  return switch (type) {
    AppNotificationType.deviceAccessRequest => (
      icon: Symbols.key,
      color: palette.accentOrange,
    ),
    AppNotificationType.deviceAccessApproved => (
      icon: Symbols.check_circle,
      color: palette.accentGreen,
    ),
    AppNotificationType.deviceAccessDeclined => (
      icon: Symbols.cancel,
      color: palette.accentRed,
    ),
  };
}

/// `dd.MM.yyyy HH:mm` in local time (no intl dependency needed).
String formatDateTime(DateTime value) {
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}
