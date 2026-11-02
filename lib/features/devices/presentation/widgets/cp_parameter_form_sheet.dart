import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/models.dart';
import 'cp_parameter_device_picker.dart';

/// Add/edit form for a Control Panel parameter slot.
class CpParameterFormSheet extends ConsumerStatefulWidget {
  const CpParameterFormSheet({
    super.key,
    required this.draft,
    required this.isNew,
    required this.excludeDeviceId,
    required this.onSave,
  });

  final CpParameter draft;
  final bool isNew;
  final String excludeDeviceId;
  final ValueChanged<CpParameter> onSave;

  @override
  ConsumerState<CpParameterFormSheet> createState() =>
      _CpParameterFormSheetState();
}

class _CpParameterFormSheetState extends ConsumerState<CpParameterFormSheet> {
  late CpParameter _draft = widget.draft;
  CpParameterDeviceOption? _selectedDevice;

  bool get _isSmartLed => CpDeviceType.isSmartLed(_draft.deviceType);

  void _update(CpParameter Function(CpParameter current) transform) {
    setState(() => _draft = transform(_draft));
  }

  String get _deviceLabel {
    final selected = _selectedDevice;
    if (selected != null) {
      final name = visibleStoredDeviceName(
        selected.name,
        firmwareType: selected.deviceType,
      );
      if (name.isNotEmpty) return name;
    }
    final draftName = visibleStoredDeviceName(
      _draft.name,
      firmwareType: _draft.deviceType,
    );
    if (draftName.isNotEmpty) return draftName;
    return 'Gerät auswählen';
  }

  CpParameterMode get _connectionMode =>
      CpParameterMode.fromValue(_draft.mode) ?? CpParameterMode.defaultMode;

  Future<void> _pickMode() async {
    final result = await showOptionPicker<CpParameterMode>(
      context: context,
      title: 'Verbindungsart',
      options: CpParameterMode.values,
      labelOf: (mode) => mode.label,
      selected: _connectionMode,
    );
    if (result != null) {
      _update((draft) => draft.copyWith(mode: result.value));
    }
  }

  Future<void> _pickFunction({
    required String title,
    required int currentValue,
    required ValueChanged<int> onSelected,
  }) async {
    final current = CpCommandFunction.fromValue(currentValue) ??
        CpCommandFunction.defaultFunction;
    final result = await showOptionPicker<CpCommandFunction>(
      context: context,
      title: title,
      options: CpCommandFunction.values,
      labelOf: (fn) => fn.label,
      selected: current,
    );
    if (result != null) onSelected(result.value);
  }

  CpParameter _finalizeDraft(CpParameter draft) {
    int existsFor(int active, int function) =>
        active == 1 && function > 0 ? 1 : 0;

    return draft.copyWith(
      command0ProtokolNr: 100,
      command1ProtokolNr: 100,
      command2ProtokolNr: 100,
      command0Exists: _isSmartLed
          ? existsFor(draft.command0Active, draft.command0Function)
          : null,
      command1Exists: _isSmartLed
          ? existsFor(draft.command1Active, draft.command1Function)
          : null,
      command2Exists: _isSmartLed
          ? existsFor(draft.command2Active, draft.command2Function)
          : null,
    );
  }

  Future<void> _pickDevice() async {
    final device = await showCpParameterDevicePicker(
      context: context,
      ref: ref,
      excludeDeviceId: widget.excludeDeviceId,
    );
    if (device == null || !mounted) return;
    setState(() {
      _selectedDevice = device;
      _draft = _draft.copyWith(
        name: device.name,
        code: device.code,
        macAddress: device.espnowMac,
        ipAddress: device.ipAddress,
        port: device.port,
        deviceType: device.deviceType,
      );
    });
  }

  void _save() {
    if (widget.isNew && _selectedDevice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte ein Gerät auswählen')),
      );
      return;
    }
    widget.onSave(_finalizeDraft(_draft));
  }

  @override
  Widget build(BuildContext context) {
    final device = _selectedDevice;

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
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
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
              Text(
                widget.isNew ? 'Parameter hinzufügen' : 'Parameter bearbeiten',
                style: context.text.titleMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                onTap: _pickDevice,
                child: Row(
                  children: [
                    IconBox(
                      icon: Symbols.devices,
                      color: context.colors.primary,
                    ),
                    const SizedBox(width: AppSpacing.gutter),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Gerät',
                            style: context.text.labelSmall,
                          ),
                          Text(
                            _deviceLabel,
                            style: context.text.bodyMedium,
                          ),
                          if (device != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              device.locationPath,
                              style: context.text.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(
                      Symbols.expand_more,
                      color: context.colors.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                onTap: _pickMode,
                child: Row(
                  children: [
                    IconBox(
                      icon: Symbols.lan,
                      color: context.palette.accentTeal,
                    ),
                    const SizedBox(width: AppSpacing.gutter),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Verbindungsart',
                            style: context.text.labelSmall,
                          ),
                          Text(
                            _connectionMode.label,
                            style: context.text.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Symbols.expand_more,
                      color: context.colors.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Aktiviert', style: context.text.bodyMedium),
                    ),
                    AppToggle(
                      value: _draft.enabled == 1,
                      onChanged: (value) =>
                          _update((d) => d.copyWith(enabled: value ? 1 : 0)),
                      semanticLabel: 'Parameter aktiviert',
                    ),
                  ],
                ),
              ),
              if (_isSmartLed) ...[
                const SizedBox(height: AppSpacing.md),
                _CommandSection(
                  title: 'Taste Mitte',
                  active: _draft.command0Active == 1,
                  functionValue: _draft.command0Function,
                  onActiveChanged: (value) => _update(
                    (d) => d.copyWith(command0Active: value ? 1 : 0),
                  ),
                  onPickFunction: () => _pickFunction(
                    title: 'Funktion Taste Mitte',
                    currentValue: _draft.command0Function,
                    onSelected: (value) =>
                        _update((d) => d.copyWith(command0Function: value)),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _CommandSection(
                  title: 'Taste Rechts',
                  active: _draft.command1Active == 1,
                  functionValue: _draft.command1Function,
                  onActiveChanged: (value) => _update(
                    (d) => d.copyWith(command1Active: value ? 1 : 0),
                  ),
                  onPickFunction: () => _pickFunction(
                    title: 'Funktion Taste Rechts',
                    currentValue: _draft.command1Function,
                    onSelected: (value) =>
                        _update((d) => d.copyWith(command1Function: value)),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _CommandSection(
                  title: 'Taste Links',
                  active: _draft.command2Active == 1,
                  functionValue: _draft.command2Function,
                  onActiveChanged: (value) => _update(
                    (d) => d.copyWith(command2Active: value ? 1 : 0),
                  ),
                  onPickFunction: () => _pickFunction(
                    title: 'Funktion Taste Links',
                    currentValue: _draft.command2Function,
                    onSelected: (value) =>
                        _update((d) => d.copyWith(command2Function: value)),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              SaveCancelCard(
                onCancel: () => Navigator.of(context).pop(),
                onSave: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommandSection extends StatelessWidget {
  const _CommandSection({
    required this.title,
    required this.active,
    required this.functionValue,
    required this.onActiveChanged,
    required this.onPickFunction,
  });

  final String title;
  final bool active;
  final int functionValue;
  final ValueChanged<bool> onActiveChanged;
  final VoidCallback onPickFunction;

  @override
  Widget build(BuildContext context) {
    final fn = CpCommandFunction.fromValue(functionValue) ??
        CpCommandFunction.defaultFunction;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: context.text.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              AppToggle(
                value: active,
                onChanged: onActiveChanged,
                semanticLabel: '$title aktiv',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SettingsRow.navigation(
            icon: Symbols.tune,
            title: 'Funktion',
            iconColor: context.palette.accentTeal,
            value: fn.label,
            onTap: active ? onPickFunction : null,
          ),
        ],
      ),
    );
  }
}

Future<void> showCpParameterFormSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String excludeDeviceId,
  required CpParameter draft,
  required bool isNew,
  required ValueChanged<CpParameter> onSave,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, _) => CpParameterFormSheet(
          draft: draft,
          isNew: isNew,
          excludeDeviceId: excludeDeviceId,
          onSave: (updated) {
            Navigator.of(context).pop();
            onSave(updated);
          },
        ),
      ),
    ),
  );
}
