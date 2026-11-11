import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/navigation/app_shell.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/security/app_lock_providers.dart';
import '../../../core/security/app_lock_service.dart';
import '../../../core/services/theme_controller.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../shared/models/models.dart';
import '../../../shared/providers/connection_mode_provider.dart';
import '../../../shared/providers/data_providers.dart';
import '../../../shared/providers/repository_providers.dart';
import '../../security/presentation/pin_setup_sheet.dart';
import '../application/start_screen_options_provider.dart';
import '../../profile/presentation/widgets/profile_card.dart';

/// Settings tab ("Einstellungen"): appearance, security, app and account.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final settingsAsync = ref.watch(appSettingsProvider);
    final startLabelAsync = ref.watch(startRouteDisplayLabelProvider);
    final isDark = ref.watch(isDarkModeProvider);
    final p = context.palette;

    Future<void> saveSettings(AppSettings settings) async {
      await ref.read(appSettingsRepositoryProvider).saveSettings(settings);
      ref.invalidate(appSettingsProvider);
      ref.invalidate(connectionAppSettingsProvider);
    }

    return AppScaffold(
      header: AppHeader(
        onBack: () {
          final shell = StatefulNavigationShell.maybeOf(context);
          final returnIndex = ref.read(settingsReturnBranchProvider);
          if (shell != null) {
            shell.goBranch(returnIndex);
            return;
          }
          context.go(Paths.home);
        },
      ),
      body: AsyncValueView<AppSettings?>(
        value: settingsAsync,
        onRetry: () => ref.invalidate(appSettingsProvider),
        data: (settings) {
          if (settings == null) {
            return const EmptyState(
              icon: Symbols.settings,
              message: 'Einstellungen nicht verfügbar',
            );
          }
          return AppScrollView(
            children: [
              const SectionHeaderCard(
                title: 'Einstellungen',
                icon: Symbols.settings,
              ),
              userAsync.when(
                data: (user) => ProfileCard(
                  user: user,
                  connectionLabel: settings.connectionModeLabel,
                  avatarHeroTag: 'profile-avatar',
                  onTap: () => context.push(Paths.profile),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
              const AppSectionLabel('Darstellung'),
              GroupedListCard(
                children: [
                  SettingsRow.toggle(
                    icon: Symbols.dark_mode,
                    title: 'Dark Mode',
                    iconColor: p.accentIndigo,
                    glow: true,
                    value: isDark,
                    onChanged: (v) async {
                      await ref
                          .read(themeModeControllerProvider.notifier)
                          .toggleDarkMode(v);
                      await saveSettings(settings.copyWith(darkMode: v));
                    },
                  ),
                  SettingsRow.navigation(
                    icon: Symbols.language,
                    title: 'Sprache',
                    iconColor: p.accentSky,
                    value: settings.languageLabel,
                    onTap: () => _pickLanguage(context, settings, saveSettings),
                  ),
                ],
              ),
              const AppSectionLabel('Sicherheit'),
              GroupedListCard(
                children: [
                  SettingsRow.toggle(
                    icon: Symbols.fingerprint,
                    title: 'Biometrische Entsperrung',
                    iconColor: p.accentOrange,
                    glow: true,
                    value: settings.biometricEnabled,
                    onChanged: (v) => _onBiometricChanged(
                      context,
                      ref,
                      settings,
                      saveSettings,
                      v,
                    ),
                  ),
                  SettingsRow.toggle(
                    icon: Symbols.pin,
                    title: 'PIN-Code',
                    iconColor: p.accentBlue,
                    value: settings.pinEnabled,
                    onChanged: (v) => _onPinChanged(
                      context,
                      ref,
                      settings,
                      saveSettings,
                      v,
                    ),
                  ),
                  SettingsRow.toggle(
                    icon: Symbols.verified_user,
                    title: 'Zwei-Faktor-Auth',
                    iconColor: p.accentGreen,
                    value: settings.twoFactorEnabled,
                    onChanged: (v) =>
                        saveSettings(settings.copyWith(twoFactorEnabled: v)),
                  ),
                ],
              ),
              const AppSectionLabel('App'),
              GroupedListCard(
                children: [
                  SettingsRow.navigation(
                    icon: Symbols.home,
                    title: 'Startbild',
                    iconColor: p.accentTeal,
                    value: startLabelAsync.maybeWhen(
                      data: (label) => label,
                      orElse: () => 'Home',
                    ),
                    onTap: () => context.push(Paths.startScreen),
                  ),
                  SettingsRow.toggle(
                    icon: Symbols.history,
                    title: 'Letzte Aktivitäten',
                    iconColor: p.accentIndigo,
                    value: settings.showRecentActivity,
                    onChanged: (v) => saveSettings(
                      settings.copyWith(showRecentActivity: v),
                    ),
                  ),
                  SettingsRow.toggle(
                    icon: Symbols.favorite,
                    title: 'Favoriten',
                    iconColor: p.accentRed,
                    value: settings.showFavorites,
                    onChanged: (v) => saveSettings(
                      settings.copyWith(showFavorites: v),
                    ),
                  ),
                  SettingsRow.navigation(
                    icon: Symbols.cloud_sync,
                    title: 'Verbindungsart',
                    iconColor: p.accentBlue,
                    value: settings.connectionModeLabel,
                    onTap: () =>
                        _pickConnectionMode(context, settings, saveSettings),
                  ),
                  SettingsRow.navigation(
                    icon: Symbols.new_releases,
                    title: 'Was ist neu',
                    iconColor: p.accentAmber,
                    value: AppConstants.appVersion,
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Changelog folgt in einer späteren Version'),
                      ),
                    ),
                  ),
                  SettingsRow.navigation(
                    icon: Symbols.help_center,
                    title: 'Hilfe & Support',
                    iconColor: p.accentCyan,
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Hilfe & Support folgt in einer späteren Version'),
                      ),
                    ),
                  ),
                  SettingsRow.navigation(
                    icon: Symbols.policy,
                    title: 'Datenschutzerklärung',
                    iconColor: p.accentPurple,
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Datenschutzerklärung folgt in einer späteren Version'),
                      ),
                    ),
                  ),
                ],
              ),
              const AppSectionLabel('Konto'),
              GroupedListCard(
                children: [
                  SettingsRow.navigation(
                    icon: Symbols.person_edit,
                    title: 'Profil bearbeiten',
                    iconColor: p.accentStone,
                    onTap: () => context.push(Paths.profile),
                  ),
                  SettingsRow.navigation(
                    icon: Symbols.logout,
                    title: 'Abmelden',
                    iconColor: p.accentRed,
                    danger: true,
                    onTap: () async {
                      final userId = settings.userId;
                      await ref.read(appLockServiceProvider).clearPin(userId);
                      ref.read(appLockProvider.notifier).reset();
                      await ref.read(authRepositoryProvider).signOut();
                      if (context.mounted) context.go(Paths.login);
                    },
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.gutter),
                child: Text(
                  AppConstants.legalFooter,
                  textAlign: TextAlign.center,
                  style: context.text.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _pickLanguage(
    BuildContext context,
    AppSettings settings,
    Future<void> Function(AppSettings) save,
  ) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Deutsch'),
              trailing: settings.language == 'de'
                  ? Icon(Icons.check, color: Theme.of(ctx).colorScheme.primary)
                  : null,
              onTap: () => Navigator.pop(ctx, 'de'),
            ),
            ListTile(
              title: const Text('English'),
              trailing: settings.language == 'en'
                  ? Icon(Icons.check, color: Theme.of(ctx).colorScheme.primary)
                  : null,
              onTap: () => Navigator.pop(ctx, 'en'),
            ),
          ],
        ),
      ),
    );
    if (picked != null && picked != settings.language) {
      await save(settings.copyWith(language: picked));
    }
  }

  Future<void> _pickConnectionMode(
    BuildContext context,
    AppSettings settings,
    Future<void> Function(AppSettings) save,
  ) async {
    const modes = ['cloud', 'direct'];
    final picked = await showOptionPicker<String>(
      context: context,
      title: 'Verbindungsart',
      options: modes,
      labelOf: (mode) => mode == 'cloud' ? 'Cloud' : 'Lokales Netzwerk',
      selected: settings.connectionMode,
    );
    if (picked != null && picked != settings.connectionMode) {
      await save(settings.copyWith(connectionMode: picked));
    }
  }
}

Future<void> _onPinChanged(
  BuildContext context,
  WidgetRef ref,
  AppSettings settings,
  Future<void> Function(AppSettings) save,
  bool enabled,
) async {
  if (!AppLockService.isPlatformSupported) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('PIN-Schutz ist nur auf iOS und Android verfügbar.'),
      ),
    );
    return;
  }

  final lockService = ref.read(appLockServiceProvider);

  if (enabled) {
    final pin = await showPinSetupSheet(context);
    if (pin == null || !context.mounted) return;

    await lockService.setPin(settings.userId, pin);
    ref.invalidate(hasLocalPinProvider(settings.userId));
    await save(settings.copyWith(pinEnabled: true));
    ref.read(appLockProvider.notifier).lock();
    return;
  }

  final disableBiometric = settings.biometricEnabled;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('PIN deaktivieren?'),
      content: Text(
        disableBiometric
            ? 'Der gespeicherte PIN wird entfernt. '
                'Die biometrische Entsperrung wird ebenfalls deaktiviert.'
            : 'Der gespeicherte PIN wird von diesem Gerät entfernt.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Deaktivieren'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  await lockService.clearPin(settings.userId);
  ref.invalidate(hasLocalPinProvider(settings.userId));
  await save(
    settings.copyWith(
      pinEnabled: false,
      biometricEnabled: disableBiometric ? false : settings.biometricEnabled,
    ),
  );
  ref.read(appLockProvider.notifier).unlock();
}

Future<void> _onBiometricChanged(
  BuildContext context,
  WidgetRef ref,
  AppSettings settings,
  Future<void> Function(AppSettings) save,
  bool enabled,
) async {
  if (!AppLockService.isPlatformSupported) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Biometrie ist nur auf iOS und Android verfügbar.'),
      ),
    );
    return;
  }

  final lockService = ref.read(appLockServiceProvider);
  final lockNotifier = ref.read(appLockProvider.notifier);

  if (enabled) {
    final support = await lockService.checkBiometricSupport();
    if (!support.isAvailable) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            support.errorMessage ??
                'Biometrie ist auf diesem Gerät nicht verfügbar.',
          ),
        ),
      );
      return;
    }

    var hasPin = await lockService.hasPin(settings.userId);
    if (!hasPin) {
      if (!context.mounted) return;
      final pin = await showPinSetupSheet(context);
      if (pin == null || !context.mounted) return;
      await lockService.setPin(settings.userId, pin);
      ref.invalidate(hasLocalPinProvider(settings.userId));
      hasPin = true;
    }

    lockNotifier.suppressResumeLockFor(const Duration(seconds: 5));
    final authenticated = await lockService.authenticateWithBiometrics(
      reason: 'Biometrie für Virtumi Home aktivieren',
    );
    lockNotifier.suppressResumeLockFor(const Duration(seconds: 2));

    if (!authenticated || !context.mounted) return;

    await save(
      settings.copyWith(
        pinEnabled: true,
        biometricEnabled: true,
      ),
    );
    lockNotifier.unlock();
    return;
  }

  await save(settings.copyWith(biometricEnabled: false));
  if (!settings.pinEnabled) {
    lockNotifier.unlock();
  }
}
