import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/supabase/realtime_guard.dart';
import '../../../core/supabase/realtime_service.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/widgets/widgets.dart';
import '../../../shared/models/models.dart';
import '../../../shared/providers/data_providers.dart';
import '../../../shared/providers/repository_providers.dart';
import 'widgets/settings_forms/general_settings_form.dart';

/// General device settings ("Allgemeine"): LED color, brightness and LED status
/// with conditional scheduling.
class GeneralSettingsPage extends ConsumerStatefulWidget {
  const GeneralSettingsPage({super.key, required this.deviceId});
  final String deviceId;

  @override
  ConsumerState<GeneralSettingsPage> createState() =>
      _GeneralSettingsPageState();
}

class _GeneralSettingsPageState extends ConsumerState<GeneralSettingsPage> {
  GeneralConfig? _draft;
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
        table: 'cp_general_settings',
        onChange: () =>
            ref.invalidate(generalConfigProvider(widget.deviceId)),
      );
      _realtime!.subscribeToDeviceTable(
        deviceId: widget.deviceId,
        table: 'smart_led_general_settings',
        onChange: () =>
            ref.invalidate(generalConfigProvider(widget.deviceId)),
      );
      _realtime!.subscribeToDeviceTable(
        deviceId: widget.deviceId,
        table: 'ems_general_settings',
        onChange: () =>
            ref.invalidate(generalConfigProvider(widget.deviceId)),
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
        .saveGeneralConfig(widget.deviceId, draft);
    ref.invalidate(generalConfigProvider(widget.deviceId));
    if (mounted) {
      setState(() {
        _draft = null;
        _editing = false;
      });
    }
  }

  Future<void> _pickCustomColor(GeneralConfig draft) async {
    final picked = await showColorPicker(
      context: context,
      initialColor: Color(draft.ledColorValue),
    );
    if (picked != null) {
      setState(() => _draft = draft.copyWith(ledColorValue: picked.toARGB32()));
    }
  }

  Future<void> _pickStatus(GeneralConfig draft) async {
    final result = await showOptionPicker<LedStatus>(
      context: context,
      title: 'LED Status',
      options: LedStatus.values,
      labelOf: (s) => s.label,
      selected: draft.ledStatus,
    );
    if (result != null) {
      setState(() => _draft = draft.copyWith(ledStatus: result));
    }
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(generalConfigProvider(widget.deviceId));
    final deviceAsync = ref.watch(deviceProvider(widget.deviceId));
    final isSmartLed = deviceAsync.value?.type == DeviceType.light;

    return AppScaffold(
      header: AppHeader(
        isEditing: _editing,
        onEdit: () => setState(() => _editing = !_editing),
        onRefresh: () => ref.invalidate(generalConfigProvider(widget.deviceId)),
      ),
      body: AsyncValueView<GeneralConfig>(
        value: configAsync,
        onRetry: () => ref.invalidate(generalConfigProvider(widget.deviceId)),
        data: (config) {
          final draft = _editing ? (_draft ??= config.copyWith()) : config;
          return AppScrollView(
            children: [
              GeneralSettingsForm(
                config: draft,
                enabled: _editing,
                onChanged: (updated) => setState(() => _draft = updated),
                onPickCustomColor: () => _pickCustomColor(draft),
                onPickStatus: () => _pickStatus(draft),
                showSmartLedBanner: isSmartLed,
                onSmartLedTap: () =>
                    context.push(Paths.ledStripSettings(widget.deviceId)),
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
