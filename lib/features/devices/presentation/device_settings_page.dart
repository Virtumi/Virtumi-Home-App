import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../shared/models/models.dart';
import '../../../shared/providers/data_providers.dart';
import '../../../shared/providers/repository_providers.dart';
import 'widgets/device_settings_header.dart';
import 'widgets/favorite_device_button.dart';
import 'widgets/settings_grid_tile.dart';

/// Device settings hub ("Geräteeinstellungen"): a 3-column grid of category
/// tiles, matching the Stitch control panel layout.
class DeviceSettingsPage extends ConsumerWidget {
  const DeviceSettingsPage({super.key, required this.deviceId});

  final String deviceId;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gerät löschen?'),
        content: const Text(
          'Das Gerät und alle zugehörigen Einstellungen werden '
          'unwiderruflich gelöscht.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.colors.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final rootNavigator = Navigator.of(context, rootNavigator: true);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Gerät wird gelöscht…',
                style: Theme.of(dialogContext).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ),
    );

    var deleted = false;
    try {
      await ref.read(smartHomeRepositoryProvider).deleteDevice(deviceId);
      invalidateLocationHierarchy(ref, deviceId: deviceId);
      deleted = true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Löschen: $e')),
        );
      }
    } finally {
      rootNavigator.pop();
    }

    if (deleted && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gerät gelöscht')),
      );
      context.go(Paths.home);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final deviceAsync = ref.watch(deviceProvider(deviceId));
    final device = deviceAsync.value;
    final isSmartLed = device?.type == DeviceType.light;
    final isControlPanel = device?.type == DeviceType.controlPanel;
    final isEms = device?.type == DeviceType.environmentMonitor;

    final tiles = <SettingsGridTile>[
      SettingsGridTile(
        icon: Symbols.info,
        label: 'Geräte Info',
        accent: p.accentBlue,
        onTap: () => context.push(Paths.deviceInfo(deviceId)),
      ),
      SettingsGridTile(
        icon: Symbols.schedule,
        label: 'Datum &\nUhrzeit',
        accent: p.accentIndigo,
        onTap: () => context.push(Paths.dateTime(deviceId)),
      ),
      SettingsGridTile(
        icon: Symbols.wifi,
        label: 'Netzwerk',
        accent: p.accentBlue,
        onTap: () => context.push(Paths.network(deviceId)),
      ),
      if (isControlPanel)
        SettingsGridTile(
          icon: Symbols.tune,
          label: 'Parameter',
          accent: p.accentTeal,
          onTap: () => context.push(Paths.deviceParameters(deviceId)),
        ),
      if (isSmartLed) ...[
        SettingsGridTile(
          icon: Symbols.light_group,
          label: 'LED-\nStreifen',
          accent: p.accentAmber,
          onTap: () => context.push(Paths.ledStripSettings(deviceId)),
        ),
        SettingsGridTile(
          icon: Symbols.schedule,
          label: 'Smart LED\nBefehle',
          accent: p.accentOrange,
          onTap: () => context.push(Paths.smartLedTriggers(deviceId)),
        ),
      ],
      if (!isControlPanel && !isSmartLed && !isEms)
        SettingsGridTile(
          icon: Symbols.sensors,
          label: 'Sensor-\ndaten',
          accent: p.accentTeal,
          onTap: () => context.push(Paths.deviceData(deviceId)),
        ),
      SettingsGridTile(
        icon: Symbols.cloud,
        label: 'Cloud',
        accent: p.accentSky,
        onTap: () => context.push(Paths.cloud(deviceId)),
      ),
      SettingsGridTile(
        icon: Symbols.location_on,
        label: 'Geräte Ort',
        accent: p.accentOrange,
        onTap: () => context.push(Paths.deviceLocation(deviceId)),
      ),
      SettingsGridTile(
        icon: Symbols.download,
        label: 'Update',
        accent: p.accentIndigo,
        onTap: () => context.push(Paths.updateSettings(deviceId)),
      ),
      SettingsGridTile(
        imageAsset: AppConstants.matterLogoAsset,
        label: 'Matter',
        accent: p.accentCyan,
        onTap: () => context.push(Paths.matter(deviceId)),
      ),
      SettingsGridTile(
        icon: Symbols.settings,
        label: 'Allgemeine',
        accent: p.accentBlue,
        onTap: () => context.push(Paths.generalSettings(deviceId)),
      ),
      SettingsGridTile(
        icon: Symbols.lock,
        label: 'Passwort\nändern',
        accent: p.accentBlue,
        onTap: () => context.push(Paths.changePassword(deviceId)),
      ),
      SettingsGridTile(
        icon: Symbols.delete,
        label: 'Löschen',
        accent: p.accentRed,
        danger: true,
        onTap: () => _confirmDelete(context, ref),
      ),
    ];

    final showHeaderActions = device != null &&
        device.type != DeviceType.controlPanel &&
        device.type != DeviceType.environmentMonitor &&
        device.type != DeviceType.light;

    return AppScaffold(
      header: AppHeader(
        onEdit: showHeaderActions ? () {} : null,
        onRefresh: showHeaderActions
            ? () => ref.invalidate(deviceProvider(deviceId))
            : null,
      ),
      body: AppScrollView(
        children: [
          DeviceSettingsHeader(
            deviceId: deviceId,
            title: 'Gerät Einstellungen',
            icon: Symbols.settings_suggest,
            trailing: FavoriteDeviceButton(deviceId: deviceId),
          ),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: AppSpacing.cardGap,
            crossAxisSpacing: AppSpacing.cardGap,
            childAspectRatio: 0.82,
            children: tiles,
          ),
        ],
      ),
    );
  }
}
