import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/extensions/accent_resolver.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/services/preferences_service.dart';
import '../../../core/supabase/realtime_guard.dart';
import '../../../core/supabase/realtime_service.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../shared/application/direct_device_link.dart';
import '../../../shared/application/location_breadcrumb.dart';
import '../../../shared/models/models.dart';
import '../../../shared/providers/data_providers.dart';
import '../../../shared/providers/connection_mode_provider.dart';
import '../../../shared/providers/repository_providers.dart';
import '../application/room_devices_controller.dart';
import 'widgets/control_panel_device_card.dart';
import 'widgets/device_card_text_styles.dart';
import 'widgets/device_control_card.dart';
import 'widgets/device_online_badge.dart';
import 'widgets/ems_room_card.dart';
import 'widgets/smart_led_device_card.dart';
import 'widgets/room_summary_grid.dart';

/// Room overview ("Raum-Übersicht"): header + device control cards + a summary
/// stats grid. Each device exposes quick power control plus settings & details.
class RoomOverviewPage extends ConsumerStatefulWidget {
  const RoomOverviewPage({super.key, required this.roomId});

  final String roomId;

  @override
  ConsumerState<RoomOverviewPage> createState() => _RoomOverviewPageState();
}

class _RoomOverviewPageState extends ConsumerState<RoomOverviewPage> {
  RealtimeService? _realtime;
  final _livecomSubscribed = <String>{};
  Timer? _poll;

  /// Bumped on each refresh so [SmartLedDeviceCard] drops optimistic edits and
  /// shows the values just read from the device or Supabase.
  int _ledRefreshGeneration = 0;

  /// Counts 1-second ticks so EMS samples refresh about every 5 seconds.
  int _emsPollTicks = 0;

  /// Counts 1-second ticks so cloud online/offline is rechecked about every
  /// 30 seconds in rooms that are not already reloaded for Smart LED.
  int _cloudStatusTicks = 0;

  /// Device ids with a direct-mode presence probe still in flight.
  final _probing = <String>{};

  /// True shows the existing control cards. False shows the compact status cards.
  var _roomCards = true;
  var _grouping = _RoomGrouping.none;
  final _collapsed = <String>{};

  Future<void> _pickGrouping() async {
    final picked = await showOptionPicker<_RoomGrouping>(
      context: context,
      title: 'Sortierung',
      options: _RoomGrouping.values,
      selected: _grouping,
      labelOf: (option) => switch (option) {
        _RoomGrouping.none => 'Ohne Gruppierung',
        _RoomGrouping.type => 'Nach Gerätetyp',
      },
    );
    if (picked == null || !mounted) return;
    setState(() {
      _grouping = picked;
      _collapsed.clear();
    });
    _persistLayout();
  }

  String? get _userId =>
      ref.read(supabaseClientProvider).auth.currentUser?.id;

  void _restoreLayout() {
    final userId = _userId;
    if (userId == null) return;
    final prefs = ref.read(preferencesServiceProvider);
    _roomCards = prefs.roomShowsCards(userId, widget.roomId);
    _grouping = prefs.roomGrouping(userId, widget.roomId) == 'type'
        ? _RoomGrouping.type
        : _RoomGrouping.none;
  }

  void _persistLayout() {
    final userId = _userId;
    if (userId == null) return;
    unawaited(
      ref.read(preferencesServiceProvider).setRoomLayout(
            userId,
            widget.roomId,
            showCards: _roomCards,
            grouping: _grouping.name,
          ),
    );
  }

  @override
  void initState() {
    super.initState();
    _restoreLayout();
    _poll = Timer.periodic(const Duration(seconds: 1), (_) => _pollTick());
  }

  /// Reloads Smart LED data every second and EMS samples about every 5 seconds,
  /// and only after the previous read has finished.
  void _pollTick() {
    if (!mounted) return;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;

    final devicesAsync = ref.read(roomDevicesControllerProvider(widget.roomId));
    if (devicesAsync.isLoading) return;
    final devices = devicesAsync.value;
    if (devices == null) return;

    final lights = [
      for (final device in devices)
        if (device.type == DeviceType.light) device,
    ];
    final monitors = [
      for (final device in devices)
        if (device.type == DeviceType.environmentMonitor) device,
    ];
    if (ref.read(isDirectConnectionProvider)) {
      _probeSilentDevices(devices);
    } else if (lights.isEmpty) {
      _cloudStatusTicks++;
      if (_cloudStatusTicks >= 30) {
        _cloudStatusTicks = 0;
        ref.invalidate(roomDevicesControllerProvider(widget.roomId));
      }
    }
    if (lights.isEmpty && monitors.isEmpty) return;

    if (lights.isNotEmpty && !_lightsBusy(lights)) {
      ref.invalidate(roomDevicesControllerProvider(widget.roomId));
      _refreshLights(lights);
    }

    if (monitors.isEmpty) return;
    _emsPollTicks++;
    if (_emsPollTicks < 5) return;
    if (_monitorsBusy(monitors)) return;
    _emsPollTicks = 0;
    for (final device in monitors) {
      ref.invalidate(emsSensorProvider(device.id));
    }
  }

  void _probeSilentDevices(List<Device> devices) {
    for (final device in devices) {
      if (device.type == DeviceType.light ||
          device.type == DeviceType.environmentMonitor) {
        continue;
      }
      if (_probing.contains(device.id)) continue;
      _probing.add(device.id);
      unawaited(
        probeDirectDeviceLink(
          link: ref.read(directDeviceLinkProvider.notifier),
          resolver: ref.read(deviceEndpointResolverProvider),
          udp: ref.read(udpDeviceServiceProvider),
          deviceId: device.id,
        ).whenComplete(() => _probing.remove(device.id)),
      );
    }
  }

  bool _lightsBusy(List<Device> devices) {
    for (final device in devices) {
      final strips = smartLedStripsProvider(device.id);
      if (ref.exists(strips) && ref.read(strips).isLoading) return true;
    }
    return false;
  }

  bool _monitorsBusy(List<Device> devices) {
    for (final device in devices) {
      final reading = emsSensorProvider(device.id);
      if (ref.exists(reading) && ref.read(reading).isLoading) return true;
    }
    return false;
  }

  void _refreshLights(List<Device> lights) {
    final resolver = ref.read(deviceEndpointResolverProvider);
    for (final device in lights) {
      resolver.invalidate(device.id);
      ref.invalidate(smartLedStripsProvider(device.id));
    }
    setState(() => _ledRefreshGeneration++);
  }

  void _refresh() {
    final id = widget.roomId;
    final devices = ref.read(roomDevicesControllerProvider(id)).value;
    ref.invalidate(roomDevicesControllerProvider(id));
    if (devices != null) {
      final lights = [
        for (final device in devices)
          if (device.type == DeviceType.light) device,
      ];
      if (lights.isNotEmpty) _refreshLights(lights);
      for (final device in devices) {
        if (device.type != DeviceType.environmentMonitor) continue;
        ref.invalidate(emsSensorProvider(device.id));
      }
    }
    _emsPollTicks = 0;
    _cloudStatusTicks = 0;
  }

  @override
  void dispose() {
    _poll?.cancel();
    _realtime?.unsubscribeAll();
    super.dispose();
  }

  void _ensureLivecomSubscriptions(List<Device> devices) {
    if (!useSupabaseRealtime(ref)) return;
    _realtime ??= RealtimeService(ref.read(supabaseClientProvider));
    for (final device in devices) {
      if (_livecomSubscribed.contains(device.id)) continue;
      _livecomSubscribed.add(device.id);
      _realtime!.subscribeToDeviceTable(
        deviceId: device.id,
        table: 'livecom',
        onChange: () =>
            ref.invalidate(roomDevicesControllerProvider(widget.roomId)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(roomProvider(widget.roomId));
    final devicesAsync = ref.watch(roomDevicesControllerProvider(widget.roomId));
    final room = roomAsync.value;
    final hasDevices = devicesAsync.value?.isNotEmpty ?? false;
    final accent = room == null ? null : context.accent(room.accentKey);
    final place = locationBreadcrumb(
      ref,
      roomId: widget.roomId,
      includeFloor: true,
      includeRoom: true,
    );

    return AppScaffold(
      header: AppHeader(
        onRefresh: _refresh,
      ),
      body: AppScrollView(
        children: [
          SectionHeaderCard(
            title: room?.name ?? 'Raum',
            subtitle: locationBreadcrumb(
              ref,
              roomId: widget.roomId,
              includeFloor: true,
            ),
            icon: room?.icon ?? Symbols.meeting_room,
            accent: accent,
            filled: true,
            trailing: hasDevices
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      NeumorphicIconButton(
                        icon: Symbols.filter_list,
                        size: 40,
                        iconSize: 20,
                        tooltip: 'Sortierung',
                        onPressed: _pickGrouping,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      NeumorphicIconButton(
                        icon: _roomCards
                            ? Symbols.unfold_less
                            : Symbols.unfold_more,
                        size: 40,
                        iconSize: 20,
                        tooltip: _roomCards
                            ? 'Zur Statusansicht wechseln'
                            : 'Zu den Karten wechseln',
                        onPressed: () {
                          setState(() => _roomCards = !_roomCards);
                          _persistLayout();
                        },
                      ),
                    ],
                  )
                : null,
          ),
          devicesAsync.when(
            skipLoadingOnReload: true,
            skipError: true,
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.sectionMargin),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.all(AppSpacing.sectionMargin),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Symbols.error, color: context.colors.error, size: 40),
                  const SizedBox(height: AppSpacing.gutter),
                  Text(
                    'Etwas ist schiefgelaufen',
                    style: context.text.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.gutter),
                  TextButton(
                    onPressed: _refresh,
                    child: const Text('Erneut versuchen'),
                  ),
                ],
              ),
            ),
            data: (devices) {
              _ensureLivecomSubscriptions(devices);
              if (devices.isEmpty) {
                return const EmptyState(
                  icon: Symbols.devices,
                  message: 'Noch keine Geräte in diesem Raum',
                );
              }
              final controller =
                  ref.read(roomDevicesControllerProvider(widget.roomId).notifier);
              final ordered = _sortedRoomDevices(devices);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_grouping == _RoomGrouping.none)
                    for (final device in ordered) ...[
                      _deviceCard(
                        context,
                        device,
                        place: place ?? '',
                        onTogglePower: (value) =>
                            controller.togglePower(device.id, value),
                      ),
                      const SizedBox(height: AppSpacing.cardGap),
                    ]
                  else
                    for (final group in _typeGroups(ordered)) ...[
                      _GroupCard(
                        title: group.title,
                        count: group.devices.length,
                        expanded: !_collapsed.contains(group.title),
                        onToggle: () => setState(() {
                          if (!_collapsed.add(group.title)) {
                            _collapsed.remove(group.title);
                          }
                        }),
                        children: [
                          for (final device in group.devices)
                            _deviceCard(
                              context,
                              device,
                              place: place ?? '',
                              onTogglePower: (value) =>
                                  controller.togglePower(device.id, value),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.cardGap),
                    ],
                  RoomSummaryGrid(devices: ordered),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _deviceCard(
    BuildContext context,
    Device device, {
    required String place,
    required ValueChanged<bool> onTogglePower,
  }) {
    if (!_roomCards) {
      return _RoomStatusCard(device: device, locationPath: place);
    }

    void openDetails() => context.push(Paths.deviceDetails(device.id));
    void openSettings() => context.push(Paths.deviceSettings(device.id));

    if (device.type == DeviceType.controlPanel) {
      return ControlPanelDeviceCard(
        device: device,
        onOpenDetails: openDetails,
        onOpenSettings: openSettings,
      );
    }
    if (device.type == DeviceType.environmentMonitor) {
      return EmsRoomCard(
        key: ValueKey(device.id),
        device: device,
        onOpenDetails: openDetails,
        onOpenSettings: openSettings,
      );
    }
    if (device.type == DeviceType.light) {
      return SmartLedDeviceCard(
        key: ValueKey(device.id),
        device: device,
        showEffectPicker: false,
        refreshGeneration: _ledRefreshGeneration,
        onOpenDetails: openDetails,
        onOpenSettings: openSettings,
      );
    }
    return DeviceControlCard(
      device: device,
      onOpenDetails: openDetails,
      onOpenSettings: openSettings,
      onTogglePower: onTogglePower,
    );
  }
}

enum _RoomGrouping { none, type }

class _RoomTypeGroup {
  _RoomTypeGroup({required this.title, required this.rank});

  final String title;
  final int rank;
  final devices = <Device>[];
}

List<_RoomTypeGroup> _typeGroups(List<Device> devices) {
  final buckets = <String, _RoomTypeGroup>{};
  for (final device in devices) {
    final info = _roomTypeGroup(device);
    buckets
        .putIfAbsent(
          info.label,
          () => _RoomTypeGroup(title: info.label, rank: info.rank),
        )
        .devices
        .add(device);
  }
  final groups = buckets.values.toList();
  groups.sort((a, b) {
    final byRank = a.rank.compareTo(b.rank);
    if (byRank != 0) return byRank;
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  });
  return groups;
}

/// Room cards: Raumklima, Smart LED, Smart Switch, Smart Blinds, Control Panel.
/// Devices of the same kind keep their previous order.
List<Device> _sortedRoomDevices(List<Device> devices) {
  final indexed = devices.indexed.toList();
  indexed.sort((a, b) {
    final rank = _roomDeviceRank(a.$2).compareTo(_roomDeviceRank(b.$2));
    if (rank != 0) return rank;
    return a.$1.compareTo(b.$1);
  });
  return [for (final entry in indexed) entry.$2];
}

int _roomDeviceRank(Device device) => _roomTypeGroup(device).rank;

({int rank, String label}) _roomTypeGroup(Device device) {
  if (device.type == DeviceType.environmentMonitor) {
    return (rank: 0, label: emsCategoryLabel);
  }
  if (device.type == DeviceType.light) {
    return (rank: 1, label: 'Smart LED');
  }

  final firmware = CpDeviceType.fromDeviceTypeName(device.model);
  return switch (firmware) {
    CpDeviceType.smartSwitch => (rank: 2, label: 'Smart Switch'),
    CpDeviceType.louver => (rank: 3, label: 'Smart Blinds'),
    CpDeviceType.controlPanel => (rank: 4, label: 'Control Panel'),
    _ => device.type == DeviceType.controlPanel
        ? (rank: 4, label: 'Control Panel')
        : (rank: 5, label: device.type.label),
  };
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.title,
    required this.count,
    required this.expanded,
    required this.onToggle,
    required this.children,
  });

  final String title;
  final int count;
  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: AppRadius.mdAll,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: context.text.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text('$count', style: context.text.bodySmall),
                Icon(
                  expanded ? Symbols.expand_less : Symbols.expand_more,
                  color: context.colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
          if (expanded) ...[
            const SizedBox(height: AppSpacing.md),
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.cardGap),
              children[i],
            ],
          ],
        ],
      ),
    );
  }
}

class _RoomStatusCard extends ConsumerWidget {
  const _RoomStatusCard({required this.device, required this.locationPath});

  final Device device;
  final String locationPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = deviceIsOnline(ref, device);
    final status = online ? 'Online' : 'Offline';
    final statusColor =
        online ? context.palette.statusOnline : context.colors.error;
    final typeLabel = _roomTypeGroup(device).label;

    return AppCard(
      onTap: () => context.push(Paths.deviceDetails(device.id)),
      child: Row(
        children: [
          IconBox(
            icon: device.type.icon,
            color: context.colors.primary,
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
                  device.displayName,
                  style: DeviceCardTextStyles.title(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  typeLabel,
                  style: DeviceCardTextStyles.subtitle(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (locationPath.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    locationPath,
                    style: DeviceCardTextStyles.caption(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  status,
                  style: DeviceCardTextStyles.caption(context, emphasis: true)
                      .copyWith(color: statusColor),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          DeviceOnlineBadge(device: device),
        ],
      ),
    );
  }
}
