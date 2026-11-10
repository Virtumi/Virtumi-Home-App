import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../rooms/presentation/widgets/smart_led_device_card.dart';
import 'widgets/device_settings_header.dart';
import '../../rooms/presentation/widgets/smart_led_effect_picker.dart';

/// Detailed LED strip configuration (smart_led_settings) for Smart LED devices.
class LedStripSettingsPage extends ConsumerStatefulWidget {
  const LedStripSettingsPage({super.key, required this.deviceId});

  final String deviceId;

  @override
  ConsumerState<LedStripSettingsPage> createState() =>
      _LedStripSettingsPageState();
}

class _LedStripSettingsPageState extends ConsumerState<LedStripSettingsPage> {
  static const _stripIndex = 1;

  bool _editing = false;
  SmartLedStrip? _draft;
  bool _initialized = false;

  final _ledCount = TextEditingController();
  final _autoInterval = TextEditingController();
  final _speed = TextEditingController();
  final _brightness = TextEditingController();
  final _maxBrightness = TextEditingController();
  final _offTime = TextEditingController();

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
    _ledCount.dispose();
    _autoInterval.dispose();
    _speed.dispose();
    _brightness.dispose();
    _maxBrightness.dispose();
    _offTime.dispose();
    super.dispose();
  }

  SmartLedStrip _stripOrDefault(List<SmartLedStrip> strips) {
    return strips.firstWhere(
      (s) => s.ledIndex == _stripIndex,
      orElse: () => const SmartLedStrip(ledIndex: _stripIndex),
    );
  }

  void _hydrate(SmartLedStrip strip) {
    if (_initialized && !_editing) return;
    if (_editing && _draft?.ledIndex == strip.ledIndex) return;

    _ledCount.text = '${strip.ledCount}';
    _autoInterval.text = '${(strip.autoModeTime / 1000).round()}';
    _speed.text = '${strip.speed}';
    _brightness.text = '${strip.brightness}';
    _maxBrightness.text = '${strip.maxBrightness}';
    _offTime.text = strip.offTime.isEmpty ? '00:00:00' : strip.offTime;
    _initialized = true;
  }

  SmartLedStrip _stripFromFields(SmartLedStrip base) {
    return base.copyWith(
      ledCount: int.tryParse(_ledCount.text.trim()) ?? base.ledCount,
      autoModeTime: (int.tryParse(_autoInterval.text.trim()) ?? 0) * 1000,
      speed: int.tryParse(_speed.text.trim()) ?? base.speed,
      brightness: (int.tryParse(_brightness.text.trim()) ?? base.brightness)
          .clamp(1, 100),
      maxBrightness:
          (int.tryParse(_maxBrightness.text.trim()) ?? base.maxBrightness)
              .clamp(1, 100),
      offTime: _offTime.text.trim(),
    );
  }

  Future<void> _save(SmartLedStrip strip) async {
    final updated = _stripFromFields(strip);
    // Full strip config (led_count, off_time, …) — still fire-and-forget UDP.
    await ref
        .read(smartLedRepositoryProvider)
        .saveStrip(widget.deviceId, updated);
    if (mounted) {
      setState(() {
        _draft = updated;
        _editing = false;
      });
    }
  }

  void _cancel(SmartLedStrip strip) {
    _draft = null;
    _initialized = false;
    _hydrate(strip);
    setState(() => _editing = false);
  }

  Future<void> _pickEffect(SmartLedStrip draft) async {
    final picked = await showSmartLedEffectPicker(
      context: context,
      selectedNumber: draft.effectNumber,
    );
    if (picked != null) {
      setState(() => _draft = draft.copyWith(effectNumber: picked.number));
    }
  }

  String _effectHint(SmartLedEffect effect) {
    if (effect.number == -1) return 'Schaltet die LEDs aus.';
    if (effect.needsSecondaryColor) {
      return 'Dieser Effekt nutzt Haupt- und Sekundärfarbe.';
    }
    return 'Dieser Effekt nutzt nur die Hauptfarbe.';
  }

  @override
  Widget build(BuildContext context) {
    final stripsAsync = ref.watch(smartLedStripsProvider(widget.deviceId));
    final deviceAsync = ref.watch(deviceProvider(widget.deviceId));
    final p = context.palette;
    final device = deviceAsync.value;

    return AppScaffold(
      header: AppHeader(
        isEditing: _editing,
        onEdit: () => setState(() => _editing = !_editing),
        onRefresh: () {
          ref.invalidate(smartLedStripsProvider(widget.deviceId));
          ref.invalidate(deviceProvider(widget.deviceId));
        },
      ),
      body: AsyncValueView<List<SmartLedStrip>>(
        value: stripsAsync,
        onRetry: () => ref.invalidate(smartLedStripsProvider(widget.deviceId)),
        data: (strips) {
          final current = _stripOrDefault(strips);
          final draft = _editing ? (_draft ??= current) : current;
          _hydrate(draft);
          final effect = smartLedEffectByNumber(draft.effectNumber);

          return AppScrollView(
            children: [
              DeviceSettingsHeader(
                deviceId: widget.deviceId,
                title: 'LED Strip Einstellungen',
                icon: Symbols.light_group,
              ),
              if (device != null) ...[
                SmartLedDeviceCard(
                  device: device,
                  stripIndex: _stripIndex,
                  showSettingsButton: false,
                  showDetailsButton: false,
                  onOpenDetails: () {},
                  onOpenSettings: () {},
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              _SettingsFieldCard(
                icon: Symbols.settings,
                iconColor: p.accentBlue,
                label: 'Anzahl LEDs',
                child: TextField(
                  controller: _ledCount,
                  enabled: _editing,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.cardGap),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        IconBox(
                          icon: Symbols.bolt,
                          color: p.accentPurple,
                        ),
                        const SizedBox(width: AppSpacing.gutter),
                        Text('Effekt', style: context.text.titleSmall),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Semantics(
                      button: true,
                      child: InkWell(
                        onTap: _editing ? () => _pickEffect(draft) : null,
                        borderRadius: AppRadius.mdAll,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${effect.number}. ${effect.name}',
                                  style: context.text.bodyMedium,
                                ),
                              ),
                              if (_editing)
                                Icon(
                                  Symbols.expand_more,
                                  color: context.colors.onSurfaceVariant,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _effectHint(effect),
                      style: context.text.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                      child: Divider(height: 1),
                    ),
                    SettingsRow.toggle(
                      icon: Symbols.auto_mode,
                      title: 'Automatik-Modus',
                      iconColor: p.accentIndigo,
                      value: draft.autoMode == 1,
                      onChanged: _editing
                          ? (v) => setState(
                                () => _draft =
                                    draft.copyWith(autoMode: v ? 1 : 0),
                              )
                          : (_) {},
                    ),
                    if (draft.autoMode == 1) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Auto-Intervall (s)',
                        style: context.text.labelMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        controller: _autoInterval,
                        enabled: _editing,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'-?\d+')),
                        ],
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: '0',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Intervall in Sekunden; im Gerät als auto_mode_time '
                        'in Millisekunden gespeichert.',
                        style: context.text.bodySmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Geschwindigkeit der Effekte',
                      style: context.text.labelMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: _speed,
                      enabled: _editing,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'-?\d+')),
                      ],
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: '500',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Höher = schneller. Negative Werte sind möglich.',
                      style: context.text.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.cardGap),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 520;
                  final brightness = _BrightnessCard(
                    title: 'Helligkeit',
                    controller: _brightness,
                    value: draft.brightness.clamp(1, 100),
                    enabled: _editing,
                    onSliderChanged: (v) {
                      _brightness.text = '$v';
                      setState(() => _draft = draft.copyWith(brightness: v));
                    },
                  );
                  final maxBrightness = _BrightnessCard(
                    title: 'Maximale Helligkeit',
                    controller: _maxBrightness,
                    value: draft.maxBrightness.clamp(1, 100),
                    enabled: _editing,
                    onSliderChanged: (v) {
                      _maxBrightness.text = '$v';
                      setState(() => _draft = draft.copyWith(maxBrightness: v));
                    },
                  );

                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: brightness),
                        const SizedBox(width: AppSpacing.cardGap),
                        Expanded(child: maxBrightness),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      brightness,
                      const SizedBox(height: AppSpacing.cardGap),
                      maxBrightness,
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.cardGap),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SettingsRow.toggle(
                      icon: Symbols.schedule,
                      title: 'Automatisch ausschalten',
                      iconColor: p.accentOrange,
                      value: draft.offAutomatic == 1,
                      onChanged: _editing
                          ? (v) => setState(
                                () => _draft =
                                    draft.copyWith(offAutomatic: v ? 1 : 0),
                              )
                          : (_) {},
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Schaltet diesen Strip nach Ablauf der Zeit aus.',
                      style: context.text.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                    if (draft.offAutomatic == 1) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Auto-Aus Zeit (HH:MM:SS)',
                        style: context.text.labelMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        controller: _offTime,
                        enabled: _editing,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: '00:00:00',
                          suffixIcon: Icon(Symbols.schedule),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (_editing)
                SaveCancelCard(
                  onCancel: () => _cancel(current),
                  onSave: () => _save(_draft ?? current),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SettingsFieldCard extends StatelessWidget {
  const _SettingsFieldCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.child,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconBox(icon: icon, color: iconColor, size: AppSizes.iconBoxSm),
              const SizedBox(width: AppSpacing.gutter),
              Text(label, style: context.text.titleSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _BrightnessCard extends StatelessWidget {
  const _BrightnessCard({
    required this.title,
    required this.controller,
    required this.value,
    required this.enabled,
    required this.onSliderChanged,
  });

  final String title;
  final TextEditingController controller;
  final int value;
  final bool enabled;
  final ValueChanged<int> onSliderChanged;

  @override
  Widget build(BuildContext context) {
    final primary = context.colors.primary;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Symbols.brightness_6,
                size: 20,
                color: context.palette.accentAmber,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(title, style: context.text.titleSmall),
              ),
              Text(
                '$value%',
                style: context.text.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: primary,
                ),
              ),
            ],
          ),
          Slider(
            value: value.toDouble(),
            min: 1,
            max: 100,
            divisions: 99,
            onChanged: enabled ? (v) => onSliderChanged(v.round()) : null,
          ),
          Row(
            children: [
              Text('Prozent:', style: context.text.bodySmall),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                width: 56,
                height: 36,
                child: TextField(
                  controller: controller,
                  enabled: enabled,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: context.text.bodyMedium,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.sm,
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (text) {
                    final parsed = int.tryParse(text);
                    if (parsed != null) onSliderChanged(parsed.clamp(1, 100));
                  },
                ),
              ),
              Text(
                '%',
                style: context.text.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
