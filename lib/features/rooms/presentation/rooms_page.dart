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

/// Rooms of a floor ("Räume"). Header card + tappable room list.
class RoomsPage extends ConsumerStatefulWidget {
  const RoomsPage({super.key, required this.floorId});

  final String floorId;

  @override
  ConsumerState<RoomsPage> createState() => _RoomsPageState();
}

class _RoomsPageState extends ConsumerState<RoomsPage> {
  bool _editing = false;

  void _refresh() {
    ref.invalidate(roomsProvider(widget.floorId));
  }

  Future<void> _pickRoomIcon(Room room) async {
    final preset = await showLocationIconPickerSheet(
      context: context,
      title: 'Symbol für ${room.name}',
      presets: LocationPresets.room,
      selectedKey: room.iconKey,
    );
    if (preset == null || !mounted) return;

    try {
      await ref
          .read(smartHomeRepositoryProvider)
          .updateRoomIcon(room.id, preset.key);
      ref.invalidate(roomsProvider(widget.floorId));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Symbol konnte nicht gespeichert werden: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomsAsync = ref.watch(roomsProvider(widget.floorId));

    return AppScaffold(
      header: AppHeader(
        isEditing: _editing,
        onEdit: () => setState(() => _editing = !_editing),
        onRefresh: _refresh,
      ),
      body: AppScrollView(
        children: [
          SectionHeaderCard(
            title: 'Räume',
            subtitle: locationBreadcrumb(
              ref,
              floorId: widget.floorId,
              includeFloor: true,
            ),
            icon: Symbols.meeting_room,
            accent: AppColors.accentCyan,
            filled: true,
          ),
          AsyncValueView<List<Room>>(
            value: roomsAsync,
            onRetry: _refresh,
            data: (rooms) {
              if (rooms.isEmpty) {
                return const EmptyState(
                  icon: Symbols.meeting_room,
                  message: 'Noch keine Räume vorhanden',
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final room in rooms) ...[
                    NavTileCard(
                      icon: room.icon,
                      title: room.name,
                      subtitle: '${room.deviceCount} Geräte',
                      accent: context.accent(room.accentKey),
                      showIconEditHint: _editing,
                      onTap: _editing
                          ? () => _pickRoomIcon(room)
                          : () => context.push(Paths.roomOverview(room.id)),
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
