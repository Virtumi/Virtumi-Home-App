import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/extensions/accent_resolver.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../shared/application/location_breadcrumb.dart';
import '../../../shared/models/models.dart';
import '../../../shared/providers/data_providers.dart';
import '../../../shared/providers/repository_providers.dart';
import '../../devices/presentation/widgets/location_icon_picker_sheet.dart';

/// Floors of a house ("Etagen"). Header card + tappable floor list.
class FloorsPage extends ConsumerStatefulWidget {
  const FloorsPage({super.key, required this.houseId});

  final String houseId;

  @override
  ConsumerState<FloorsPage> createState() => _FloorsPageState();
}

class _FloorsPageState extends ConsumerState<FloorsPage> {
  bool _editing = false;

  void _refresh() {
    ref.invalidate(floorsProvider(widget.houseId));
  }

  Future<void> _pickFloorIcon(Floor floor) async {
    final preset = await showLocationIconPickerSheet(
      context: context,
      title: 'Symbol für ${floor.name}',
      presets: LocationPresets.floor,
      selectedKey: floor.iconKey,
    );
    if (preset == null || !mounted) return;

    try {
      await ref
          .read(smartHomeRepositoryProvider)
          .updateFloorIcon(floor.id, preset.key);
      ref.invalidate(floorsProvider(widget.houseId));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Symbol konnte nicht gespeichert werden: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final floorsAsync = ref.watch(floorsProvider(widget.houseId));

    return AppScaffold(
      header: AppHeader(
        isEditing: _editing,
        onEdit: () => setState(() => _editing = !_editing),
        onRefresh: _refresh,
      ),
      body: AppScrollView(
        children: [
          SectionHeaderCard(
            title: 'Etagen',
            subtitle: locationBreadcrumb(ref, houseId: widget.houseId),
            icon: Symbols.layers,
            filled: true,
          ),
          AsyncValueView<List<Floor>>(
            value: floorsAsync,
            onRetry: _refresh,
            data: (floors) {
              if (floors.isEmpty) {
                return const EmptyState(
                  icon: Symbols.layers,
                  message: 'Noch keine Etagen vorhanden',
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final floor in floors) ...[
                    NavTileCard(
                      icon: floor.icon,
                      title: floor.name,
                      subtitle:
                          '${floor.roomCount} Räume \u00b7 ${floor.deviceCount} Geräte',
                      accent: context.accent(floor.accentKey),
                      showIconEditHint: _editing,
                      onTap: _editing
                          ? () => _pickFloorIcon(floor)
                          : () => context.push(Paths.rooms(floor.id)),
                    ),
                    const SizedBox(height: AppSpacing.cardGap),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
