import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/supabase/realtime_guard.dart';
import '../../../core/supabase/realtime_service.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../shared/models/models.dart';
import '../../../shared/providers/data_providers.dart';
import '../../../shared/providers/repository_providers.dart';
import 'widgets/brightness_control.dart';
import 'widgets/device_settings_header.dart';
import 'widgets/led_color_palette.dart';

/// Smart LED strip settings (LED 1–3) from smart_led_settings.
class SmartLedStripsPage extends ConsumerStatefulWidget {
  const SmartLedStripsPage({super.key, required this.deviceId});

  final String deviceId;

  @override
  ConsumerState<SmartLedStripsPage> createState() => _SmartLedStripsPageState();
}

class _SmartLedStripsPageState extends ConsumerState<SmartLedStripsPage> {
  bool _editing = false;
  SmartLedStrip? _draft;
  int _selectedIndex = 1;
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
        table: 'smart_led_settings',
        onChange: () => ref.invalidate(smartLedStripsProvider(widget.deviceId)),
      );
    });
  }

  @override
  void dispose() {
    _realtime?.unsubscribeAll();
    super.dispose();
  }

  Future<void> _save(SmartLedStrip strip) async {
    await ref.read(smartLedRepositoryProvider).saveStrip(
          widget.deviceId,
          strip,
          quickControl: true,
        );
    // Keep local draft; avoid full UDP strip reload after quick save.
    if (mounted) {
      setState(() {
        _draft = strip;
        _editing = false;
      });
    }
  }

  Future<void> _pickCustomColor(SmartLedStrip draft) async {
    final picked = await showColorPicker(
      context: context,
      initialColor: Color(draft.ledColorValue),
    );
    if (picked != null) {
      setState(() => _draft = draft.copyWith(ledColorValue: picked.toARGB32()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final stripsAsync = ref.watch(smartLedStripsProvider(widget.deviceId));
    final p = context.palette;

    return AppScaffold(
      header: AppHeader(
        isEditing: _editing,
        onEdit: () => setState(() => _editing = !_editing),
        onRefresh: () => ref.invalidate(smartLedStripsProvider(widget.deviceId)),
      ),
      body: AsyncValueView<List<SmartLedStrip>>(
        value: stripsAsync,
        onRetry: () => ref.invalidate(smartLedStripsProvider(widget.deviceId)),
        data: (strips) {
          final current = strips.firstWhere((s) => s.ledIndex == _selectedIndex);
          final draft = _editing ? (_draft ??= current) : current;

          return AppScrollView(
            children: [
              DeviceSettingsHeader(
                deviceId: widget.deviceId,
                title: 'LED-Streifen',
                icon: Symbols.light_group,
              ),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 1, label: Text('LED 1')),
                  ButtonSegment(value: 2, label: Text('LED 2')),
                  ButtonSegment(value: 3, label: Text('LED 3')),
                ],
                selected: {_selectedIndex},
                onSelectionChanged: _editing
                    ? null
                    : (selection) => setState(() {
                          _selectedIndex = selection.first;
                          _draft = null;
                        }),
              ),
              const SizedBox(height: AppSpacing.lg),
              const AppSectionLabel('LED Farbe'),
              LedColorPalette(
                selectedValue: draft.ledColorValue,
                enabled: _editing,
                onSelected: (value) => setState(
                  () => _draft = draft.copyWith(ledColorValue: value),
                ),
                onCustomTap: _editing ? () => _pickCustomColor(draft) : null,
              ),
              const AppSectionLabel('Helligkeit'),
              BrightnessControl(
                value: draft.brightness.clamp(1, 100),
                enabled: _editing,
                onChanged: (value) =>
                    setState(() => _draft = draft.copyWith(brightness: value)),
              ),
              GroupedListCard(
                children: [
                  SettingsRow.toggle(
                    icon: Symbols.power,
                    title: 'LED an',
                    iconColor: p.accentGreen,
                    value: draft.ledOn == 1,
                    onChanged: _editing
                        ? (v) => setState(
                              () => _draft = draft.copyWith(ledOn: v ? 1 : 0),
                            )
                        : (_) {},
                  ),
                  SettingsRow.toggle(
                    icon: Symbols.auto_mode,
                    title: 'Auto-Modus',
                    iconColor: p.accentIndigo,
                    value: draft.autoMode == 1,
                    onChanged: _editing
                        ? (v) => setState(
                              () => _draft = draft.copyWith(autoMode: v ? 1 : 0),
                            )
                        : (_) {},
                  ),
                ],
              ),
              if (_editing)
                SaveCancelCard(
                  onCancel: () => setState(() {
                    _draft = null;
                    _editing = false;
                  }),
                  onSave: () => _save(_draft ?? current),
                ),
            ],
          );
        },
      ),
    );
  }
}
