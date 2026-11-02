import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/extensions/accent_resolver.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/supabase/realtime_guard.dart';
import '../../../core/supabase/realtime_service.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../shared/models/models.dart';
import '../../../shared/providers/data_providers.dart';
import '../../../shared/providers/repository_providers.dart';
import '../application/room_devices_controller.dart';
import 'widgets/control_panel_device_card.dart';
import 'widgets/device_control_card.dart';
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

  @override
  void initState() {
    super.initState();
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

    return AppScaffold(
      header: AppHeader(
        onRefresh: _refresh,
      ),
      body: AppScrollView(
        children: [
          SectionHeaderCard(
            title: room?.name ?? 'Raum',
            icon: room?.icon ?? Symbols.meeting_room,
            accent: room == null ? null : context.accent(room.accentKey),
            filled: true,
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
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final device in devices) ...[
                    if (device.type == DeviceType.controlPanel)
                      ControlPanelDeviceCard(
                        device: device,
                        onOpenDetails: () =>
                            context.push(Paths.deviceDetails(device.id)),
                        onOpenSettings: () =>
                            context.push(Paths.deviceSettings(device.id)),
                      )
                    else if (device.type == DeviceType.environmentMonitor)
                      EmsRoomCard(
                        key: ValueKey(device.id),
                        device: device,
                        onOpenDetails: () =>
                            context.push(Paths.deviceDetails(device.id)),
                        onOpenSettings: () =>
                            context.push(Paths.deviceSettings(device.id)),
                      )
                    else if (device.type == DeviceType.light)
                      SmartLedDeviceCard(
                        key: ValueKey(device.id),
                        device: device,
                        showEffectPicker: false,
                        showOfflineStatus: false,
                        refreshGeneration: _ledRefreshGeneration,
                        onOpenDetails: () =>
                            context.push(Paths.deviceDetails(device.id)),
                        onOpenSettings: () =>
                            context.push(Paths.deviceSettings(device.id)),
                      )
                    else
                      DeviceControlCard(
                        device: device,
                        onOpenDetails: () =>
                            context.push(Paths.deviceDetails(device.id)),
                        onOpenSettings: () =>
                            context.push(Paths.deviceSettings(device.id)),
                        onTogglePower: (value) =>
                            controller.togglePower(device.id, value),
                      ),
                    const SizedBox(height: AppSpacing.cardGap),
                  ],
                  RoomSummaryGrid(devices: devices),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
