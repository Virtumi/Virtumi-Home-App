import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/services/preferences_service.dart';
import '../../../core/supabase/supabase_client.dart';
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

enum _FavoriteGrouping { none, room, type }

class _FavoriteGroup {
  _FavoriteGroup({required this.title, required this.rank});

  final String title;
  final int rank;
  final entries = <RecentActivityEntry>[];
}

/// Favorites tab: saved devices as status cards or room-overview cards.
class FavoritesPage extends ConsumerStatefulWidget {
  const FavoritesPage({super.key});

  @override
  ConsumerState<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends ConsumerState<FavoritesPage> {
  /// False shows the compact online/offline cards.
  var _roomCards = false;
  var _grouping = _FavoriteGrouping.none;
  final _collapsed = <String>{};

  final _power = <String, bool>{};

  @override
  void initState() {
    super.initState();
    final userId = _userId;
    if (userId == null) return;
    final prefs = ref.read(preferencesServiceProvider);
    _roomCards = prefs.favoritesShowsCards(userId);
    _grouping = switch (prefs.favoritesGrouping(userId)) {
      'room' => _FavoriteGrouping.room,
      'type' => _FavoriteGrouping.type,
      _ => _FavoriteGrouping.none,
    };
  }

  String? get _userId =>
      ref.read(supabaseClientProvider).auth.currentUser?.id;

  void _persistLayout() {
    final userId = _userId;
    if (userId == null) return;
    unawaited(
      ref.read(preferencesServiceProvider).setFavoritesLayout(
            userId,
            showCards: _roomCards,
            grouping: _grouping.name,
          ),
    );
  }

  Future<void> _pickGrouping() async {
    final picked = await showOptionPicker<_FavoriteGrouping>(
      context: context,
      title: 'Sortierung',
      options: _FavoriteGrouping.values,
      selected: _grouping,
      labelOf: (option) => switch (option) {
        _FavoriteGrouping.none => 'Ohne Gruppierung',
        _FavoriteGrouping.room => 'Nach Raum',
        _FavoriteGrouping.type => 'Nach Gerätetyp',
      },
    );
    if (picked == null || !mounted) return;
    setState(() {
      _grouping = picked;
      _collapsed.clear();
    });
    _persistLayout();
  }

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
            _header(accent, showActions: false),
            const EmptyState(
              icon: Symbols.error,
              message: 'Etwas ist schiefgelaufen',
            ),
          ],
        ),
        data: (entries) {
          return AppScrollView(
            children: [
              _header(accent, showActions: entries.isNotEmpty),
              if (entries.isEmpty)
                const EmptyState(
                  icon: Symbols.favorite,
                  message: 'Noch keine Favoriten gesetzt',
                )
              else if (_grouping == _FavoriteGrouping.none)
                for (final entry in entries) _cardFor(context, entry)
              else
                for (final group in _groups(entries))
                  _GroupCard(
                    title: group.title,
                    count: group.entries.length,
                    expanded: !_collapsed.contains(group.title),
                    onToggle: () => setState(() {
                      if (!_collapsed.add(group.title)) {
                        _collapsed.remove(group.title);
                      }
                    }),
                    children: [
                      for (final entry in group.entries)
                        _cardFor(context, entry),
                    ],
                  ),
            ],
          );
        },
      ),
    );
  }

  Widget _header(Color accent, {required bool showActions}) {
    return SectionHeaderCard(
      title: 'Favoriten',
      icon: Symbols.favorite,
      subtitle: 'Gespeicherte Geräte',
      accent: accent,
      filled: true,
      trailing: showActions
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
                  icon: _roomCards ? Symbols.unfold_less : Symbols.unfold_more,
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
    );
  }

  List<_FavoriteGroup> _groups(List<RecentActivityEntry> entries) {
    final buckets = <String, _FavoriteGroup>{};
    for (final entry in entries) {
      final info = _grouping == _FavoriteGrouping.room
          ? (
              rank: 0,
              label: entry.locationPath.trim().isEmpty
                  ? 'Ohne Ort'
                  : entry.locationPath.trim(),
            )
          : _typeGroup(entry.device);
      buckets
          .putIfAbsent(
            info.label,
            () => _FavoriteGroup(title: info.label, rank: info.rank),
          )
          .entries
          .add(entry);
    }
    final groups = buckets.values.toList();
    groups.sort((a, b) {
      final byRank = a.rank.compareTo(b.rank);
      if (byRank != 0) return byRank;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return groups;
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

({int rank, String label}) _typeGroup(Device device) {
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
                Text(
                  '$count',
                  style: context.text.bodySmall,
                ),
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
