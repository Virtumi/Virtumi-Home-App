import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/refresh_on_show.dart';
import '../../../core/widgets/widgets.dart';
import '../../../shared/application/recent_house_activity.dart';
import '../../../shared/models/models.dart';
import '../../../shared/providers/data_providers.dart';
import '../../../shared/providers/repository_providers.dart';
import '../../devices/presentation/widgets/location_icon_picker_sheet.dart';

/// All houses of the account with edit mode for house icons.
class AllHousesPage extends ConsumerStatefulWidget {
  const AllHousesPage({super.key});

  @override
  ConsumerState<AllHousesPage> createState() => _AllHousesPageState();
}

class _AllHousesPageState extends ConsumerState<AllHousesPage>
    with RefreshOnShow {
  bool _editing = false;

  @override
  void refreshOnShow() => _refresh();

  void _refresh() {
    ref.invalidate(housesProvider);
    ref.invalidate(recentHomesProvider);
  }

  Future<void> _openHouse(House house) async {
    await ref.read(recentHouseActivityProvider.notifier).record(house.id);
    if (!mounted) return;
    context.push(Paths.floors(house.id));
  }

  Future<void> _pickHouseIcon(House house) async {
    final preset = await showLocationIconPickerSheet(
      context: context,
      title: 'Symbol für ${house.name}',
      presets: LocationPresets.house,
      selectedKey: house.iconKey,
    );
    if (preset == null || !mounted) return;

    try {
      await ref
          .read(smartHomeRepositoryProvider)
          .updateHouseIcon(house.id, preset.key);
      ref.invalidate(housesProvider);
      ref.invalidate(recentHomesProvider);
      ref.invalidate(houseProvider(house.id));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Symbol konnte nicht gespeichert werden: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    trackVisibility();
    final housesAsync = ref.watch(housesProvider);
    // Shared (non-owned) houses cannot be re-iconed.
    final ownedIds = ref.watch(ownedLocationIdsProvider).value;
    bool owns(String id) =>
        id.startsWith('syn:') || (ownedIds?.contains(id) ?? false);

    return AppScaffold(
      header: AppHeader(
        isEditing: _editing,
        onEdit: () => setState(() => _editing = !_editing),
        onRefresh: _refresh,
      ),
      body: AppScrollView(
        children: [
          const SectionHeaderCard(
            title: 'Meine Häuser',
            icon: Symbols.home,
            filled: true,
          ),
          AsyncValueView<List<House>>(
            value: housesAsync,
            onRetry: _refresh,
            data: (houses) {
              if (houses.isEmpty) {
                return const EmptyState(
                  icon: Symbols.home,
                  message: 'Noch keine Häuser vorhanden',
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final house in houses) ...[
                    NavTileCard(
                      icon: house.icon,
                      title: house.name,
                      subtitle:
                          '${house.deviceCount} Geräte \u00b7 ${house.roomCount} Räume',
                      accent: context.colors.primary,
                      showIconEditHint: _editing && owns(house.id),
                      onTap: _editing && owns(house.id)
                          ? () => _pickHouseIcon(house)
                          : () => _openHouse(house),
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
