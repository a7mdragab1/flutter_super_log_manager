import 'package:flutter/material.dart';

import 'log_entry.dart';

/// Configuration for [SuperLogManager.runApp].
///
/// This class holds all the settings to customize the behavior and appearance
/// of the logger and debug overlay.
class SuperLogConfig {
  /// Enable or disable the debug tool completely (default true)
  final bool enabled;

  /// Maximum number of logs to keep in memory (default 1000)
  final int maxLogs;

  /// Show debug overlay bubble (default true)
  final bool showOverlayBubble;

  /// Auto-detect error level from message text (default true)
  final bool autoDetectErrorLevel;

  /// Capture debugPrint calls (default true)
  final bool captureDebugPrint;

  /// Capture print() calls via ZoneSpecification (default true)
  final bool capturePrint;

  /// Bubble size (diameter) (default 56.0)
  final double bubbleSize;

  /// Initial bubble position (offset from top-start corner)
  /// (default Offset(16.0, 100.0))
  final Offset initialBubblePosition;

  /// Bubble color (default Color(0xCCFF0000))
  final Color bubbleColor;

  /// Bubble icon color (default Colors.white)
  final Color bubbleIconColor;

  /// Error badge color (default Colors.red)
  final Color errorBadgeColor;

  /// Error badge text color (default Colors.white)
  final Color errorBadgeTextColor;

  /// Enable drag to reposition bubble (default true)
  final bool enableBubbleDrag;

  /// Hide bubble when the log panel is visible (default true)
  final bool hideBubbleWhenScreenOpen;

  /// Panel height as fraction of screen height (0.0 to 1.0)
  /// Default: 0.9 (90% of screen height)
  final double panelHeightFraction;

  /// Dim background when overlay is open (default true)
  final bool dimOverlayBackground;

  /// Enable log filtering (default true)
  final bool enableLogFiltering;

  /// Enable log search (default true)
  final bool enableLogSearch;

  /// Enable log deletion (default true)
  final bool enableLogDeletion;

  /// Enable log export (default true)
  final bool enableLogExport;

  /// Mirror each log entry to debug console output (default true)
  final bool mirrorLogsToConsole;

  /// Default log level filter (null = show all)
  final LogLevel? defaultLogLevelFilter;

  const SuperLogConfig({
    this.enabled = true,
    this.maxLogs = 1000,
    this.showOverlayBubble = true,
    this.autoDetectErrorLevel = true,
    this.captureDebugPrint = true,
    this.capturePrint = true,
    this.bubbleSize = 56.0,
    this.initialBubblePosition = const Offset(16.0, 100.0),
    this.bubbleColor = const Color(0xCCFF0000), // Red with opacity
    this.bubbleIconColor = Colors.white,
    this.errorBadgeColor = Colors.red,
    this.errorBadgeTextColor = Colors.white,
    this.enableBubbleDrag = true,
    this.hideBubbleWhenScreenOpen = true,
    this.panelHeightFraction = 0.9,
    this.dimOverlayBackground = true,
    this.enableLogFiltering = true,
    this.enableLogSearch = true,
    this.enableLogDeletion = true,
    this.enableLogExport = true,
    this.mirrorLogsToConsole = true,
    this.defaultLogLevelFilter,
  });

  /// Creates a disabled configuration.
  ///
  /// When this constructor is used, the logger and debug overlay are completely disabled.
  /// This is useful for production builds where you want to strip out the debug tools.
  const SuperLogConfig.disabled()
    : enabled = false,
      maxLogs = 0,
      showOverlayBubble = false,
      autoDetectErrorLevel = false,
      captureDebugPrint = false,
      capturePrint = false,
      bubbleSize = 56.0,
      initialBubblePosition = const Offset(16.0, 100.0),
      bubbleColor = const Color(0xCCFF0000),
      bubbleIconColor = Colors.white,
      errorBadgeColor = Colors.red,
      errorBadgeTextColor = Colors.white,
      enableBubbleDrag = true,
      hideBubbleWhenScreenOpen = true,
      panelHeightFraction = 0.9,
      dimOverlayBackground = true,
      enableLogFiltering = true,
      enableLogSearch = true,
      enableLogDeletion = true,
      enableLogExport = true,
      mirrorLogsToConsole = true,
      defaultLogLevelFilter = null;
}
