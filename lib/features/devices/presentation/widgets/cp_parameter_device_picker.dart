import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/providers/data_providers.dart';

/// Drill-down device picker: Haus → Etage → Raum → Gerät.
Future<CpParameterDeviceOption?> showCpParameterDevicePicker({
  required BuildContext context,
  required WidgetRef ref,
  required String excludeDeviceId,
}) {
  return showModalBottomSheet<CpParameterDeviceOption>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (context) => _CpParameterDevicePickerSheet(
      excludeDeviceId: excludeDeviceId,
    ),
  );
}

class _CpParameterDevicePickerSheet extends ConsumerWidget {
  const _CpParameterDevicePickerSheet({required this.excludeDeviceId});

  final String excludeDeviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devicesAsync = ref.watch(cpSelectableDevicesProvider(excludeDeviceId));

    return NeumorphicContainer(
      style: NeumorphicStyle.raised,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.containerPadding,
        AppSpacing.gutter,
        AppSpacing.containerPadding,
        AppSpacing.containerPadding,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.palette.divider,
                  borderRadius: AppRadius.full,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.gutter),
            Text('Gerät auswählen', style: context.text.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Haus → Etage → Raum → Gerät',
              style: context.text.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            Flexible(
              child: AsyncValueView<List<CpParameterDeviceOption>>(
                value: devicesAsync,
                onRetry: () =>
                    ref.invalidate(cpSelectableDevicesProvider(excludeDeviceId)),
                data: (devices) {
                  if (devices.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: EmptyState(
                        icon: Symbols.devices,
                        message: 'Keine verfügbaren Geräte gefunden',
                      ),
                    );
                  }

                  final grouped = <String, List<CpParameterDeviceOption>>{};
                  for (final device in devices) {
                    grouped.putIfAbsent(device.locationPath, () => []).add(device);
                  }

                  return ListView(
                    shrinkWrap: true,
                    children: [
                      for (final entry in grouped.entries) ...[
                        Padding(
                          padding: const EdgeInsets.only(
                            top: AppSpacing.sm,
                            bottom: AppSpacing.xs,
                          ),
                          child: Text(
                            entry.key,
                            style: context.text.labelSmall?.copyWith(
                              color: context.colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                        for (final device in entry.value)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: IconBox(
                              icon: device.deviceType == CpDeviceType.ems
                                  ? Symbols.air
                                  : CpDeviceType.isSmartLed(device.deviceType)
                                  ? Symbols.lightbulb
                                  : Symbols.devices,
                              color: context.colors.primary,
                              size: AppSizes.iconBoxSm,
                            ),
                            title: Text(
                              device.deviceType == CpDeviceType.ems ||
                                      isEmsTypeName(device.deviceTypeName)
                                  ? emsDisplayName
                                  : device.name,
                            ),
                            subtitle: Text(
                              '${device.deviceType == CpDeviceType.ems || isEmsTypeName(device.deviceTypeName) ? emsDisplayName : device.deviceTypeName} · ${device.code.isEmpty ? '—' : device.code}',
                            ),
                            trailing: const Icon(Symbols.chevron_right),
                            onTap: () => Navigator.of(context).pop(device),
                          ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
