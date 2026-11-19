import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/theme/theme.dart';
import '../../../../shared/models/models.dart';

/// Scrollable bottom sheet to pick one of 102 Smart LED effects.
Future<SmartLedEffect?> showSmartLedEffectPicker({
  required BuildContext context,
  required int selectedNumber,
}) {
  return showModalBottomSheet<SmartLedEffect>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (context) => _SmartLedEffectPickerSheet(selectedNumber: selectedNumber),
  );
}

class _SmartLedEffectPickerSheet extends StatefulWidget {
  const _SmartLedEffectPickerSheet({required this.selectedNumber});

  final int selectedNumber;

  @override
  State<_SmartLedEffectPickerSheet> createState() =>
      _SmartLedEffectPickerSheetState();
}

class _SmartLedEffectPickerSheetState extends State<_SmartLedEffectPickerSheet> {
  late List<SmartLedEffect> _filtered;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filtered = smartLedEffects;
    _search.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _applyFilter() {
    final query = _search.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filtered = smartLedEffects;
        return;
      }
      _filtered = smartLedEffects.where((effect) {
        return effect.name.toLowerCase().contains(query) ||
            effect.number.toString().contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            margin: const EdgeInsets.all(AppSpacing.gutter),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: AppRadius.cardLgAll,
              boxShadow: context.palette.raised,
            ),
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.colors.outlineVariant,
                    borderRadius: AppRadius.full,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text('LED-Effekt wählen', style: context.text.titleMedium),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: TextField(
                    controller: _search,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Symbols.search),
                      hintText: 'Effekt suchen…',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final effect = _filtered[index];
                      final selected = effect.number == widget.selectedNumber;
                      final primary = context.colors.primary;
                      return ListTile(
                        selected: selected,
                        title: Text(
                          effect.name,
                          style: context.text.bodyLarge?.copyWith(
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected ? primary : null,
                          ),
                        ),
                        subtitle: effect.needsSecondaryColor
                            ? Text(
                                'Sekundärfarbe',
                                style: context.text.bodySmall,
                              )
                            : null,
                        trailing: selected
                            ? Icon(Symbols.check_circle, color: primary, fill: 1)
                            : null,
                        onTap: () => Navigator.of(context).pop(effect),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
