import 'package:flutter/material.dart';
import 'log_navigation_callbacks.dart';
import '../models/log_entry.dart';

/// Configuration for SuperLogManager.runApp
class SuperLogConfig {
  /// Enable or disable the debug tool completely
  final bool enabled;

  /// Maximum number of logs to keep in memory
  final int maxLogs;

  /// Show debug overlay bubble
  final bool showOverlayBubble;

  /// Auto-detect error level from message text
  final bool autoDetectErrorLevel;

  /// Capture debugPrint calls
  final bool captureDebugPrint;

  /// Capture print() calls via ZoneSpecification
  final bool capturePrint;

  /// Navigation callbacks for custom navigation systems
  /// If null, uses default Flutter Navigator
  final SuperLogNavigationCallbacks? navigationCallbacks;

  /// Bubble size (diameter)
  final double bubbleSize;

  /// Initial bubble position (corner of the bubble)
  /// Respects app text direction (RTL/LTR):
  /// - RTL: dx = distance from right edge, dy = distance from top
  /// - LTR: dx = distance from left edge, dy = distance from top
  /// Offset(16, 100) means 16 pixels from the appropriate edge, 100 pixels from top
  /// Default: Offset(16.0, 100.0)
  final Offset initialBubblePosition;

  /// Bubble color
  final Color bubbleColor;

  /// Bubble icon color
  final Color bubbleIconColor;

  /// Error badge color
  final Color errorBadgeColor;

  /// Error badge text color
  final Color errorBadgeTextColor;

  /// Enable drag to reposition bubble
  final bool enableBubbleDrag;

  /// Hide bubble when debug screen is open
  final bool hideBubbleWhenScreenOpen;

  /// Debug log screen route name (for named routes)
  /// Default: '/super-debug-log'
  final String debugLogRouteName;

  /// Enable log filtering
  final bool enableLogFiltering;

  /// Enable log search
  final bool enableLogSearch;

  /// Enable log deletion
  final bool enableLogDeletion;

  /// Enable log export
  final bool enableLogExport;

  /// Default log level filter (null = show all)
  final LogLevel? defaultLogLevelFilter;

  /// Enable auto-scroll to latest log
  final bool autoScrollToLatest;

  /// Log screen theme mode (null = use system theme)
  final ThemeMode? logScreenThemeMode;

  /// Enable performance optimizations
  final bool enablePerformanceOptimizations;

  /// Log retention duration (null = keep all logs)
  final Duration? logRetentionDuration;

  /// Enable log compression for large logs
  final bool enableLogCompression;

  /// Maximum log message length (null = no limit)
  final int? maxLogMessageLength;

  /// Enable crash reporting integration
  final bool enableCrashReporting;

  /// Custom crash reporter callback
  final void Function(Object error, StackTrace? stackTrace)? onCrashReport;

  /// Enable network log capture
  final bool enableNetworkLogCapture;

  /// Enable database log capture
  final bool enableDatabaseLogCapture;

  /// Enable UI interaction log capture
  final bool enableUIInteractionLogCapture;

  /// Platform-specific settings
  final Map<String, dynamic>? platformSettings;

  const SuperLogConfig({
    this.enabled = true,
    this.maxLogs = 1000,
    this.showOverlayBubble = true,
    this.autoDetectErrorLevel = true,
    this.captureDebugPrint = true,
    this.capturePrint = true,
    this.navigationCallbacks,
    this.bubbleSize = 56.0,
    this.initialBubblePosition = const Offset(16.0, 100.0),
    this.bubbleColor = const Color(0xCCFF0000), // Red with opacity
    this.bubbleIconColor = Colors.white,
    this.errorBadgeColor = Colors.red,
    this.errorBadgeTextColor = Colors.white,
    this.enableBubbleDrag = true,
    this.hideBubbleWhenScreenOpen = true,
    this.debugLogRouteName = '/super-debug-log',
    this.enableLogFiltering = true,
    this.enableLogSearch = true,
    this.enableLogDeletion = true,
    this.enableLogExport = true,
    this.defaultLogLevelFilter,
    this.autoScrollToLatest = true,
    this.logScreenThemeMode,
    this.enablePerformanceOptimizations = true,
    this.logRetentionDuration,
    this.enableLogCompression = false,
    this.maxLogMessageLength,
    this.enableCrashReporting = false,
    this.onCrashReport,
    this.enableNetworkLogCapture = false,
    this.enableDatabaseLogCapture = false,
    this.enableUIInteractionLogCapture = false,
    this.platformSettings,
  });

  /// Disabled configuration (tool completely ignored)
  const SuperLogConfig.disabled()
    : enabled = false,
      maxLogs = 0,
      showOverlayBubble = false,
      autoDetectErrorLevel = false,
      captureDebugPrint = false,
      capturePrint = false,
      navigationCallbacks = null,
      bubbleSize = 56.0,
      initialBubblePosition = const Offset(16.0, 100.0),
      bubbleColor = const Color(0xCCFF0000),
      bubbleIconColor = Colors.white,
      errorBadgeColor = Colors.red,
      errorBadgeTextColor = Colors.white,
      enableBubbleDrag = true,
      hideBubbleWhenScreenOpen = true,
      debugLogRouteName = '/super-debug-log',
      enableLogFiltering = true,
      enableLogSearch = true,
      enableLogDeletion = true,
      enableLogExport = true,
      defaultLogLevelFilter = null,
      autoScrollToLatest = true,
      logScreenThemeMode = null,
      enablePerformanceOptimizations = true,
      logRetentionDuration = null,
      enableLogCompression = false,
      maxLogMessageLength = null,
      enableCrashReporting = false,
      onCrashReport = null,
      enableNetworkLogCapture = false,
      enableDatabaseLogCapture = false,
      enableUIInteractionLogCapture = false,
      platformSettings = null;
}
