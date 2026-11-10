import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../../core/theme/theme.dart';
import '../../../../../core/widgets/widgets.dart';
import '../../../../../shared/models/models.dart';
import '../device_settings_header.dart';
import '../update_hero_card.dart';
import '../update_settings_cards.dart';

class UpdateSettingsForm extends StatefulWidget {
  const UpdateSettingsForm({
    super.key,
    required this.config,
    required this.enabled,
    required this.onChanged,
    required this.onPickSchedule,
    required this.onPickWeekday,
    this.onStartUpdate,
    this.liveStatus,
    this.footer,
    this.deviceId,
  });

  final UpdateConfig config;
  final bool enabled;
  final ValueChanged<UpdateConfig> onChanged;
  final VoidCallback onPickSchedule;
  final VoidCallback onPickWeekday;
  final VoidCallback? onStartUpdate;
  final DeviceUpdateStatus? liveStatus;
  final Widget? footer;

  /// Set on the device settings page. The setup wizard leaves this empty.
  final String? deviceId;

  @override
  State<UpdateSettingsForm> createState() => _UpdateSettingsFormState();
}

class _UpdateSettingsFormState extends State<UpdateSettingsForm> {
  final _time = TextEditingController();
  UpdateConfig? _lastSynced;

  @override
  void initState() {
    super.initState();
    _time.addListener(_onTimeChanged);
    _syncTime();
  }

  void _onTimeChanged() {
    widget.onChanged(
      widget.config.copyWith(scheduledTime: _normalizeTime(_time.text)),
    );
  }

  @override
  void didUpdateWidget(covariant UpdateSettingsForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.scheduledTime != widget.config.scheduledTime) {
      _syncTime(force: true);
    }
  }

  void _syncTime({bool force = false}) {
    if (!force && _lastSynced?.scheduledTime == widget.config.scheduledTime) {
      return;
    }
    _lastSynced = widget.config;
    _time.text = _displayTime(widget.config.scheduledTime);
  }

  String _displayTime(String value) {
    if (value.length >= 5) return value.substring(0, 5);
    return value;
  }

  String _normalizeTime(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '23:50:00';
    if (RegExp(r'^\d{2}:\d{2}$').hasMatch(trimmed)) return '$trimmed:00';
    if (RegExp(r'^\d{2}:\d{2}:\d{2}$').hasMatch(trimmed)) return trimmed;
    return trimmed;
  }

  Future<void> _pickTime() async {
    final parts = _normalizeTime(_time.text).split(':');
    final hour = parts.isNotEmpty ? int.tryParse(parts[0]) : null;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) : null;
    final initial = TimeOfDay(hour: hour ?? 23, minute: minute ?? 50);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      useRootNavigator: true,
    );
    if (picked != null) {
      final formatted =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() => _time.text = formatted);
      widget.onChanged(
        widget.config.copyWith(scheduledTime: _normalizeTime(formatted)),
      );
    }
  }

  @override
  void dispose() {
    _time.removeListener(_onTimeChanged);
    _time.dispose();
    super.dispose();
  }

  Widget _settingsGrid(UpdateConfig draft) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= AppSizes.tabletBreakpoint;
        final status = UpdateStatusCard(
          enabled: draft.autoUpdatesEnabled,
          editing: widget.enabled,
          onChanged: (value) =>
              widget.onChanged(draft.copyWith(autoUpdatesEnabled: value)),
        );
        final modus = UpdateModusCard(
          schedule: draft.updateSchedule,
          weekday: draft.weekday,
          editing: widget.enabled,
          onScheduleTap: widget.onPickSchedule,
          onWeekdayTap: widget.onPickWeekday,
        );
        final time = UpdateTimeCard(
          editing: widget.enabled,
          controller: _time,
          onPickTime: _pickTime,
        );

        if (!draft.autoUpdatesEnabled) {
          return status;
        }

        if (!wide) {
          return Column(
            children: [
              status,
              const SizedBox(height: AppSpacing.cardGap),
              modus,
              const SizedBox(height: AppSpacing.cardGap),
              time,
            ],
          );
        }

        return Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: status),
                const SizedBox(width: AppSpacing.cardGap),
                Expanded(child: modus),
              ],
            ),
            const SizedBox(height: AppSpacing.cardGap),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: time),
                const Expanded(child: SizedBox.shrink()),
              ],
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final draft = widget.config;
    final liveStatus = widget.liveStatus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.deviceId != null)
          DeviceSettingsHeader(
            deviceId: widget.deviceId!,
            title: 'Update Einstellungen',
            icon: Symbols.update,
          )
        else
          const SectionHeaderCard(
            title: 'Update Einstellungen',
            icon: Symbols.update,
            filled: true,
          ),
        const SizedBox(height: AppSpacing.cardGap),
        if (liveStatus?.status == 'failed') ...[
          AppCard(
            child: Text(
              liveStatus!.errorMessage ?? 'Update fehlgeschlagen',
              style: context.text.bodyMedium?.copyWith(
                color: context.colors.error,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.cardGap),
        ],
        UpdateHeroCard(
          config: draft,
          onStartUpdate: widget.onStartUpdate ?? () {},
        ),
        const AppSectionLabel('Aktuelle Version'),
        GroupedListCard(
          children: [
            SettingsRow.navigation(
              icon: Symbols.info,
              title: draft.currentVersion,
              iconColor: p.accentBlue,
            ),
          ],
        ),
        const AppSectionLabel('Update Einstellungen'),
        _settingsGrid(draft),
        if (widget.footer != null) widget.footer!,
      ],
    );
  }
}
