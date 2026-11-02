import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/services/preferences_service.dart';
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

class _HomePageState extends ConsumerState<HomePage> {
  static const User _placeholderUser =
      User(id: '', name: '', email: '', badges: []);

  bool _wasHidden = false;

  @override
  Widget build(BuildContext context) {
    final isVisible = ModalRoute.of(context)?.isCurrent ?? true;
    if (isVisible && _wasHidden) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) refreshHomeScreenData(ref);
      });
    }
    _wasHidden = !isVisible;

    final userAsync = ref.watch(currentUserProvider);
    final settingsAsync = ref.watch(appSettingsProvider);
    final user = userAsync.value ?? _placeholderUser;
    final connection = settingsAsync.maybeWhen(
      data: (settings) => settings?.connectionModeLabel ?? 'Cloud',
      orElse: () => 'Cloud',
    );

    return AppScaffold(
      header: HomeTopBar(
        user: user,
        connection: connection,
        onNotifications: () {},
      ),
      body: AppScrollView(
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
          const _RecentActivitySection(),
        ],
      ),
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
      data: (houses) => houses.length > PreferencesService.maxRecentHouses,
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
                    onTap: () =>
                        context.push(Paths.deviceDetails(entry.device.id)),
                  ),
                  const SizedBox(height: AppSpacing.cardGap),
                ],
              ],
            );
          },
        ),
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
