import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/providers/data_providers.dart';
import '../../../rooms/presentation/widgets/device_card_text_styles.dart';
import '../../../rooms/presentation/widgets/ems_climate_widgets.dart';
import 'ems_history_chart.dart';

/// Device overview for an Environment Monitoring System.
class EmsDeviceOverview extends ConsumerWidget {
  const EmsDeviceOverview({super.key, required this.device});

  final Device device;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readingAsync = ref.watch(emsSensorProvider(device.id));
    final reading = readingAsync.asData?.value ?? EmsSensorReading.empty;
    final quality = reading.airQuality;
    final qualityColor = emsAirQualityColor(context, quality);
    final goodAir = reading.ventilationAdvice.startsWith('Optimale');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeaderCard(
          title: 'Luftqualität im Raum',
          subtitle: device.displayName,
          icon: Symbols.air,
          accent: context.palette.accentTeal,
          filled: true,
          trailing: NeumorphicIconButton(
            icon: Symbols.settings,
            iconColor: context.colors.onSurface,
            size: 40,
            iconSize: 20,
            tooltip: 'Geräteeinstellungen',
            onPressed: () => context.push(Paths.deviceSettings(device.id)),
          ),
        ),
        const SizedBox(height: AppSpacing.cardGap),
        if (readingAsync.isLoading && !readingAsync.hasValue) ...[
          const Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          const SizedBox(height: AppSpacing.cardGap),
        ],
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.containerPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'INDEX BEWERTUNG',
                style: DeviceCardTextStyles.statLabel(context),
              ),
              const SizedBox(height: AppSpacing.gutter),
              Row(
                children: [
                  Icon(
                    quality.isCritical
                        ? Symbols.warning
                        : Symbols.check_circle,
                    color: qualityColor,
                    fill: 1,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      quality.label,
                      style: context.text.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: qualityColor,
                      ),
                    ),
                  ),
                ],
              ),
              if (quality.detail.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  quality.detail,
                  style: DeviceCardTextStyles.subtitle(context),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              EmsAirQualityScale(reading: reading),
              if (reading.isStabilizing) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Sensor stabilisiert sich noch.',
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
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.cardGap),
        Row(
          children: [
            Expanded(
              child: _IndexTile(
                icon: Symbols.bubble_chart,
                color: context.palette.accentTeal,
                label: 'AQI Index',
                value: reading.aqiLabel,
                caption: 'Genauigkeit: ${reading.accuracyLabel}',
              ),
            ),
            const SizedBox(width: AppSpacing.cardGap),
            Expanded(
              child: _IndexTile(
                icon: Symbols.co2,
                color: context.palette.accentIndigo,
                label: 'Kohlendioxid',
                value: reading.co2Label,
                caption: reading.co2Ppm == null ? '—' : 'ppm',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        const AppSectionLabel('Klimamesswerte'),
        _ClimateTile(
          icon: Symbols.device_thermostat,
          color: context.palette.accentOrange,
          label: 'Temperatur',
          value: reading.temperatureLabel,
          unit: reading.temperature == null ? '' : '°C',
          hint: reading.temperatureHint,
        ),
        const SizedBox(height: AppSpacing.cardGap),
        _ClimateTile(
          icon: Symbols.humidity_percentage,
          color: context.palette.accentSky,
          label: 'Luftfeuchte',
          value: reading.humidityLabel,
          unit: reading.humidity == null ? '' : '%',
          hint: reading.humidityHint,
        ),
        const SizedBox(height: AppSpacing.cardGap),
        _ClimateTile(
          icon: Symbols.speed,
          color: context.palette.accentIndigo,
          label: 'Luftdruck',
          value: reading.pressureLabel,
          unit: reading.pressureHpa == null ? '' : 'hPa',
          hint: reading.pressureHint,
        ),
        const SizedBox(height: AppSpacing.cardGap),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.containerPadding),
          child: Row(
            children: [
              IconBox(
                icon: goodAir ? Symbols.check_circle : Symbols.info,
                color: goodAir
                    ? context.palette.accentGreen
                    : context.palette.accentAmber,
                filled: true,
              ),
              const SizedBox(width: AppSpacing.gutter),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lüftungsempfehlung',
                      style: DeviceCardTextStyles.title(context),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      reading.airQuality == EmsAirQuality.unknown &&
                              reading.co2Ppm == null
                          ? 'Keine Sensordaten'
                          : reading.ventilationAdvice,
                      style: DeviceCardTextStyles.subtitle(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.cardGap),
        EmsHistoryChart(deviceId: device.id),
      ],
    );
  }
}

class _IndexTile extends StatelessWidget {
  const _IndexTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.caption,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBox(icon: icon, color: color, filled: true),
          const SizedBox(height: AppSpacing.gutter),
          Text(label, style: DeviceCardTextStyles.caption(context)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: context.text.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(caption, style: DeviceCardTextStyles.subtitle(context)),
        ],
      ),
    );
  }
}

class _ClimateTile extends StatelessWidget {
  const _ClimateTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.unit,
    required this.hint,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String unit;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.containerPadding),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: DeviceCardTextStyles.subtitle(context)),
                const SizedBox(height: AppSpacing.xs),
                Text.rich(
                  TextSpan(
                    text: value,
                    style: context.text.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    children: [
                      if (unit.isNotEmpty)
                        TextSpan(
                          text: ' $unit',
                          style: context.text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(hint, style: DeviceCardTextStyles.caption(context)),
              ],
            ),
          ),
          IconBox(icon: icon, color: color, size: AppSizes.iconBoxMd, filled: true),
        ],
      ),
    );
  }
}
