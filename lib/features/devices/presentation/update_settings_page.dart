import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/realtime_guard.dart';
import '../../../core/supabase/realtime_service.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/widgets/widgets.dart';
import '../../../shared/models/models.dart';
import '../../../shared/providers/connection_mode_provider.dart';
import '../../../shared/providers/data_providers.dart';
import '../../../shared/providers/repository_providers.dart';
import 'widgets/settings_forms/update_settings_form.dart';

/// Update settings ("Update Einstellungen"): availability hero card, current
/// version, and configurable auto-update options.
class UpdateSettingsPage extends ConsumerStatefulWidget {
  const UpdateSettingsPage({super.key, required this.deviceId});
  final String deviceId;

  @override
  ConsumerState<UpdateSettingsPage> createState() => _UpdateSettingsPageState();
}

class _UpdateSettingsPageState extends ConsumerState<UpdateSettingsPage> {
  UpdateConfig? _draft;
  bool _editing = false;
  RealtimeService? _realtime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!useSupabaseRealtime(ref)) return;
      _realtime = RealtimeService(ref.read(supabaseClientProvider));
      _realtime!.subscribeToDeviceTable(
        deviceId: widget.deviceId,
        table: 'device_update_status',
        onChange: () =>
            ref.invalidate(deviceUpdateStatusProvider(widget.deviceId)),
      );
    });
  }

  @override
  void dispose() {
    _realtime?.unsubscribeAll();
    super.dispose();
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null) return;
    await ref
        .read(deviceConfigRepositoryProvider)
        .saveUpdateConfig(widget.deviceId, draft);
    ref.invalidate(updateConfigProvider(widget.deviceId));
    if (mounted) {
      setState(() {
        _draft = null;
        _editing = false;
      });
    }
  }

  Future<void> _pickSchedule(UpdateConfig draft) async {
    final result = await showOptionPicker<UpdateSchedule>(
      context: context,
      title: 'Update Zeitplan',
      options: UpdateSchedule.values,
      labelOf: (option) => option.label,
      selected: draft.updateSchedule,
    );
    if (result != null) {
      setState(() => _draft = draft.copyWith(updateSchedule: result));
    }
  }

  Future<void> _pickWeekday(UpdateConfig draft) async {
    final result = await showOptionPicker<Weekday>(
      context: context,
      title: 'Wochentag',
      options: Weekday.values,
      labelOf: (option) => option.label,
      selected: draft.weekday,
    );
    if (result != null) {
      setState(() => _draft = draft.copyWith(weekday: result));
    }
  }

  Future<void> _startUpdate() async {
    await ref.read(deviceRequestRepositoryProvider).sendUpdateRequest(widget.deviceId);

    String? error;
    if (!ref.read(isDirectConnectionProvider)) {
      error = await ref
          .read(deviceRequestRepositoryProvider)
          .pollRequestStatus(table: 'update_requests', deviceId: widget.deviceId);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Update wurde gestartet')),
    );
    ref.invalidate(updateConfigProvider(widget.deviceId));
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(updateConfigProvider(widget.deviceId));
    final statusAsync = ref.watch(deviceUpdateStatusProvider(widget.deviceId));

    return AppScaffold(
      header: AppHeader(
        isEditing: _editing,
        onEdit: () => setState(() => _editing = !_editing),
        onRefresh: () {
          ref.invalidate(updateConfigProvider(widget.deviceId));
          ref.invalidate(deviceUpdateStatusProvider(widget.deviceId));
        },
      ),
      body: AsyncValueView<UpdateConfig>(
        value: configAsync,
        onRetry: () => ref.invalidate(updateConfigProvider(widget.deviceId)),
        data: (config) {
          final draft = _editing ? (_draft ??= config.copyWith()) : config;
          return AppScrollView(
            children: [
              UpdateSettingsForm(
                deviceId: widget.deviceId,
                config: draft,
                enabled: _editing,
                onChanged: (updated) => setState(() => _draft = updated),
                onPickSchedule: () => _pickSchedule(draft),
                onPickWeekday: () => _pickWeekday(draft),
                onStartUpdate: _startUpdate,
                liveStatus: statusAsync.value,
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
