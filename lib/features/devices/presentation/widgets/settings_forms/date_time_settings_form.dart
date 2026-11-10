import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../../core/theme/theme.dart';
import '../../../../../core/widgets/widgets.dart';
import '../../../../../shared/models/models.dart';
import '../device_settings_header.dart';
import '../manual_date_time_card.dart';

class DateTimeSettingsForm extends StatelessWidget {
  const DateTimeSettingsForm({
    super.key,
    required this.config,
    required this.enabled,
    required this.onChanged,
    required this.onPickTimezone,
    this.footer,
    this.deviceId,
  });

  final DateTimeConfig config;
  final bool enabled;
  final ValueChanged<DateTimeConfig> onChanged;
  final VoidCallback onPickTimezone;
  final Widget? footer;

  /// Set on the device settings page. The setup wizard leaves this empty.
  final String? deviceId;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (deviceId != null)
          DeviceSettingsHeader(
            deviceId: deviceId!,
            title: 'Datum & Uhrzeit',
            icon: Symbols.schedule,
            accent: AppColors.accentIndigo,
          )
        else
          const SectionHeaderCard(
            title: 'Datum & Uhrzeit',
            subtitle: 'Zeitzone & Synchronisierung',
            icon: Symbols.schedule,
            accent: AppColors.accentIndigo,
            filled: true,
          ),
        const AppSectionLabel('Synchronisierung'),
        GroupedListCard(
          children: [
            SettingsRow.toggle(
              icon: Symbols.sync,
              title: 'Automatisch',
              iconColor: p.accentGreen,
              value: config.automatic,
              onChanged: enabled
                  ? (v) => onChanged(config.copyWith(automatic: v))
                  : (_) {},
            ),
            SettingsRow.navigation(
              icon: Symbols.public,
              title: 'Zeitzone',
              iconColor: p.accentBlue,
              value: config.timezone,
              onTap: enabled ? onPickTimezone : null,
            ),
            SettingsRow.navigation(
              icon: Symbols.dns,
              title: 'NTP-Server',
              iconColor: p.accentTeal,
              value: config.ntpServer,
            ),
            SettingsRow.navigation(
              icon: Symbols.dns,
              title: 'Sekundärer NTP Server',
              iconColor: p.accentCyan,
              value: config.secondaryNtpServer,
            ),
          ],
        ),
        if (!config.automatic) ...[
          const AppSectionLabel('Manuelle Einstellung'),
          ManualDateTimeCard(
            config: config,
            enabled: enabled,
            onChanged: onChanged,
          ),
        ],
        if (footer != null) footer!,
      ],
    );
  }
}
