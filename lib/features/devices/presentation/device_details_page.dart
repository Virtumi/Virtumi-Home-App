import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../shared/application/direct_device_link.dart';
import '../../../shared/application/location_breadcrumb.dart';
import '../../../shared/models/models.dart';
import '../../../shared/providers/connection_mode_provider.dart';
import '../../../shared/providers/data_providers.dart';
import '../../../shared/providers/repository_providers.dart';
import '../../rooms/presentation/widgets/control_panel_device_card.dart';
import '../../rooms/presentation/widgets/device_control_card.dart';
import '../../rooms/presentation/widgets/smart_led_device_card.dart';
import 'widgets/ems_device_overview.dart';

/// Device details ("Gerätedetails"): same interactive card as room overview.
class DeviceDetailsPage extends ConsumerStatefulWidget {
  const DeviceDetailsPage({super.key, required this.deviceId});

  final String deviceId;

  @override
  ConsumerState<DeviceDetailsPage> createState() => _DeviceDetailsPageState();
}

class _DeviceDetailsPageState extends ConsumerState<DeviceDetailsPage> {
  Timer? _poll;

  /// Bumped on each refresh so [SmartLedDeviceCard] drops its optimistic
  /// state and shows the values just read from the device or Supabase.
  int _ledRefreshGeneration = 0;
  int _emsPollTicks = 0;
  int _emsHistoryTicks = 0;
  int _cloudStatusTicks = 0;
  bool _probing = false;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 1), (_) => _pollTick());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  /// Reloads this Smart LED every second and an EMS about every 5 seconds
  /// while the details route is in front and the last read has finished.
  void _pollTick() {
    if (!mounted) return;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;

    final id = widget.deviceId;
    final deviceAsync = ref.read(deviceProvider(id));
    if (deviceAsync.isLoading) return;
    final type = deviceAsync.value?.type;
    final direct = ref.read(isDirectConnectionProvider);
    if (direct &&
        type != null &&
        type != DeviceType.light &&
        type != DeviceType.environmentMonitor &&
        !_probing) {
      _probing = true;
      unawaited(
        probeDirectDeviceLink(
          link: ref.read(directDeviceLinkProvider.notifier),
          resolver: ref.read(deviceEndpointResolverProvider),
          udp: ref.read(udpDeviceServiceProvider),
          deviceId: id,
        ).whenComplete(() => _probing = false),
      );
    } else if (!direct) {
      _cloudStatusTicks++;
      if (_cloudStatusTicks >= 30) {
        _cloudStatusTicks = 0;
        ref.invalidate(deviceProvider(id));
      }
    }
    if (type == DeviceType.light) {
      final strips = smartLedStripsProvider(id);
      if (ref.exists(strips) && ref.read(strips).isLoading) return;
      _refresh();
      return;
    }
    if (type != DeviceType.environmentMonitor) return;
    _emsPollTicks++;
    _emsHistoryTicks++;
    if (_emsHistoryTicks >= 60) {
      final history = emsSensorHistoryProvider(id);
      final historyBusy = ref.exists(history) && ref.read(history).isLoading;
      if (!historyBusy) {
        _emsHistoryTicks = 0;
        ref.invalidate(emsSensorHistoryProvider(id));
      }
    }
    if (_emsPollTicks < 5) return;
    final reading = emsSensorProvider(id);
    if (ref.exists(reading) && ref.read(reading).isLoading) return;
    _emsPollTicks = 0;
    ref.invalidate(emsSensorProvider(id));
  }

  void _refresh() {
    final id = widget.deviceId;
    final type = ref.read(deviceProvider(id)).asData?.value?.type;
    // Drop the cached UDP endpoint so direct mode re-reads IP and device code.
    ref.read(deviceEndpointResolverProvider).invalidate(id);
    ref.invalidate(deviceProvider(id));
    if (type == DeviceType.light) {
      // Cloud: smart_led_settings. Direct: UDP protocol 0 / reply 17.
      ref.invalidate(smartLedStripsProvider(id));
      setState(() => _ledRefreshGeneration++);
    } else if (type == DeviceType.environmentMonitor) {
      ref.invalidate(emsSensorProvider(id));
      ref.invalidate(emsSensorHistoryProvider(id));
      _emsPollTicks = 0;
      _emsHistoryTicks = 0;
    }
    _cloudStatusTicks = 0;
  }

  @override
  Widget build(BuildContext context) {
    final deviceAsync = ref.watch(deviceProvider(widget.deviceId));
    final device = deviceAsync.value;
    final showEdit =
        device != null &&
        device.type != DeviceType.controlPanel &&
        device.type != DeviceType.environmentMonitor &&
        device.type != DeviceType.light;

    return AppScaffold(
      header: AppHeader(
        onEdit: showEdit
            ? () => context.push(Paths.deviceSettings(widget.deviceId))
            : null,
        onRefresh: _refresh,
      ),
      body: deviceAsync.when(
        // Reload keeps the last device so the header and controls stay put.
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
        data: (device) {
          if (device == null) {
            return const EmptyState(
              icon: Symbols.error,
              message: 'Gerät nicht gefunden',
            );
          }
          return AppScrollView(
            children: [
              if (device.type == DeviceType.environmentMonitor)
                EmsDeviceOverview(device: device)
              else ...[
                SectionHeaderCard(
                  title: device.displayName,
                  subtitle: locationBreadcrumb(
                    ref,
                    roomId: device.roomId,
                    includeFloor: true,
                    includeRoom: true,
                  ),
                  icon: device.type.icon,
                  filled: true,
                  trailing: device.type == DeviceType.controlPanel ||
                          device.type == DeviceType.light
                      ? NeumorphicIconButton(
                          icon: Symbols.settings,
                          iconColor: context.colors.onSurface,
                          size: 40,
                          iconSize: 20,
                          tooltip: 'Geräteeinstellungen',
                          onPressed: () => context.push(
                            Paths.deviceSettings(device.id),
                          ),
                        )
                      : null,
                ),
                _DeviceControlCard(
                  device: device,
                  ledRefreshGeneration: _ledRefreshGeneration,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _DeviceControlCard extends ConsumerWidget {
  const _DeviceControlCard({
    required this.device,
    required this.ledRefreshGeneration,
  });

  final Device device;
  final int ledRefreshGeneration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (device.type == DeviceType.controlPanel) {
      return ControlPanelDeviceCard(
        device: device,
        showDetailsButton: false,
        showSettingsButton: false,
        onOpenDetails: () {},
        onOpenSettings: () {},
      );
    }

    if (device.type == DeviceType.light) {
      return SmartLedDeviceCard(
        device: device,
        showDetailsButton: false,
        showSettingsButton: false,
        showExtendedEffectControls: true,
        refreshGeneration: ledRefreshGeneration,
        onOpenDetails: () {},
        onOpenSettings: () {},
      );
    }

    return DeviceControlCard(
      device: device,
      onOpenDetails: () {},
      onOpenSettings: () => context.push(Paths.deviceSettings(device.id)),
      onTogglePower: (value) async {
        await ref
            .read(smartHomeRepositoryProvider)
            .setDevicePower(device.id, value);
        ref.invalidate(deviceProvider(device.id));
      },
    );
  }
}
