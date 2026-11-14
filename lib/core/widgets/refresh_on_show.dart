import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Reloads a screen's data every time the screen is built (first open) and
/// every time it becomes visible again after another route above it closed.
///
/// Usage: mix into the screen's [ConsumerState], implement [refreshOnShow]
/// (invalidate the providers the screen shows) and call [trackVisibility] at
/// the start of `build`.
///
/// Invalidation is deferred until after the current frame: invalidating a
/// provider while widgets are building throws "markNeedsBuild during build".
/// Already loaded data stays visible while the reload runs.
mixin RefreshOnShow<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  bool _wasHidden = false;

  /// Whether to reload right after the screen is first built. Disable when the
  /// providers are guaranteed to be freshly created at that point.
  bool get refreshOnInit => true;

  /// Invalidate the providers used by this screen.
  void refreshOnShow();

  @override
  void initState() {
    super.initState();
    if (refreshOnInit) _scheduleRefresh();
  }

  /// Call at the start of `build`. Detects the screen becoming visible again.
  void trackVisibility() {
    final isVisible = ModalRoute.of(context)?.isCurrent ?? true;
    if (isVisible && _wasHidden) _scheduleRefresh();
    _wasHidden = !isVisible;
  }

  void _scheduleRefresh() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) refreshOnShow();
    });
  }
}
