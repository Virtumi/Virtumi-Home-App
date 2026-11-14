import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/refresh_on_show.dart';
import '../../../core/widgets/widgets.dart';
import '../../../shared/application/favorite_devices.dart';
import '../../../shared/application/recent_house_activity.dart';
import '../../../shared/models/models.dart';
import '../../../shared/providers/data_providers.dart';
import 'widgets/home_top_bar.dart';
import 'widgets/house_grid_card.dart';

/// Home tab: account header, quick add, "Meine Häuser" grid and recent activity.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> with RefreshOnShow {
  static const User _placeholderUser =
      User(id: '', name: '', email: '', badges: []);

  // Providers are created fresh when the Home tab is first built.
  @override
  bool get refreshOnInit => false;

  @override
  void refreshOnShow() => refreshHomeScreenData(ref);

  @override
  Widget build(BuildContext context) {
    trackVisibility();

    final userAsync = ref.watch(currentUserProvider);
    final settingsAsync = ref.watch(appSettingsProvider);
    final user = userAsync.value ?? _placeholderUser;
    final connection = settingsAsync.maybeWhen(
      data: (settings) => settings?.connectionModeLabel ?? 'Cloud',
      orElse: () => 'Cloud',
    );
    final showRecentActivity = settingsAsync.maybeWhen(
      data: (settings) => settings?.showRecentActivity ?? true,
      orElse: () => true,
    );
    final showFavorites = settingsAsync.maybeWhen(
      data: (settings) => settings?.showFavorites ?? true,
      orElse: () => true,
    );

    final hasNoHouses = ref.watch(housesProvider).maybeWhen(
          data: (houses) => houses.isEmpty,
          orElse: () => false,
        );

    // Selected directly (no derived provider) so bursts of realtime events
    // cannot rebuild a derived provider twice in one frame.
    final unreadNotifications = ref.watch(
      notificationsProvider.select(unreadNotificationCount),
    );

    return AppScaffold(
      header: HomeTopBar(
        user: user,
        connection: connection,
        unreadCount: unreadNotifications,
        onNotifications: () => context.push(Paths.notifications),
      ),
      body: hasNoHouses
          ? _NoDevicesState(
              onAddDevice: () => context.push(Paths.newDeviceWizard),
            )
          : AppScrollView(
              children: [
                ActionBannerCard(
                  icon: Symbols.add_circle,
                  title: 'Neues Gerät hinzufügen',
                  subtitle: 'Assistent: Passwort, Netzwerk oder Bluetooth',
                  accent: context.colors.primary,
                  trailingIcon: Symbols.add,
                  trailingFilledButton: true,
                  onTap: () => context.push(Paths.newDeviceWizard),
                ),
                const _HousesSection(),
                if (showFavorites) const _FavoritesSection(),
                if (showRecentActivity) const _RecentActivitySection(),
              ],
            ),
    );
  }
}

/// Shown instead of the Home lists while the account has no devices (and
/// therefore no houses): one large, centered call-to-action.
class _NoDevicesState extends StatelessWidget {
  const _NoDevicesState({required this.onAddDevice});

  final VoidCallback onAddDevice;

  @override
  Widget build(BuildContext context) {
    final bottomClearance = AppSpacing.scrollBottomClearance(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            AppSpacing.containerPadding,
            AppSpacing.gutter,
            AppSpacing.containerPadding,
            bottomClearance,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight -
                  AppSpacing.gutter -
                  bottomClearance,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      color: context.colors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Symbols.add_home,
                      size: 56,
                      color: context.colors.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Noch keine Geräte',
                    style: context.text.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Füge dein erstes Gerät hinzu, um loszulegen.',
                    style: context.text.bodyMedium?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    height: 64,
                    child: FilledButton.icon(
                      onPressed: onAddDevice,
                      icon: const Icon(Symbols.add, size: 28),
                      label: const Text('Gerät hinzufügen'),
                      style: FilledButton.styleFrom(
                        textStyle: context.text.titleMedium,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HousesSection extends ConsumerWidget {
  const _HousesSection();

  Future<void> _openHouse(
    BuildContext context,
    WidgetRef ref,
    House house,
  ) async {
    await ref.read(recentHouseActivityProvider.notifier).record(house.id);
    if (!context.mounted) return;
    context.push(Paths.floors(house.id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentHomesAsync = ref.watch(recentHomesProvider);
    final allHousesAsync = ref.watch(housesProvider);
    final showSeeAll = allHousesAsync.maybeWhen(
      data: (houses) => houses.isNotEmpty,
      orElse: () => false,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionLabel(
          'Meine Häuser',
          trailing: showSeeAll
              ? _SeeAllButton(onTap: () => context.push(Paths.allHouses))
              : null,
        ),
        AsyncValueView<List<House>>(
          value: recentHomesAsync,
          onRetry: () => refreshHomeScreenData(ref),
          data: (houses) => _HousesGrid(
            houses: houses,
            onHouseTap: (house) => _openHouse(context, ref, house),
          ),
        ),
      ],
    );
  }
}

class _HousesGrid extends StatelessWidget {
  const _HousesGrid({
    required this.houses,
    required this.onHouseTap,
  });

  final List<House> houses;
  final void Function(House house) onHouseTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 520 ? 3 : 2;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: columns,
          mainAxisSpacing: AppSpacing.cardGap,
          crossAxisSpacing: AppSpacing.cardGap,
          childAspectRatio: 1.05,
          children: [
            for (final house in houses)
              HouseGridCard(
                house: house,
                onTap: () => onHouseTap(house),
              ),
          ],
        );
      },
    );
  }
}

class _FavoritesSection extends ConsumerWidget {
  const _FavoritesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = ref.watch(favoriteDevicesProvider);
    if (ids.isEmpty) return const SizedBox.shrink();

    final devicesAsync = ref.watch(favoriteDevicesEntriesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppSectionLabel('Favoriten'),
        AsyncValueView<List<RecentActivityEntry>>(
          value: devicesAsync,
          onRetry: () => ref.invalidate(favoriteDevicesEntriesProvider),
          data: (entries) {
            if (entries.isEmpty) return const SizedBox.shrink();
            return _DeviceEntryList(entries: entries);
          },
        ),
      ],
    );
  }
}

class _RecentActivitySection extends ConsumerWidget {
  const _RecentActivitySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devicesAsync = ref.watch(recentActivityDevicesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppSectionLabel('Letzte Aktivitäten'),
        AsyncValueView<List<RecentActivityEntry>>(
          value: devicesAsync,
          onRetry: () => ref.invalidate(recentActivityDevicesProvider),
          data: (entries) {
            if (entries.isEmpty) {
              return const EmptyState(
                icon: Symbols.history,
                message: 'Noch keine Aktivitäten',
                padding: EdgeInsets.all(AppSpacing.lg),
              );
            }
            return _DeviceEntryList(entries: entries);
          },
        ),
      ],
    );
  }
}

class _DeviceEntryList extends StatelessWidget {
  const _DeviceEntryList({required this.entries});

  final List<RecentActivityEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in entries) ...[
          NavTileCard(
            icon: entry.device.type.icon,
            title: entry.device.displayName,
            detail: entry.locationPath,
            subtitle: entry.device.type == DeviceType.environmentMonitor
                ? '$emsCategoryLabel · ${entry.device.connectivity.label}'
                : '${entry.device.type.label} · ${entry.device.statusLabel}',
            accent: context.colors.primary,
            onTap: () => context.push(Paths.deviceDetails(entry.device.id)),
          ),
          const SizedBox(height: AppSpacing.cardGap),
        ],
      ],
    );
  }
}

class _SeeAllButton extends StatelessWidget {
  const _SeeAllButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      semanticLabel: 'Alle anzeigen',
      scalePressed: 0.95,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Alle',
              style: context.text.bodyMedium
                  ?.copyWith(color: context.colors.onSurfaceVariant)),
          Icon(Symbols.chevron_right,
              size: 18, color: context.colors.onSurfaceVariant),
        ],
      ),
    );
  }
}
