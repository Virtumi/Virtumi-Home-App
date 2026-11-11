import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/providers/data_providers.dart';
import '../theme/theme.dart';
import '../widgets/app_bottom_navigation.dart';

/// Branch index to restore when leaving Einstellungen via the header back
/// button (defaults to Home).
class SettingsReturnBranch extends Notifier<int> {
  @override
  int build() => 0;

  void remember(int branchIndex) {
    if (branchIndex == _settingsBranchIndex) return;
    state = branchIndex;
  }
}

const _settingsBranchIndex = 3;

final settingsReturnBranchProvider =
    NotifierProvider<SettingsReturnBranch, int>(SettingsReturnBranch.new);

/// Hosts the four primary tab branches and overlays the floating bottom
/// navigation so it stays visible (and consistent) across nested drill-downs.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      body: Stack(
        children: [
          Positioned.fill(child: navigationShell),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Padding(
              padding: EdgeInsets.only(
                bottom:
                    MediaQuery.paddingOf(context).bottom + AppSpacing.bottomNavInset,
              ),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: AppBottomNavigation(
                  currentIndex: navigationShell.currentIndex,
                  onTap: (index) => _onTap(index, ref),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onTap(int index, WidgetRef ref) {
    final current = navigationShell.currentIndex;
    if (index == _settingsBranchIndex && current != _settingsBranchIndex) {
      ref.read(settingsReturnBranchProvider.notifier).remember(current);
    }

    if (index == 0) {
      refreshHomeScreenData(ref);
    }

    navigationShell.goBranch(
      index,
      initialLocation: index == 0 || index == current,
    );
  }
}
