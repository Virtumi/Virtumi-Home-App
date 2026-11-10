import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../shared/models/models.dart';
import '../../../shared/providers/data_providers.dart';
import 'widgets/device_settings_header.dart';

/// Cloud hub ("Cloud Einstellungen"): entry points to Virtumi Cloud and MQTT.
class CloudPage extends ConsumerWidget {
  const CloudPage({super.key, required this.deviceId});

  final String deviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cloudAsync = ref.watch(cloudConfigProvider(deviceId));
    final p = context.palette;

    return AppScaffold(
      header: AppHeader(onRefresh: () => ref.invalidate(cloudConfigProvider(deviceId))),
      body: AsyncValueView<CloudConfig>(
        value: cloudAsync,
        onRetry: () => ref.invalidate(cloudConfigProvider(deviceId)),
        data: (cloud) => AppScrollView(
          children: [
            DeviceSettingsHeader(
              deviceId: deviceId,
              title: 'Cloud',
              icon: Symbols.cloud,
              accent: AppColors.accentSky,
            ),
            const AppSectionLabel('Dienste'),
            GroupedListCard(
              children: [
                SettingsRow.navigation(
                  icon: Symbols.cloud_done,
                  title: 'Virtumi Cloud',
                  iconColor: p.accentBlue,
                  value: cloud.virtumi.status.label,
                  glow: true,
                  onTap: () => context.push(Paths.virtumiCloud(deviceId)),
                ),
                SettingsRow.navigation(
                  icon: Symbols.dns,
                  title: 'MQTT Cloud',
                  iconColor: p.accentPurple,
                  value: cloud.mqtt.status.label,
                  onTap: () => context.push(Paths.mqttCloud(deviceId)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
