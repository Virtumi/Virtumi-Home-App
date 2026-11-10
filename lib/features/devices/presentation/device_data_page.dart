import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../shared/models/models.dart';
import '../../../shared/providers/data_providers.dart';
import '../../../shared/providers/repository_providers.dart';
import 'widgets/device_settings_header.dart';

/// Bluetooth sensor data from device_data table.
class DeviceDataPage extends ConsumerWidget {
  const DeviceDataPage({super.key, required this.deviceId});

  final String deviceId;

  Future<void> _deleteEntry(WidgetRef ref, String entryId) async {
    await ref.read(deviceDataRepositoryProvider).deleteDeviceData(entryId);
    ref.invalidate(deviceDataProvider(deviceId));
  }

  Future<void> _deleteAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alle Sensordaten löschen?'),
        content: const Text('Diese Aktion kann nicht rückgängig gemacht werden.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref.read(deviceDataRepositoryProvider).deleteAllDeviceData(deviceId);
    ref.invalidate(deviceDataProvider(deviceId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(deviceDataProvider(deviceId));
    final p = context.palette;

    return AppScaffold(
      header: AppHeader(
        onRefresh: () => ref.invalidate(deviceDataProvider(deviceId)),
      ),
      body: AsyncValueView<List<DeviceDataEntry>>(
        value: dataAsync,
        onRetry: () => ref.invalidate(deviceDataProvider(deviceId)),
        data: (entries) {
          if (entries.isEmpty) {
            return const EmptyState(
              icon: Symbols.sensors,
              message: 'Keine Sensordaten vorhanden',
            );
          }

          return AppScrollView(
            children: [
              DeviceSettingsHeader(
                deviceId: deviceId,
                title: 'Sensordaten',
                icon: Symbols.sensors,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _deleteAll(context, ref),
                  icon: const Icon(Symbols.delete_sweep),
                  label: const Text('Alle löschen'),
                ),
              ),
              GroupedListCard(
                children: [
                  for (final entry in entries)
                    SettingsRow(
                      icon: Symbols.data_object,
                      title: entry.receivedAt.toLocal().toString(),
                      iconColor: p.accentTeal,
                      onTap: () => _deleteEntry(ref, entry.id),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              entry.data.entries
                                  .take(2)
                                  .map((e) => '${e.key}: ${e.value}')
                                  .join(', '),
                              style: context.text.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Icon(
                            Symbols.delete,
                            size: 20,
                            color: context.colors.error,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
