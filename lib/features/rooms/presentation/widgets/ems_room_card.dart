import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/application/direct_device_link.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/providers/data_providers.dart';
import 'device_card_text_styles.dart';
import 'device_online_badge.dart';
import 'ems_climate_widgets.dart';

/// Compact climate card for the room overview.
class EmsRoomCard extends ConsumerWidget {
  const EmsRoomCard({
    super.key,
    required this.device,
    required this.onOpenDetails,
    required this.onOpenSettings,
    this.showSettingsButton = true,
    this.showDetailsButton = true,
  });

  final Device device;
  final VoidCallback onOpenDetails;
  final VoidCallback onOpenSettings;
  final bool showSettingsButton;
  final bool showDetailsButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = deviceIsOnline(ref, device);
    final readingAsync = ref.watch(emsSensorProvider(device.id));
    final reading = readingAsync.asData?.value ?? EmsSensorReading.empty;
    final quality = reading.airQuality;
    final qualityColor = emsAirQualityColor(context, quality);

    return AppCard(
      onTap: online && showDetailsButton ? onOpenDetails : null,
      padding: const EdgeInsets.all(AppSpacing.containerPadding),
      semanticLabel: emsDisplayName,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconBox(
                icon: Symbols.cloud,
                color: context.colors.primary,
                size: AppSizes.iconBoxMd,
                filled: true,
              ),
              const SizedBox(width: AppSpacing.gutter),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      device.displayName,
                      style: DeviceCardTextStyles.title(context),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      emsCategoryLabel,
                      style: DeviceCardTextStyles.subtitle(context),
                    ),
                  ],
                ),
              ),
              DeviceOnlineBadge(device: device),
              if (online && showSettingsButton) ...[
                const SizedBox(width: AppSpacing.sm),
                NeumorphicIconButton(
                  icon: Symbols.settings,
                  iconColor: context.colors.onSurface,
                  size: 40,
                  iconSize: 20,
                  tooltip: 'Geräteeinstellungen',
                  onPressed: onOpenSettings,
                ),
              ],
              if (online && showSettingsButton && showDetailsButton)
                const SizedBox(width: AppSpacing.sm),
              if (online && showDetailsButton)
                _DetailsButton(onPressed: onOpenDetails),
            ],
          ),
          if (online) ...[
          const SizedBox(height: AppSpacing.lg),
          NeumorphicContainer(
            style: NeumorphicStyle.sunken,
            borderRadius: AppRadius.cardAll,
            padding: const EdgeInsets.all(AppSpacing.gutter),
            child: Row(
              children: [
                IconBox(
                  icon: quality.isCritical
                      ? Symbols.warning
                      : Symbols.check_circle,
                  color: qualityColor,
                  filled: true,
                ),
                const SizedBox(width: AppSpacing.gutter),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Luftqualität',
                        style: DeviceCardTextStyles.caption(context),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        quality.label,
                        style: context.text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: qualityColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('AQI', style: DeviceCardTextStyles.caption(context)),
                    const SizedBox(height: 2),
                    Text(
                      reading.aqiLabel,
                      style: context.text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (reading.isStabilizing || reading.isRunInActive) ...[
            const SizedBox(height: AppSpacing.sm),
            if (reading.isStabilizing)
              Text(
                'Sensor stabilisiert sich noch.',
                style: DeviceCardTextStyles.caption(context),
              ),
            if (reading.isStabilizing && reading.isRunInActive)
              const SizedBox(height: AppSpacing.xs),
            if (reading.isRunInActive)
              Text(
                'Sensor Einlaufphase aktiv',
                style: DeviceCardTextStyles.caption(context),
              ),
          ],
          if (readingAsync.hasError) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Sensordaten nicht verfügbar',
              style: DeviceCardTextStyles.caption(context).copyWith(
                color: context.colors.error,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  icon: Symbols.device_thermostat,
                  color: context.palette.accentOrange,
                  label: 'Temp',
                  value: reading.temperatureLabel,
                  unit: '°C',
                ),
              ),
              Expanded(
                child: _Stat(
                  icon: Symbols.humidity_percentage,
                  color: context.palette.accentSky,
                  label: 'Feuchte',
                  value: reading.humidityLabel,
                  unit: '%',
                ),
              ),
              Expanded(
                child: _Stat(
                  icon: Symbols.speed,
                  color: context.palette.accentIndigo,
                  label: 'Druck',
                  value: reading.pressureLabel,
                  unit: 'hPa',
                ),
              ),
            ],
          ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.unit,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final missing = value == '—';
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: AppSpacing.xs),
        Text(label, style: DeviceCardTextStyles.caption(context)),
        const SizedBox(height: 2),
        Text.rich(
          TextSpan(
            text: value,
            style: context.text.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            children: [
              if (!missing)
                TextSpan(
                  text: ' $unit',
                  style: DeviceCardTextStyles.caption(context),
                ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _DetailsButton extends StatelessWidget {
  const _DetailsButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final primary = context.colors.primary;
    return PressScale(
      style: PressScaleStyle.compact,
      onTap: onPressed,
      semanticLabel: 'Gerätedetails',
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Icon(
          Symbols.arrow_forward,
          color: context.colors.onPrimary,
          size: 20,
        ),
      ),
    );
  }
}
