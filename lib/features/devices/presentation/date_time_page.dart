import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/widgets.dart';
import '../../../shared/models/models.dart';
import '../../../shared/providers/data_providers.dart';
import '../../../shared/providers/repository_providers.dart';
import 'widgets/location_search_sheet.dart';
import 'widgets/settings_forms/date_time_settings_form.dart';

/// Date & time settings ("Datum & Uhrzeit") with toggles + value rows.
class DateTimePage extends ConsumerStatefulWidget {
  const DateTimePage({super.key, required this.deviceId});
  final String deviceId;

  @override
  ConsumerState<DateTimePage> createState() => _DateTimePageState();
}

class _DateTimePageState extends ConsumerState<DateTimePage> {
  DateTimeConfig? _draft;
  bool _editing = false;

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null) return;
    await ref
        .read(deviceConfigRepositoryProvider)
        .saveDateTimeConfig(widget.deviceId, draft);
    ref.invalidate(dateTimeConfigProvider(widget.deviceId));
    if (mounted) {
      setState(() {
        _draft = null;
        _editing = false;
      });
    }
  }

  Future<void> _pickTimezone(DateTimeConfig draft) async {
    final location = await showLocationSearch(context);
    if (location != null) {
      setState(() => _draft = draft.copyWith(
            timezone: location.label,
            timezoneTz: location.timezone,
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(dateTimeConfigProvider(widget.deviceId));

    return AppScaffold(
      header: AppHeader(
        isEditing: _editing,
        onEdit: () => setState(() => _editing = !_editing),
        onRefresh: () =>
            ref.invalidate(dateTimeConfigProvider(widget.deviceId)),
      ),
      body: AsyncValueView<DateTimeConfig>(
        value: configAsync,
        onRetry: () =>
            ref.invalidate(dateTimeConfigProvider(widget.deviceId)),
        data: (config) {
          final draft = _editing ? (_draft ??= config.copyWith()) : config;
          return AppScrollView(
            children: [
              DateTimeSettingsForm(
                deviceId: widget.deviceId,
                config: draft,
                enabled: _editing,
                onChanged: (updated) => setState(() => _draft = updated),
                onPickTimezone: () => _pickTimezone(draft),
                footer: _editing
                    ? SaveCancelCard(
                        onCancel: () => setState(() {
                          _draft = null;
                          _editing = false;
                        }),
                        onSave: _save,
                      )
                    : null,
              ),
            ],
          );
        },
      ),
    );
  }
}
