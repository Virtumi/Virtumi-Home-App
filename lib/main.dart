import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/app_constants.dart';
import 'core/navigation/app_router.dart';
import 'core/services/app_settings_bootstrap.dart';
import 'core/services/preferences_service.dart';
import 'core/services/theme_controller.dart';
import 'core/supabase/supabase_config.dart';
import 'core/theme/theme.dart';
import 'features/security/presentation/app_lock_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!SupabaseConfig.isConfigured) {
    throw StateError(
      'SUPABASE_ANON_KEY fehlt. Starte mit '
      '--dart-define=SUPABASE_ANON_KEY=...',
    );
  }

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
  );

  final prefs = await SharedPreferences.getInstance();
  final preferencesService = PreferencesService(prefs);
  await preferencesService.clearLegacyRecentLists();

  runApp(
    ProviderScope(
      overrides: [
        preferencesServiceProvider.overrideWithValue(preferencesService),
      ],
      child: AppSettingsBootstrap(
        child: const VirtumiHomeApp(),
      ),
    ),
  );
}

/// Root application widget. Wires the global theme + router and reacts to the
/// persisted [ThemeMode].
class VirtumiHomeApp extends ConsumerWidget {
  const VirtumiHomeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeControllerProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        return AppLockGate(child: child ?? const SizedBox.shrink());
      },
    );
  }
}
