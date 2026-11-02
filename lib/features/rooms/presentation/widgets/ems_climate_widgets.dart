import 'package:flutter/material.dart';

import '../../../../core/theme/theme.dart';
import '../../../../shared/models/ems_sensor_reading.dart';
import 'device_card_text_styles.dart';

Color emsAirQualityColor(BuildContext context, EmsAirQuality quality) {
  final palette = context.palette;
  return switch (quality) {
    EmsAirQuality.excellent => palette.accentGreen,
    EmsAirQuality.good => palette.accentTeal,
    EmsAirQuality.light => palette.accentYellow,
    EmsAirQuality.moderate => palette.accentAmber,
    EmsAirQuality.heavy => palette.accentOrange,
    EmsAirQuality.severe => palette.accentRed,
    EmsAirQuality.extreme => palette.accentRed,
    EmsAirQuality.unknown => context.colors.outline,
  };
}

/// Green-to-red IAQ track with a marker at the current index.
class EmsAirQualityScale extends StatelessWidget {
  const EmsAirQualityScale({super.key, required this.reading});

  final EmsSensorReading reading;

  @override
  Widget build(BuildContext context) {
    final color = emsAirQualityColor(context, reading.airQuality);
    const labels = ['Ausgezeichnet', 'Gut', 'Belastet', 'Extrem'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            const marker = 18.0;
            final left = (reading.airQualityFraction * width - marker / 2)
                .clamp(0.0, (width - marker).clamp(0.0, width));
            return SizedBox(
              height: 22,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: AppRadius.full,
                      gradient: LinearGradient(
                        colors: [
                          context.palette.accentGreen,
                          context.palette.accentYellow,
                          context.palette.accentOrange,
                          context.palette.accentRed,
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: left,
                    child: Container(
                      width: marker,
                      height: marker,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.colors.surfaceContainerLowest,
                        border: Border.all(color: color, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.35),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            for (final label in labels)
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DeviceCardTextStyles.caption(context),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
