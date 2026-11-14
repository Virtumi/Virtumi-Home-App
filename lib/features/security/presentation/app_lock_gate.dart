import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/security/app_lock_providers.dart';
import '../../../shared/models/models.dart';
import '../../../shared/providers/data_providers.dart';
import 'app_lock_screen.dart';

/// Observes app lifecycle and shows the lock overlay when security is enabled.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  var _wasInBackground = false;
  var _pendingColdStartLock = false;
  late final bool _sessionWasRestoredAtStart;

  @override
  void initState() {
    super.initState();
    _sessionWasRestoredAtStart =
        Supabase.instance.client.auth.currentSession != null;
    _pendingColdStartLock = _sessionWasRestoredAtStart;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _evaluateLock());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Only `paused` means the app truly went to background. On iOS, Face ID
    // triggers `inactive` without leaving the app — must not re-lock on that.
    if (state == AppLifecycleState.paused) {
      _wasInBackground = true;
      return;
    }

    if (state == AppLifecycleState.resumed && _wasInBackground) {
      _wasInBackground = false;
      _lockIfNeeded(force: true);
    }
  }

  void _evaluateLock() {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      ref.read(appLockProvider.notifier).reset();
      return;
    }

    _lockIfNeeded();
  }

  bool _isLockConfigured(AppSettings settings, bool hasLocalPin) {
    final pinActive = settings.pinEnabled && hasLocalPin;
    if (settings.biometricEnabled && !pinActive) return false;
    return pinActive;
  }

  void _lockIfNeeded({bool force = false}) {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;

    final shouldForce = force || _pendingColdStartLock;
    final lockNotifier = ref.read(appLockProvider.notifier);
    if (shouldForce && lockNotifier.shouldSuppressResumeLock) return;

    final settings = ref.read(appSettingsProvider).value;
    if (settings == null) return;

    final hasLocalPinAsync = ref.read(hasLocalPinProvider(settings.userId));
    if (hasLocalPinAsync.isLoading) return;

    final hasLocalPin = hasLocalPinAsync.value ?? false;
    if (!_isLockConfigured(settings, hasLocalPin)) {
      lockNotifier.unlock();
      return;
    }

    final lockState = ref.read(appLockProvider);
    if (!shouldForce && lockState.skipLockUntilBackground && !lockState.isLocked) {
      return;
    }

    lockNotifier.lock();
    _pendingColdStartLock = false;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authStateProvider, (previous, next) {
      next.whenData((state) {
        final hadSession = previous?.value?.session != null;
        final hasSession = state.session != null;

        if (!hasSession) {
          ref.read(appLockProvider.notifier).reset();
          return;
        }

        if (!hadSession && hasSession) {
          if (_sessionWasRestoredAtStart) {
            _lockIfNeeded(force: true);
          } else {
            ref.read(appLockProvider.notifier).unlockAfterLogin();
          }
        }
      });
    });

    ref.listen(appSettingsProvider, (previous, next) {
      next.whenData((settings) {
        if (settings == null) return;
        final pinAsync = ref.read(hasLocalPinProvider(settings.userId));
        if (pinAsync.isLoading) return;
        final hasLocalPin = pinAsync.value ?? false;
        if (!_isLockConfigured(settings, hasLocalPin)) {
          ref.read(appLockProvider.notifier).unlock();
          _pendingColdStartLock = false;
        } else {
          _lockIfNeeded();
        }
      });
    });

    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      ref.listen(hasLocalPinProvider(session.user.id), (previous, next) {
        if (next.hasValue) _lockIfNeeded();
      });
    }

    final settings = ref.watch(appSettingsProvider).value;
    // Selected directly (no derived provider): the lock state can change
    // several times within one frame on sign-out, and a derived Provider
    // rebuilding twice per frame crashes in Riverpod.
    final isLocked = ref.watch(appLockProvider.select((s) => s.isLocked));
    final hasLocalPin =
        ref.watch(hasLocalPinProvider(session?.user.id ?? '')).value ?? false;

    final pinActive = settings?.pinEnabled == true && hasLocalPin;
    final lockConfigured =
        settings != null && _isLockConfigured(settings, hasLocalPin);

    final showLock =
        session != null && settings != null && isLocked && lockConfigured;

    return Stack(
      alignment: Alignment.topLeft,
      children: [
        widget.child,
        if (showLock)
          Positioned.fill(
            child: AppLockScreen(
              userId: session.user.id,
              biometricEnabled: settings.biometricEnabled && pinActive,
              pinEnabled: pinActive,
              onUnlocked: () => ref.read(appLockProvider.notifier).unlock(),
            ),
          ),
      ],
    );
  }
}
