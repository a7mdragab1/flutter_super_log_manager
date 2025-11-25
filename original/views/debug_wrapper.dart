import 'package:flutter/material.dart';
import 'debug_overlay_bubble.dart';
import '../super_log_manager.dart';

/// Widget to wrap the entire app and provide the debug overlay
/// Pure Flutter implementation - no GetX dependencies
///
/// Automatically shows debug overlay if LogManager is initialized
/// Uses LogManager.instance directly (singleton pattern)
class SuperDebugWrapper extends StatelessWidget {
  final Widget child;

  const SuperDebugWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Check if LogManager is initialized and overlay is enabled
    final config = SuperLogManager.config;
    if (!SuperLogManager.isInitialized || config?.showOverlayBubble != true) {
      return child;
    }

    // LogManager is initialized and overlay enabled - show debug overlay
    // Default to RTL since app defaults to Arabic locale
    // The bubble will read direction from its context and update accordingly
    return Directionality(
      textDirection: TextDirection.rtl, // Default to RTL (Arabic)
      child: Stack(
        children: [child, const SuperDebugOverlayBubble()],
      ),
    );
  }
}
