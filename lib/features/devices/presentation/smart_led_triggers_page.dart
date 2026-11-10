import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../shared/models/models.dart';
import '../../../shared/providers/data_providers.dart';
import '../../../shared/providers/repository_providers.dart';
import 'widgets/device_settings_header.dart';
import 'widgets/smart_led_trigger_card.dart';
import 'widgets/smart_led_trigger_form_sheet.dart';

/// Smart LED trigger commands (smart_led_triggers): CRUD for active slots.
class SmartLedTriggersPage extends ConsumerWidget {
  const SmartLedTriggersPage({super.key, required this.deviceId});

  final String deviceId;

  void _refresh(WidgetRef ref) {
    // Active list is what the page shows; avoid a second full 10-slot read.
    ref.invalidate(smartLedActiveTriggersProvider(deviceId));
  }

  Future<void> _saveTrigger(
    BuildContext context,
    WidgetRef ref,
    SmartLedTrigger trigger,
  ) async {
    try {
      await ref
          .read(smartLedRepositoryProvider)
          .saveTrigger(deviceId, trigger.copyWith(active: 1));
      _refresh(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Befehl gespeichert')),
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
    SmartLedTrigger trigger,
  ) async {
    final title = trigger.name.isNotEmpty
        ? trigger.name
        : 'Befehl ${trigger.parameterIndex + 1}';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Befehl entfernen?'),
        content: Text('Befehl „$title“ wirklich entfernen?'),
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
      await ref.read(smartLedRepositoryProvider).deactivateTrigger(
            deviceId,
            trigger.parameterIndex,
          );
      _refresh(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Befehl entfernt')),
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
    SmartLedTrigger trigger,
  ) async {
    await showSmartLedTriggerFormSheet(
      context: context,
      draft: trigger,
      isNew: false,
      onSave: (updated) => _saveTrigger(context, ref, updated),
    );
  }

  Future<void> _openAddSheet(BuildContext context, WidgetRef ref) async {
    final index = await ref
        .read(smartLedRepositoryProvider)
        .nextFreeTriggerIndex(deviceId);

    if (index == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alle 10 Befehls-Slots sind belegt')),
        );
      }
      return;
    }

    if (!context.mounted) return;

    await showSmartLedTriggerFormSheet(
      context: context,
      draft: SmartLedTrigger(
        parameterIndex: index,
        active: 1,
      ),
      isNew: true,
      onSave: (updated) => _saveTrigger(context, ref, updated),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final triggersAsync = ref.watch(smartLedActiveTriggersProvider(deviceId));
    final p = context.palette;

    return AppScaffold(
      header: AppHeader(
        onRefresh: () => _refresh(ref),
      ),
      body: AsyncValueView<List<SmartLedTrigger>>(
        value: triggersAsync,
        onRetry: () => _refresh(ref),
        data: (triggers) {
          final slotsFull = triggers.length >= 10;

          return AppScrollView(
            children: [
              DeviceSettingsHeader(
                deviceId: deviceId,
                title: 'Smart LED Befehle',
                icon: Symbols.schedule,
              ),
              ActionBannerCard(
                icon: Symbols.add,
                title: 'Befehl hinzufügen',
                subtitle: slotsFull
                    ? 'Alle 10 Slots belegt'
                    : 'Neuen zeitgesteuerten Befehl anlegen',
                accent: p.accentOrange,
                trailingIcon: Symbols.add,
                trailingFilledButton: true,
                onTap: slotsFull ? null : () => _openAddSheet(context, ref),
              ),
              if (triggers.isEmpty)
                const EmptyState(
                  icon: Symbols.bolt,
                  message: 'Noch keine Befehle konfiguriert',
                )
              else
                for (final trigger in triggers)
                  SmartLedTriggerCard(
                    trigger: trigger,
                    accent: p.accentOrange,
                    onTap: () => _openEditSheet(context, ref, trigger),
                    onDelete: () => _confirmDelete(context, ref, trigger),
                  ),
            ],
          );
        },
      ),
    );
  }
}
