import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/app_settings.dart';
import '../../shared/providers/connection_mode_provider.dart';
import '../../shared/providers/data_providers.dart';
import '../../shared/providers/repository_providers.dart';
import '../auth/auth_providers.dart';
import '../navigation/start_route_providers.dart';
import '../navigation/start_route_support.dart';
import 'preferences_service.dart';
import 'theme_controller.dart';

/// Loads [appSettingsProvider] after login and applies the local start route.
class AppSettingsBootstrap extends ConsumerStatefulWidget {
  const AppSettingsBootstrap({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppSettingsBootstrap> createState() =>
      _AppSettingsBootstrapState();
}

class _AppSettingsBootstrapState extends ConsumerState<AppSettingsBootstrap> {
  Future<void> _apply(AppSettings? settings) async {
    if (!mounted) return;
    if (settings == null) {
      ref.read(appSettingsReadyProvider.notifier).setReady(false);
      return;
    }

    // Dark mode is remembered per user: apply the signed-in user's choice.
    if (ref
        .read(preferencesServiceProvider)
        .hasStoredDarkMode(settings.userId)) {
      await ref
          .read(themeModeControllerProvider.notifier)
          .toggleDarkMode(settings.darkMode);
      if (!mounted) return;
    }

    final repo = ref.read(smartHomeRepositoryProvider);
    final validated =
        await StartRouteSupport.validate(repo, settings.startRoute);
    if (!mounted) return;
    ref.read(effectiveStartRouteProvider.notifier).setRoute(validated);
    ref.read(appSettingsReadyProvider.notifier).setReady(true);
    ref.read(routerRedirectTriggerProvider).refresh();
  }

  @override
  Widget build(BuildContext context) {
    // Registered unconditionally: it must already exist when the user id
    // flips from null to a value (fresh login). Settings may have finished
    // loading before the settings listener below was registered.
    // Invalidated here, not via ref.watch inside the parameter providers:
    // a watch makes those providers invalidate themselves while TickerMode
    // is still building, which Riverpod rejects.
    ref.listen(connectionModeProvider, (previous, next) {
      if (previous == null || previous == next) return;
      ref.invalidate(cpParametersProvider);
      ref.invalidate(cpActiveParametersProvider);
    });

    ref.listen(authUserIdProvider, (previous, next) {
      // Logout: nothing to do. Invalidating on logout makes dependent
      // providers (e.g. isDirectConnectionProvider) rebuild twice within one
      // frame, which Riverpod rejects; the next login invalidates anyway.
      if (next == null) {
        ref.read(appSettingsReadyProvider.notifier).setReady(false);
        return;
      }
      if (next == previous) return;
      // Per-user data must not survive a login/account switch. Done here
      // (outside of build) instead of via provider dependencies.
      ref.invalidate(appSettingsProvider);
      ref.invalidate(connectionAppSettingsProvider);
      ref.invalidate(currentUserProvider);
      ref.invalidate(housesProvider);
      ref.invalidate(mySharesProvider);
      ref.invalidate(sharedWithMeProvider);
      ref.invalidate(notificationsProvider);
      ref.invalidate(deviceAccessRequestProvider);
      ref.invalidate(shareableTargetsProvider);
      ref.invalidate(ownedLocationIdsProvider);
      // Rebuild providers that have dependents right now (outside of build).
      // Otherwise they are flushed lazily by the first widget watching them,
      // which makes their dependents invalidate themselves during build.
      ref.read(connectionAppSettingsProvider);
      ref.read(currentUserProvider);
      ref.read(housesProvider);
      ref.read(appSettingsProvider.future).then(_apply, onError: (_) {});
    });

    // Watching the user id rebuilds this widget on login/logout.
    final userId = ref.watch(authUserIdProvider);
    if (userId != null) {
      ref.listen(appSettingsProvider, (previous, next) {
        next.whenData(_apply);
      });
    }

    return widget.child;
  }
}