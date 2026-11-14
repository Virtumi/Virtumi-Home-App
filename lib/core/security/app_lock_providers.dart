import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_lock_service.dart';

final appLockServiceProvider = Provider<AppLockService>((ref) {
  return AppLockService();
});

/// Whether the authenticated app content is currently behind the lock overlay.
class AppLockState {
  const AppLockState({
    this.isLocked = false,
    this.skipLockUntilBackground = false,
  });

  final bool isLocked;
  final bool skipLockUntilBackground;

  @override
  bool operator ==(Object other) =>
      other is AppLockState &&
      other.isLocked == isLocked &&
      other.skipLockUntilBackground == skipLockUntilBackground;

  @override
  int get hashCode => Object.hash(isLocked, skipLockUntilBackground);

  AppLockState copyWith({
    bool? isLocked,
    bool? skipLockUntilBackground,
  }) {
    return AppLockState(
      isLocked: isLocked ?? this.isLocked,
      skipLockUntilBackground:
          skipLockUntilBackground ?? this.skipLockUntilBackground,
    );
  }
}

class AppLockNotifier extends Notifier<AppLockState> {
  DateTime? _suppressResumeLockUntil;

  @override
  AppLockState build() => const AppLockState();

  bool get shouldSuppressResumeLock {
    final until = _suppressResumeLockUntil;
    if (until == null) return false;
    if (DateTime.now().isBefore(until)) return true;
    _suppressResumeLockUntil = null;
    return false;
  }

  void suppressResumeLockFor(Duration duration) {
    _suppressResumeLockUntil = DateTime.now().add(duration);
  }

  void clearResumeLockSuppression() {
    _suppressResumeLockUntil = null;
  }

  void lock() {
    if (state.isLocked) return;
    state = state.copyWith(isLocked: true, skipLockUntilBackground: false);
  }

  void unlock() {
    if (!state.isLocked && state.skipLockUntilBackground) return;
    suppressResumeLockFor(const Duration(seconds: 2));
    state = state.copyWith(
      isLocked: false,
      skipLockUntilBackground: true,
    );
  }

  void unlockAfterLogin() {
    suppressResumeLockFor(const Duration(seconds: 2));
    state = const AppLockState(skipLockUntilBackground: true);
  }

  void reset() {
    _suppressResumeLockUntil = null;
    state = const AppLockState();
  }
}

final appLockProvider =
    NotifierProvider<AppLockNotifier, AppLockState>(AppLockNotifier.new);

final hasLocalPinProvider = FutureProvider.family<bool, String>((ref, userId) {
  return ref.watch(appLockServiceProvider).hasPin(userId);
});
