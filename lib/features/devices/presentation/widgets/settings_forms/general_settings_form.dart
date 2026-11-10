import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../../core/theme/theme.dart';
import '../../../../../core/widgets/widgets.dart';
import '../../../../../shared/models/models.dart';
import '../brightness_control.dart';
import '../device_settings_header.dart';
import '../led_color_palette.dart';
import '../led_schedule_section.dart';

class GeneralSettingsForm extends StatelessWidget {
  const GeneralSettingsForm({
    super.key,
    required this.config,
    required this.enabled,
    required this.onChanged,
    required this.onPickCustomColor,
    required this.onPickStatus,
    this.showSmartLedBanner = false,
    this.onSmartLedTap,
    this.footer,
    this.deviceId,
  });

  final GeneralConfig config;
  final bool enabled;
  final ValueChanged<GeneralConfig> onChanged;
  final VoidCallback onPickCustomColor;
  final VoidCallback onPickStatus;
  final bool showSmartLedBanner;
  final VoidCallback? onSmartLedTap;
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
            title: 'Allgemeine',
            icon: Symbols.settings,
          )
        else
          const SectionHeaderCard(
            title: 'Allgemeine',
            subtitle: 'LED & Anzeige',
            icon: Symbols.settings,
            filled: true,
          ),
        if (showSmartLedBanner && onSmartLedTap != null) ...[
          const SizedBox(height: AppSpacing.cardGap),
          ActionBannerCard(
            icon: Symbols.light_group,
            title: 'LED Strip Einstellungen',
            subtitle: 'Strip-Parameter, Effekte & Automatik',
            accent: p.accentAmber,
            trailingIcon: Symbols.chevron_right,
            onTap: onSmartLedTap,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        const AppSectionLabel('LED Farbe'),
        LedColorPalette(
          selectedValue: config.ledColorValue,
          enabled: enabled,
          onSelected: (value) =>
              onChanged(config.copyWith(ledColorValue: value)),
          onCustomTap: enabled ? onPickCustomColor : null,
        ),
        const AppSectionLabel('Helligkeit'),
        BrightnessControl(
          value: config.brightness,
          enabled: enabled,
          onChanged: (value) => onChanged(config.copyWith(brightness: value)),
        ),
        const AppSectionLabel('LED Status'),
        GroupedListCard(
          children: [
            SettingsRow.navigation(
              icon: Symbols.lightbulb,
              title: 'LED Status',
              iconColor: p.accentBlue,
              glow: true,
              value: config.ledStatus.label,
              onTap: enabled ? onPickStatus : null,
            ),
          ],
        ),
        if (config.ledStatus == LedStatus.scheduled)
          LedScheduleSection(
            config: config,
            enabled: enabled,
            onChanged: onChanged,
          ),
        if (footer != null) footer!,
      ],
    );
  }
}
