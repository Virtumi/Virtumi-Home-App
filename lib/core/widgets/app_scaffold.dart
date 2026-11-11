import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// Back target for the left-edge swipe. [AppHeader] writes it; the scaffold
/// reads it when the gesture ends, so custom back actions stay in sync
/// without rebuilding the scaffold.
class ScaffoldBackAction {
  VoidCallback? onBack;
  bool showBack = false;
  Object? owner;
}

/// Exposes [ScaffoldBackAction] to the header without rebuilding on updates.
class ScaffoldBackScope extends InheritedWidget {
  const ScaffoldBackScope({
    super.key,
    required this.action,
    required super.child,
  });

  final ScaffoldBackAction action;

  static ScaffoldBackScope? maybeOf(BuildContext context) {
    final element =
        context.getElementForInheritedWidgetOfExactType<ScaffoldBackScope>();
    return element?.widget as ScaffoldBackScope?;
  }

  @override
  bool updateShouldNotify(ScaffoldBackScope oldWidget) =>
      action != oldWidget.action;
}

/// Publishes the header's back button to the enclosing [AppScaffold].
class BackActionRegistration extends StatefulWidget {
  const BackActionRegistration({
    super.key,
    required this.showBack,
    required this.onBack,
    required this.child,
  });

  final bool showBack;
  final VoidCallback? onBack;
  final Widget child;

  @override
  State<BackActionRegistration> createState() => _BackActionRegistrationState();
}

class _BackActionRegistrationState extends State<BackActionRegistration> {
  ScaffoldBackScope? _scope;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scope = ScaffoldBackScope.maybeOf(context);
    _publish();
  }

  @override
  void didUpdateWidget(BackActionRegistration oldWidget) {
    super.didUpdateWidget(oldWidget);
    _publish();
  }

  void _publish() {
    final action = _scope?.action;
    if (action == null) return;
    action.owner = this;
    action.showBack = widget.showBack;
    action.onBack = widget.onBack;
  }

  @override
  void dispose() {
    final action = _scope?.action;
    if (action != null && identical(action.owner, this)) {
      action.owner = null;
      action.showBack = false;
      action.onBack = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Base scaffold for every screen.
///
/// Handles the neumorphic background, a fixed (non-scrolling) [header] area, and
/// a centered, width-constrained content region for a consistent "handheld
/// remote" feel on tablets/desktop. The floating bottom navigation is provided
/// once by the navigation shell and overlays the content.
///
/// A drag from the left edge toward the right runs the same action as the
/// header back button.
class AppScaffold extends StatefulWidget {
  const AppScaffold({
    super.key,
    this.header,
    required this.body,
    this.maxContentWidth = AppSizes.maxContentWidth,
  });

  final Widget? header;
  final Widget body;
  final double maxContentWidth;

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  static const _edgeWidth = 28.0;
  static const _triggerDistance = 72.0;

  final ScaffoldBackAction _action = ScaffoldBackAction();
  double _dragDx = 0;

  void _onDragStart(DragStartDetails _) {
    _dragDx = 0;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _dragDx += details.delta.dx;
  }

  void _onDragEnd(DragEndDetails _) {
    if (!_action.showBack || _dragDx < _triggerDistance) return;
    final onBack = _action.onBack;
    if (onBack != null) {
      onBack();
      return;
    }
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldBackScope(
      action: _action,
      child: Scaffold(
        backgroundColor: context.colors.surface,
        body: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: widget.maxContentWidth),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ?widget.header,
                      Expanded(child: widget.body),
                    ],
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: _edgeWidth,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onHorizontalDragStart: _onDragStart,
                      onHorizontalDragUpdate: _onDragUpdate,
                      onHorizontalDragEnd: _onDragEnd,
                      onHorizontalDragCancel: () => _dragDx = 0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Standard scrolling content region with consistent horizontal padding and
/// bottom clearance so content can scroll clear of the floating nav bar.
class AppScrollView extends StatelessWidget {
  const AppScrollView({
    super.key,
    required this.children,
    this.spacing = AppSpacing.cardGap,
    this.padding,
    this.bottomClearance,
    this.controller,
  });

  final List<Widget> children;
  final double spacing;
  final EdgeInsetsGeometry? padding;

  /// When null, uses [AppSpacing.scrollBottomClearance] (nav + system inset + gap).
  final double? bottomClearance;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final resolvedBottomClearance =
        bottomClearance ?? AppSpacing.scrollBottomClearance(context);
    final resolvedPadding = padding ??
        EdgeInsets.fromLTRB(
          AppSpacing.containerPadding,
          AppSpacing.gutter,
          AppSpacing.containerPadding,
          resolvedBottomClearance,
        );

    return SingleChildScrollView(
      controller: controller,
      clipBehavior: Clip.hardEdge,
      padding: resolvedPadding,
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _withSpacing(children, spacing),
      ),
    );
  }

  List<Widget> _withSpacing(List<Widget> items, double gap) {
    if (items.isEmpty) return items;
    final result = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      result.add(items[i]);
      if (i != items.length - 1) result.add(SizedBox(height: gap));
    }
    return result;
  }
}
