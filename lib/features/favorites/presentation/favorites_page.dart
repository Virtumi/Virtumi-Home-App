import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../shared/application/direct_device_link.dart';
import '../../../shared/models/models.dart';
import '../../../shared/providers/data_providers.dart';
import '../../../shared/providers/repository_providers.dart';
import '../../rooms/presentation/widgets/control_panel_device_card.dart';
import '../../rooms/presentation/widgets/device_card_text_styles.dart';
import '../../rooms/presentation/widgets/device_control_card.dart';
import '../../rooms/presentation/widgets/device_online_badge.dart';
import '../../rooms/presentation/widgets/ems_room_card.dart';
import '../../rooms/presentation/widgets/smart_led_device_card.dart';

/// Saturated red matching the Favoriten tab in dark mode.
const _favoriteRedDark = Color(0xFFFF4D5A);

/// Favorites tab: saved devices as status cards or room-overview cards.
class FavoritesPage extends ConsumerStatefulWidget {
  const FavoritesPage({super.key});

  @override
  ConsumerState<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends ConsumerState<FavoritesPage> {
  /// False shows the compact online/offline cards.
  var _roomCards = false;

  final _power = <String, bool>{};

  Future<void> _togglePower(Device device, bool isOn) async {
    setState(() => _power[device.id] = isOn);
    try {
      await ref
          .read(smartHomeRepositoryProvider)
          .setDevicePower(device.id, isOn);
      ref.invalidate(favoriteDevicesEntriesProvider);
    } catch (_) {
      if (!mounted) return;
      setState(() => _power.remove(device.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(favoriteDevicesEntriesProvider);
    final accent = Theme.of(context).brightness == Brightness.dark
        ? _favoriteRedDark
        : context.palette.accentRed;

    return AppScaffold(
      header: const AppHeader(showBack: false),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AppScrollView(
          children: [
            _header(accent, showSwitch: false),
            const EmptyState(
              icon: Symbols.error,
              message: 'Etwas ist schiefgelaufen',
            ),
          ],
        ),
        data: (entries) {
          return AppScrollView(
            children: [
              _header(accent, showSwitch: entries.isNotEmpty),
              if (entries.isEmpty)
                const EmptyState(
                  icon: Symbols.favorite,
                  message: 'Noch keine Favoriten gesetzt',
                )
              else
                for (final entry in entries)
                  _cardFor(context, entry),
            ],
          );
        },
      ),
    );
  }

  Widget _header(Color accent, {required bool showSwitch}) {
    return SectionHeaderCard(
      title: 'Favoriten',
      icon: Symbols.favorite,
      subtitle: 'Gespeicherte Geräte',
      accent: accent,
      filled: true,
      trailing: showSwitch
          ? _ViewSwitch(
              roomCards: _roomCards,
              accent: accent,
              onPressed: () => setState(() => _roomCards = !_roomCards),
            )
          : null,
    );
  }

  Widget _cardFor(BuildContext context, RecentActivityEntry entry) {
    final stored = entry.device;
    final device = stored.copyWith(isOn: _power[stored.id] ?? stored.isOn);
    if (!_roomCards) {
      return _FavoriteStatusCard(device: device, locationPath: entry.locationPath);
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
        onOpenDetails: openDetails,
        onOpenSettings: openSettings,
      );
    }
    return DeviceControlCard(
      device: device,
      onOpenDetails: openDetails,
      onOpenSettings: openSettings,
      onTogglePower: (value) => unawaited(_togglePower(device, value)),
    );
  }
}

class _ViewSwitch extends StatelessWidget {
  const _ViewSwitch({
    required this.roomCards,
    required this.accent,
    required this.onPressed,
  });

  final bool roomCards;
  final Color accent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = roomCards ? 'Status' : 'Karten';
    final tooltip = roomCards
        ? 'Zur Statusansicht mit Online und Offline wechseln'
        : 'Zu den Karten der Raumübersicht wechseln';

    return Tooltip(
      message: tooltip,
      child: Material(
        color: accent.withValues(alpha: 0.12),
        borderRadius: AppRadius.full,
        child: InkWell(
          onTap: onPressed,
          borderRadius: AppRadius.full,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              label,
              style: context.text.labelMedium?.copyWith(
                color: accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FavoriteStatusCard extends ConsumerWidget {
  const _FavoriteStatusCard({
    required this.device,
    required this.locationPath,
  });

  final Device device;
  final String locationPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = deviceIsOnline(ref, device);
    final status = online ? 'Online' : 'Offline';
    final statusColor =
        online ? context.palette.statusOnline : context.colors.error;
    final typeLabel = device.type == DeviceType.environmentMonitor
        ? emsCategoryLabel
        : device.type.label;

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
