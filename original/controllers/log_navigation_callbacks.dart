import 'package:flutter/material.dart';

/// Navigation callbacks for custom navigation systems
/// Allows integration with GetX, go_router, auto_route, etc.
class SuperLogNavigationCallbacks {
  /// Navigate to debug log screen
  /// [debugLogScreenBuilder] provides the DebugLogScreen widget
  /// Return a Future that completes when navigation is done
  /// Example for GetX: `(builder) => Get.to(builder)`
  /// Example for go_router: `(builder) => router.push('/debug-log')`
  /// Example for Navigator: `(builder) => Navigator.push(context, MaterialPageRoute(builder: (_) => builder()))`
  final Future<void> Function(
    BuildContext? context,
    Widget Function() debugLogScreenBuilder,
  )?
  onNavigateToDebugLog;

  /// Navigate back
  /// Example for GetX: `() => Get.back()`
  /// Example for go_router: `() => router.pop()`
  /// Example for Navigator: `() => Navigator.pop(context)`
  final void Function(BuildContext? context)? onNavigateBack;

  /// Show snackbar/toast message
  /// Example for GetX: `(msg) => Get.snackbar('Info', msg)`
  /// Example for Flutter: `(msg) => ScaffoldMessenger.of(context).showSnackBar(...)`
  final void Function(BuildContext? context, String message)? onShowSnackbar;

  /// Check if can navigate back
  /// Example for Navigator: `(context) => Navigator.canPop(context)`
  final bool Function(BuildContext? context)? canNavigateBack;

  const SuperLogNavigationCallbacks({
    this.onNavigateToDebugLog,
    this.onNavigateBack,
    this.onShowSnackbar,
    this.canNavigateBack,
  });

  /// Default Flutter Navigator callbacks
  factory SuperLogNavigationCallbacks.flutter() {
    return SuperLogNavigationCallbacks(
      onNavigateToDebugLog: (context, debugLogScreenBuilder) async {
        if (context == null) return;
        final navigator = Navigator.of(context, rootNavigator: true);
        await navigator.push(
          MaterialPageRoute(
            builder: (_) => debugLogScreenBuilder(),
            fullscreenDialog: true,
          ),
        );
      },
      onNavigateBack: (context) {
        if (context == null) return;
        final navigator = Navigator.of(context, rootNavigator: true);
        if (navigator.canPop()) {
          navigator.pop();
        }
      },
      onShowSnackbar: (context, message) {
        if (context == null) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      canNavigateBack: (context) {
        if (context == null) return false;
        return Navigator.of(context, rootNavigator: true).canPop();
      },
    );
  }

  /// Create custom navigation callbacks for your navigation system
  ///
  /// Example for GetX:
  /// ```dart
  /// import 'package:your_app/core/routes/app_pages.dart';
  ///
  /// SuperLogNavigationCallbacks(
  ///   onNavigateToDebugLog: (context, builder) async =>
  ///       await Get.toNamed(Routes.SUPER_DEBUG_LOG),
  ///   onNavigateBack: (context) => Get.back(),
  ///   onShowSnackbar: (context, msg) => Get.snackbar('Info', msg),
  ///   canNavigateBack: (context) => Get.key.currentState?.canPop() ?? false,
  /// )
  /// ```
  ///
  /// Example for go_router:
  /// ```dart
  /// SuperLogNavigationCallbacks(
  ///   onNavigateToDebugLog: (context, builder) => router.push('/debug-log'),
  ///   onNavigateBack: (context) => router.pop(),
  ///   onShowSnackbar: (context, msg) => ScaffoldMessenger.of(context).showSnackBar(...),
  ///   canNavigateBack: (context) => router.canPop(),
  /// )
  /// ```
}
