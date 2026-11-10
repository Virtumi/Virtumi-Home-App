import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../shared/models/models.dart';
import '../../../shared/providers/data_providers.dart';
import '../../../shared/providers/repository_providers.dart';
import 'widgets/cp_parameter_card.dart';
import 'widgets/device_settings_header.dart';
import 'widgets/cp_parameter_form_sheet.dart';

/// Control Panel parameter modules (cp_parameters): CRUD for active slots.
class DeviceParametersPage extends ConsumerWidget {
  const DeviceParametersPage({super.key, required this.deviceId});

  final String deviceId;

  void _refresh(WidgetRef ref) {
    // Active list is what the page shows; avoid a second full 10-slot read.
    ref.invalidate(cpActiveParametersProvider(deviceId));
  }

  Future<void> _saveParameter(
    BuildContext context,
    WidgetRef ref,
    CpParameter parameter,
  ) async {
    try {
      await ref
          .read(cpSettingsRepositoryProvider)
          .saveParameter(deviceId, parameter.copyWith(active: 1));
      _refresh(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Parameter gespeichert')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Speichern fehlgeschlagen: $e')),
        );
      }
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    CpParameter parameter,
  ) async {
    final storedTitle = visibleStoredDeviceName(
      parameter.name,
      firmwareType: parameter.deviceType,
    );
    final title = storedTitle.isNotEmpty
        ? storedTitle
        : 'Parameter ${parameter.parameterIndex}';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Parameter entfernen?'),
        content: Text('Parameter „$title“ wirklich entfernen?'),
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
            child: const Text('Entfernen'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(cpSettingsRepositoryProvider).deactivateParameter(
            deviceId,
            parameter.parameterIndex,
          );
      _refresh(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Parameter entfernt')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Entfernen fehlgeschlagen: $e')),
        );
      }
    }
  }

  Future<void> _openEditSheet(
    BuildContext context,
    WidgetRef ref,
    CpParameter parameter,
  ) async {
    await showCpParameterFormSheet(
      context: context,
      ref: ref,
      excludeDeviceId: deviceId,
      draft: parameter,
      isNew: false,
      onSave: (updated) => _saveParameter(context, ref, updated),
    );
  }

  Future<void> _openAddSheet(BuildContext context, WidgetRef ref) async {
    final index = await ref
        .read(cpSettingsRepositoryProvider)
        .nextFreeParameterIndex(deviceId);

    if (index == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alle 10 Parameter-Slots sind belegt')),
        );
      }
      return;
    }

    if (!context.mounted) return;

    await showCpParameterFormSheet(
      context: context,
      ref: ref,
      excludeDeviceId: deviceId,
      draft: CpParameter(
        parameterIndex: index,
        active: 1,
        enabled: 1,
      ),
      isNew: true,
      onSave: (updated) => _saveParameter(context, ref, updated),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paramsAsync = ref.watch(cpActiveParametersProvider(deviceId));
    final p = context.palette;

    return AppScaffold(
      header: AppHeader(
        onRefresh: () => _refresh(ref),
      ),
      body: AsyncValueView<List<CpParameter>>(
        value: paramsAsync,
        onRetry: () => _refresh(ref),
        data: (parameters) {
          final slotsFull = parameters.length >= 10;

          return AppScrollView(
            children: [
              DeviceSettingsHeader(
                deviceId: deviceId,
                title: 'Parameter',
                icon: Symbols.tune,
              ),
              ActionBannerCard(
                icon: Symbols.add,
                title: 'Parameter hinzufügen',
                subtitle: slotsFull
                    ? 'Alle 10 Slots belegt'
                    : 'Gerät über Haus, Etage und Raum auswählen',
                accent: p.accentTeal,
                trailingIcon: Symbols.add,
                trailingFilledButton: true,
                onTap: slotsFull ? null : () => _openAddSheet(context, ref),
              ),
              if (parameters.isEmpty)
                const EmptyState(
                  icon: Symbols.settings_input_component,
                  message: 'Noch keine Parameter konfiguriert',
                )
              else
                for (final parameter in parameters)
                  CpParameterCard(
                    parameter: parameter,
                    accent: p.accentTeal,
                    onTap: () => _openEditSheet(context, ref, parameter),
                    onDelete: () => _confirmDelete(context, ref, parameter),
                  ),
            ],
          );
        },
      ),
    );
  }
}
