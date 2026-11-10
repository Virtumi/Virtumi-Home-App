import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/supabase/realtime_guard.dart';
import '../../../../core/supabase/realtime_service.dart';
import '../../../../core/supabase/supabase_client.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/application/direct_device_link.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/providers/data_providers.dart';
import '../../../../shared/providers/repository_providers.dart';
import '../../../devices/presentation/widgets/led_color_palette.dart';
import 'device_card_text_styles.dart';
import 'device_online_badge.dart';
import 'smart_led_effect_picker.dart';

/// Room card for Smart LED devices: quick control for power, color, brightness
/// and effect (strip 1), distinct from [ControlPanelDeviceCard].
class SmartLedDeviceCard extends ConsumerStatefulWidget {
  const SmartLedDeviceCard({
    super.key,
    required this.device,
    required this.onOpenDetails,
    required this.onOpenSettings,
    this.stripIndex = 1,
    this.showSettingsButton = true,
    this.showDetailsButton = true,
    this.showExtendedEffectControls = false,
    this.showEffectPicker = true,
    this.refreshGeneration = 0,
  });

  final Device device;
  final VoidCallback onOpenDetails;
  final VoidCallback onOpenSettings;
  final int stripIndex;
  final bool showSettingsButton;
  final bool showDetailsButton;
  final bool showExtendedEffectControls;
  final bool showEffectPicker;

  /// Incremented by the details screen refresh button. While this differs from
  /// the last applied value, optimistic edits are dropped and the card waits
  /// for a fresh read (UDP in direct mode, smart_led_settings in cloud mode).
  final int refreshGeneration;

  @override
  ConsumerState<SmartLedDeviceCard> createState() => _SmartLedDeviceCardState();
}

class _SmartLedDeviceCardState extends ConsumerState<SmartLedDeviceCard> {
  RealtimeService? _realtime;

  /// Optimistic strip so power/color/etc. update immediately on tap.
  SmartLedStrip? _pendingStrip;

  /// Last [SmartLedDeviceCard.refreshGeneration] whose reload has finished.
  int _seenRefreshGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Seed UDP endpoint cache so the first command skips Supabase lookup.
      ref.read(deviceEndpointResolverProvider).cacheFromDevice(widget.device);
      if (!useSupabaseRealtime(ref)) return;
      _realtime = RealtimeService(ref.read(supabaseClientProvider));
      _realtime!.subscribeToDeviceTable(
        deviceId: widget.device.id,
        table: 'smart_led_settings',
        onChange: () =>
            ref.invalidate(smartLedStripsProvider(widget.device.id)),
      );
    });
  }

  @override
  void didUpdateWidget(covariant SmartLedDeviceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.device.id != widget.device.id ||
        oldWidget.device.ipAddress != widget.device.ipAddress ||
        oldWidget.device.serialNumber != widget.device.serialNumber) {
      ref.read(deviceEndpointResolverProvider).cacheFromDevice(widget.device);
    }
  }

  @override
  void dispose() {
    _realtime?.unsubscribeAll();
    super.dispose();
  }

  Future<void> _save(SmartLedStrip strip) async {
    final previous = _pendingStrip;
    // Optimistic UI first — never wait for UDP before updating controls.
    setState(() => _pendingStrip = strip);
    try {
      await ref
          .read(smartLedRepositoryProvider)
          .saveStrip(widget.device.id, strip, quickControl: true);
    } catch (e) {
      if (mounted && identical(_pendingStrip, strip)) {
        setState(() => _pendingStrip = previous);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fehler beim Speichern: $e')));
      }
    }
  }

  void _saveQuick(SmartLedStrip strip) => unawaited(_save(strip));

  SmartLedStrip _stripOrDefault(List<SmartLedStrip> strips) {
    final loaded = strips.firstWhere(
      (s) => s.ledIndex == widget.stripIndex,
      orElse: () => SmartLedStrip(ledIndex: widget.stripIndex),
    );
    final pending = _pendingStrip;
    if (pending != null && pending.ledIndex == widget.stripIndex) {
      return pending;
    }
    return loaded;
  }

  Future<void> _pickCustomColor(
    SmartLedStrip strip, {
    required bool secondary,
  }) async {
    final initial = secondary ? strip.ledColorValue2 : strip.ledColorValue;
    final picked = await showColorPicker(
      context: context,
      initialColor: Color(initial),
    );
    if (picked == null) return;
    final updated = secondary
        ? strip.copyWith(ledColorValue2: picked.toARGB32())
        : strip.copyWith(ledColorValue: picked.toARGB32());
    _saveQuick(updated);
  }

  Future<void> _pickEffect(SmartLedStrip strip) async {
    final picked = await showSmartLedEffectPicker(
      context: context,
      selectedNumber: strip.effectNumber,
    );
    if (picked == null) return;
    var updated = strip.copyWith(effectNumber: picked.number);
    if (picked.number == -1) {
      updated = updated.copyWith(ledOn: 0);
    } else if (strip.ledOn == 0) {
      updated = updated.copyWith(ledOn: 1);
    }
    _saveQuick(updated);
  }

  @override
  Widget build(BuildContext context) {
    final online = deviceIsOnline(ref, widget.device);
    final primary = context.colors.primary;
    if (!online) {
      return AppCard(
        padding: const EdgeInsets.all(AppSpacing.containerPadding),
        child: Row(
          children: [
            IconBox(
              icon: Symbols.light_group,
              color: primary,
              size: AppSizes.iconBoxMd,
              filled: true,
            ),
            const SizedBox(width: AppSpacing.gutter),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.device.name,
                    style: DeviceCardTextStyles.title(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Smart LED',
                    style: DeviceCardTextStyles.subtitle(context),
                  ),
                ],
              ),
            ),
            DeviceOnlineBadge(device: widget.device),
          ],
        ),
      );
    }

    final stripsAsync = ref.watch(smartLedStripsProvider(widget.device.id));
    final awaitingRefresh = widget.refreshGeneration != _seenRefreshGeneration;
    final strips = stripsAsync.value;
    // First open has no strip yet. A refresh keeps the previous value so the
    // controls stay on screen while status, color, brightness and effect reload.
    if (strips == null) {
      if (stripsAsync.hasError) {
        return AppCard(
          padding: const EdgeInsets.all(AppSpacing.containerPadding),
          child: Text(
            'Smart LED konnte nicht geladen werden: ${stripsAsync.error}',
          ),
        );
      }
      return const AppCard(
        padding: EdgeInsets.all(AppSpacing.containerPadding),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (awaitingRefresh && !stripsAsync.isLoading) {
      // Fresh read finished: show the device/cloud values, not the last tap.
      _pendingStrip = null;
      _seenRefreshGeneration = widget.refreshGeneration;
    }

    final strip = _stripOrDefault(strips);
    final isOn = strip.ledOn == 1 && strip.effectNumber != -1;
    final effect = smartLedEffectByNumber(strip.effectNumber);
    final needsSecondary = effect.needsSecondaryColor;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.containerPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconBox(
                icon: Symbols.light_group,
                color: isOn ? context.palette.accentAmber : primary,
                size: AppSizes.iconBoxMd,
                filled: true,
              ),
              const SizedBox(width: AppSpacing.gutter),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.device.name,
                      style: DeviceCardTextStyles.title(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Smart LED',
                      style: DeviceCardTextStyles.subtitle(context),
                    ),
                  ],
                ),
              ),
              DeviceOnlineBadge(device: widget.device),
              if (widget.showSettingsButton) ...[
                const SizedBox(width: AppSpacing.sm),
                NeumorphicIconButton(
                  icon: Symbols.settings,
                  iconColor: context.colors.onSurface,
                  size: 40,
                  iconSize: 20,
                  tooltip: 'Geräteeinstellungen',
                  onPressed: widget.onOpenSettings,
                ),
              ],
              if (widget.showSettingsButton && widget.showDetailsButton)
                const SizedBox(width: AppSpacing.sm),
              if (widget.showDetailsButton)
                _PrimaryNavButton(onPressed: widget.onOpenDetails),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _LedPowerButton(
            isOn: isOn,
            enabled: true,
            onPressed: () {
              final updated = strip.copyWith(
                ledOn: isOn ? 0 : 1,
                effectNumber: !isOn && strip.effectNumber == -1
                    ? 0
                    : strip.effectNumber,
              );
              _saveQuick(updated);
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Primärfarbe',
            style: DeviceCardTextStyles.caption(context, emphasis: true),
          ),
          const SizedBox(height: AppSpacing.sm),
          LedColorPalette(
            compact: true,
            selectedValue: strip.ledColorValue,
            enabled: true,
            onSelected: (value) =>
                _saveQuick(strip.copyWith(ledColorValue: value)),
            onCustomTap: () => _pickCustomColor(strip, secondary: false),
          ),
          if (needsSecondary) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Sekundärfarbe',
              style: DeviceCardTextStyles.caption(context, emphasis: true),
            ),
            const SizedBox(height: AppSpacing.sm),
            LedColorPalette(
              compact: true,
              selectedValue: strip.ledColorValue2,
              enabled: true,
              onSelected: (value) =>
                  _saveQuick(strip.copyWith(ledColorValue2: value)),
              onCustomTap: () => _pickCustomColor(strip, secondary: true),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          _CompactBrightness(
            value: strip.brightness.clamp(1, 100),
            enabled: true,
            onChangedEnd: (value) =>
                _saveQuick(strip.copyWith(brightness: value)),
          ),
          if (widget.showEffectPicker) ...[
            const SizedBox(height: AppSpacing.md),
            PressScale(
              onTap: () => _pickEffect(strip),
              semanticLabel: 'Effekt: ${effect.name}',
              child: NeumorphicContainer(
                style: NeumorphicStyle.sunken,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.gutter,
                ),
                borderRadius: AppRadius.mdAll,
                child: Row(
                  children: [
                    IconBox(
                      icon: Symbols.auto_awesome,
                      color: context.palette.accentPurple,
                      size: 36,
                    ),
                    const SizedBox(width: AppSpacing.gutter),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Effekt',
                            style: DeviceCardTextStyles.caption(context),
                          ),
                          Text(
                            effect.name,
                            style: DeviceCardTextStyles.subtitle(context),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Symbols.chevron_right,
                      color: context.colors.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (widget.showExtendedEffectControls) ...[
            const SizedBox(height: AppSpacing.md),
            _CompactIntField(
              label: 'Effektgeschwindigkeit',
              value: strip.speed,
              hint: '500',
              enabled: true,
              onSubmitted: (value) => _saveQuick(strip.copyWith(speed: value)),
            ),
            const SizedBox(height: AppSpacing.md),
            SettingsRow.toggle(
              icon: Symbols.auto_mode,
              title: 'Automatik-Modus',
              iconColor: context.palette.accentIndigo,
              value: strip.autoMode == 1,
              onChanged: (v) => _saveQuick(strip.copyWith(autoMode: v ? 1 : 0)),
            ),
            if (strip.autoMode == 1) ...[
              const SizedBox(height: AppSpacing.md),
              _CompactIntField(
                label: 'Intervall (s)',
                value: (strip.autoModeTime / 1000).round(),
                hint: '0',
                enabled: true,
                onSubmitted: (seconds) =>
                    _saveQuick(strip.copyWith(autoModeTime: seconds * 1000)),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _CompactIntField extends StatefulWidget {
  const _CompactIntField({
    required this.label,
    required this.value,
    required this.onSubmitted,
    this.hint,
    this.enabled = true,
  });

  final String label;
  final int value;
  final String? hint;
  final bool enabled;
  final ValueChanged<int> onSubmitted;

  @override
  State<_CompactIntField> createState() => _CompactIntFieldState();
}

class _CompactIntFieldState extends State<_CompactIntField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.value}');
  }

  @override
  void didUpdateWidget(_CompactIntField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value &&
        _controller.text != '${widget.value}') {
      _controller.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final parsed = int.tryParse(_controller.text.trim());
    if (parsed != null) widget.onSubmitted(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.label,
          style: DeviceCardTextStyles.caption(context, emphasis: true),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _controller,
          enabled: widget.enabled,
          keyboardType: const TextInputType.numberWithOptions(signed: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'-?\d+')),
          ],
          decoration: InputDecoration(
            isDense: true,
            hintText: widget.hint,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
          ),
          onSubmitted: (_) => _submit(),
          onEditingComplete: _submit,
        ),
      ],
    );
  }
}

class _LedPowerButton extends StatelessWidget {
  const _LedPowerButton({
    required this.isOn,
    required this.onPressed,
    this.enabled = true,
  });

  final bool isOn;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final amber = context.palette.accentAmber;
    final label = isOn ? 'LED ausschalten' : 'LED einschalten';
    final icon = isOn ? Symbols.lightbulb : Symbols.light_off;
    final fg = isOn ? Colors.white : context.colors.onSurface;

    final decoration = isOn
        ? BoxDecoration(
            gradient: LinearGradient(
              colors: [amber, context.palette.accentOrange],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: AppRadius.full,
            boxShadow: [
              BoxShadow(
                color: amber.withValues(alpha: 0.45),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          )
        : BoxDecoration(
            color: context.palette.controlSurface,
            borderRadius: AppRadius.full,
            border: context.palette.flatElevation
                ? Border.all(color: context.palette.cardBorder)
                : null,
            boxShadow: context.palette.flatElevation
                ? null
                : context.palette.raised,
          );

    return PressScale(
      enabled: enabled,
      onTap: enabled ? onPressed : null,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        height: 48,
        decoration: decoration,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: fg, size: 22, fill: isOn ? 1 : 0),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: context.text.bodyMedium?.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryNavButton extends StatelessWidget {
  const _PrimaryNavButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final primary = context.colors.primary;

    return PressScale(
      style: PressScaleStyle.compact,
      onTap: onPressed,
      semanticLabel: 'Gerätedetails',
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Icon(
          Symbols.arrow_forward,
          color: context.colors.onPrimary,
          size: 20,
        ),
      ),
    );
  }
}

class _CompactBrightness extends StatefulWidget {
  const _CompactBrightness({
    required this.value,
    required this.onChangedEnd,
    this.enabled = true,
  });

  final int value;
  final ValueChanged<int> onChangedEnd;
  final bool enabled;

  @override
  State<_CompactBrightness> createState() => _CompactBrightnessState();
}

class _CompactBrightnessState extends State<_CompactBrightness> {
  late double _localValue;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _localValue = widget.value.toDouble().clamp(1, 100);
  }

  @override
  void didUpdateWidget(_CompactBrightness oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isDragging && oldWidget.value != widget.value) {
      _localValue = widget.value.toDouble().clamp(1, 100);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = context.colors.primary;
    final displayValue = _localValue.round();

    return Column(
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
            Text(
              'Helligkeit',
              style: DeviceCardTextStyles.caption(context, emphasis: true),
            ),
            const Spacer(),
            Text(
              '$displayValue%',
              style: context.text.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: primary,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 6,
            activeTrackColor: primary,
            inactiveTrackColor: context.colors.surfaceContainerHighest,
            thumbColor: Colors.white,
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
          ),
          child: Slider(
            value: _localValue.clamp(1, 100),
            min: 1,
            max: 100,
            onChangeStart: widget.enabled
                ? (_) => setState(() => _isDragging = true)
                : null,
            onChanged: widget.enabled
                ? (value) => setState(() => _localValue = value)
                : null,
            onChangeEnd: widget.enabled
                ? (value) {
                    setState(() {
                      _isDragging = false;
                      _localValue = value;
                    });
                    widget.onChangedEnd(value.round());
                  }
                : null,
          ),
        ),
      ],
    );
  }
}
