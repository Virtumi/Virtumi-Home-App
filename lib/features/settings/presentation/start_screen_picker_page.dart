import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/extensions/accent_resolver.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/navigation/start_route_providers.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../shared/models/models.dart';
import '../../../shared/providers/data_providers.dart';
import '../../../shared/providers/repository_providers.dart';

enum _PickerLevel { root, floors, rooms, roomOverview }

/// Lets the user pick the screen opened after login / app launch.
class StartScreenPickerPage extends ConsumerStatefulWidget {
  const StartScreenPickerPage({super.key});

  @override
  ConsumerState<StartScreenPickerPage> createState() =>
      _StartScreenPickerPageState();
}

class _StartScreenPickerPageState extends ConsumerState<StartScreenPickerPage> {
  _PickerLevel _level = _PickerLevel.root;
  String? _houseId;
  String? _floorId;
  String? _roomId;
  bool _saving = false;

  bool get _isRoot => _level == _PickerLevel.root;

  void _goBack() {
    if (_isRoot) {
      context.pop();
      return;
    }

    setState(() {
      switch (_level) {
        case _PickerLevel.roomOverview:
          _level = _PickerLevel.rooms;
          _roomId = null;
        case _PickerLevel.rooms:
          _level = _PickerLevel.floors;
          _floorId = null;
        case _PickerLevel.floors:
          _level = _PickerLevel.root;
          _houseId = null;
        case _PickerLevel.root:
          break;
      }
    });
  }

  Future<void> _selectRoute(
    BuildContext context,
    AppSettings settings,
    String route,
    String label,
  ) async {
    if (_saving) return;

    if (route == settings.startRoute) {
      if (context.mounted) context.pop();
      return;
    }

    setState(() => _saving = true);

    try {
      final updated = settings.copyWith(startRoute: route);
      await ref.read(appSettingsRepositoryProvider).saveSettings(updated);
      ref.invalidate(appSettingsProvider);
      ref.read(effectiveStartRouteProvider.notifier).setRoute(route);
      ref.read(routerRedirectTriggerProvider).refresh();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Startbild: $label')),
        );
        context.pop();
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Startbild konnte nicht gespeichert werden: $error',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(appSettingsProvider);

    return AppScaffold(
      header: AppHeader(onBack: _goBack),
      body: AsyncValueView<AppSettings?>(
        value: settingsAsync,
        onRetry: () => ref.invalidate(appSettingsProvider),
        data: (settings) {
          if (settings == null) {
            return const EmptyState(
              icon: Symbols.home,
              message: 'Einstellungen nicht verfügbar',
            );
          }

          if (_saving) {
            return const Center(child: CircularProgressIndicator());
          }

          return AppScrollView(
            children: [
              SectionHeaderCard(
                title: _headerTitle,
                icon: _headerIcon,
                subtitle:
                    'Als Startbild wählen oder weiter navigieren, um tiefer auszuwählen.',
              ),
              _SelectStartBanner(
                icon: _selectIcon,
                title: _selectTitle,
                subtitle: _selectSubtitle,
                accent: context.colors.primary,
                selected: settings.startRoute == _currentRoute,
                onTap: () => _selectRoute(
                  context,
                  settings,
                  _currentRoute,
                  _selectTitle,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ...switch (_level) {
                _PickerLevel.root => [_RootDrillDown(onOpenHouse: _openHouse)],
                _PickerLevel.floors => [
                    _FloorsDrillDown(
                      houseId: _houseId!,
                      onOpenFloor: _openFloor,
                    ),
                  ],
                _PickerLevel.rooms => [
                    _RoomsDrillDown(
                      floorId: _floorId!,
                      onOpenRoom: _openRoom,
                    ),
                  ],
                _PickerLevel.roomOverview => [
                    _DevicesSelectList(
                      roomId: _roomId!,
                      selectedRoute: settings.startRoute,
                      onSelectDevice: (device) => _selectRoute(
                        context,
                        settings,
                        Paths.deviceDetails(device.id),
                        '${device.displayName} · Geräte-Übersicht',
                      ),
                    ),
                  ],
              },
            ],
          );
        },
      ),
    );
  }

  void _openHouse(String houseId) {
    setState(() {
      _level = _PickerLevel.floors;
      _houseId = houseId;
    });
  }

  void _openFloor(String floorId) {
    setState(() {
      _level = _PickerLevel.rooms;
      _floorId = floorId;
    });
  }

  void _openRoom(String roomId) {
    setState(() {
      _level = _PickerLevel.roomOverview;
      _roomId = roomId;
    });
  }

  String get _currentRoute => switch (_level) {
        _PickerLevel.root => Paths.home,
        _PickerLevel.floors => Paths.floors(_houseId!),
        _PickerLevel.rooms => Paths.rooms(_floorId!),
        _PickerLevel.roomOverview => Paths.roomOverview(_roomId!),
      };

  String get _headerTitle => switch (_level) {
        _PickerLevel.root => 'Startbild',
        _PickerLevel.floors => 'Etagen',
        _PickerLevel.rooms => 'Räume',
        _PickerLevel.roomOverview => 'Raum-Übersicht',
      };

  IconData get _headerIcon => switch (_level) {
        _PickerLevel.root => Symbols.home,
        _PickerLevel.floors => Symbols.layers,
        _PickerLevel.rooms => Symbols.meeting_room,
        _PickerLevel.roomOverview => Symbols.dashboard,
      };

  IconData get _selectIcon => switch (_level) {
        _PickerLevel.root => Symbols.home,
        _PickerLevel.floors => Symbols.layers,
        _PickerLevel.rooms => Symbols.meeting_room,
        _PickerLevel.roomOverview => Symbols.dashboard,
      };

  String get _selectTitle => switch (_level) {
        _PickerLevel.root => 'Home als Startbild wählen',
        _PickerLevel.floors => 'Etagen als Startbild wählen',
        _PickerLevel.rooms => 'Räume als Startbild wählen',
        _PickerLevel.roomOverview => 'Raum-Übersicht als Startbild wählen',
      };

  String get _selectSubtitle => switch (_level) {
        _PickerLevel.root => 'Startet in der Home-Ansicht',
        _PickerLevel.floors => 'Startet in der Etagen-Übersicht',
        _PickerLevel.rooms => 'Startet in der Räume-Übersicht',
        _PickerLevel.roomOverview => 'Startet in der gewählten Raum-Übersicht',
      };
}

class _SelectStartBanner extends StatelessWidget {
  const _SelectStartBanner({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionBannerCard(
      icon: icon,
      title: title,
      subtitle: subtitle,
      accent: accent,
      trailingIcon: selected ? Symbols.check_circle : Symbols.touch_app,
      onTap: onTap,
    );
  }
}

class _RootDrillDown extends ConsumerWidget {
  const _RootDrillDown({required this.onOpenHouse});

  final ValueChanged<String> onOpenHouse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final housesAsync = ref.watch(housesProvider);

    return AsyncValueView<List<House>>(
      value: housesAsync,
      onRetry: () => ref.invalidate(housesProvider),
      data: (houses) {
        if (houses.isEmpty) {
          return const EmptyState(
            icon: Symbols.home_work,
            message: 'Noch keine Häuser vorhanden',
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppSectionLabel('Etagen'),
            for (final house in houses) ...[
              NavTileCard(
                icon: house.icon,
                title: house.name,
                subtitle:
                    '${house.floorCount} Etagen · ${house.roomCount} Räume',
                accent: context.colors.primary,
                onTap: () => onOpenHouse(house.id),
              ),
              const SizedBox(height: AppSpacing.cardGap),
            ],
          ],
        );
      },
    );
  }
}

class _FloorsDrillDown extends ConsumerWidget {
  const _FloorsDrillDown({
    required this.houseId,
    required this.onOpenFloor,
  });

  final String houseId;
  final ValueChanged<String> onOpenFloor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final floorsAsync = ref.watch(floorsProvider(houseId));

    return AsyncValueView<List<Floor>>(
      value: floorsAsync,
      onRetry: () => ref.invalidate(floorsProvider(houseId)),
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
            const AppSectionLabel('Räume'),
            for (final floor in floors) ...[
              NavTileCard(
                icon: floor.icon,
                title: floor.name,
                subtitle:
                    '${floor.roomCount} Räume · ${floor.deviceCount} Geräte',
                accent: context.accent(floor.accentKey),
                onTap: () => onOpenFloor(floor.id),
              ),
              const SizedBox(height: AppSpacing.cardGap),
            ],
          ],
        );
      },
    );
  }
}

class _RoomsDrillDown extends ConsumerWidget {
  const _RoomsDrillDown({
    required this.floorId,
    required this.onOpenRoom,
  });

  final String floorId;
  final ValueChanged<String> onOpenRoom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsAsync = ref.watch(roomsProvider(floorId));

    return AsyncValueView<List<Room>>(
      value: roomsAsync,
      onRetry: () => ref.invalidate(roomsProvider(floorId)),
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
            const AppSectionLabel('Raum-Übersicht'),
            for (final room in rooms) ...[
              NavTileCard(
                icon: room.icon,
                title: room.name,
                subtitle: '${room.deviceCount} Geräte',
                accent: context.accent(room.accentKey),
                onTap: () => onOpenRoom(room.id),
              ),
              const SizedBox(height: AppSpacing.cardGap),
            ],
          ],
        );
      },
    );
  }
}

class _DevicesSelectList extends ConsumerWidget {
  const _DevicesSelectList({
    required this.roomId,
    required this.selectedRoute,
    required this.onSelectDevice,
  });

  final String roomId;
  final String selectedRoute;
  final ValueChanged<Device> onSelectDevice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devicesAsync = ref.watch(devicesProvider(roomId));

    return AsyncValueView<List<Device>>(
      value: devicesAsync,
      onRetry: () => ref.invalidate(devicesProvider(roomId)),
      data: (devices) {
        if (devices.isEmpty) {
          return const EmptyState(
            icon: Symbols.devices,
            message: 'Noch keine Geräte vorhanden',
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppSectionLabel('Geräte-Übersicht'),
            for (final device in devices) ...[
              NavTileCard(
                icon: device.type.icon,
                title: device.displayName,
                subtitle: device.type == DeviceType.environmentMonitor
                    ? emsCategoryLabel
                    : device.type.label,
                accent: context.colors.primary,
                onTap: () => onSelectDevice(device),
              ),
              if (selectedRoute == Paths.deviceDetails(device.id))
                Padding(
                  padding: const EdgeInsets.only(
                    top: AppSpacing.xs,
                    bottom: AppSpacing.cardGap,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(
                        Symbols.check_circle,
                        color: context.colors.primary,
                        fill: 1,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Aktuelles Startbild',
                        style: context.text.labelSmall?.copyWith(
                          color: context.colors.primary,
                        ),
                      ),
                    ],
                  ),
                )
              else
                const SizedBox(height: AppSpacing.cardGap),
            ],
          ],
        );
      },
    );
  }
}
