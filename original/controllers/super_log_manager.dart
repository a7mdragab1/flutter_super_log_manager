import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart' as flutter;
import '../models/log_entry.dart';
import '../views/debug_wrapper.dart';
import 'log_config.dart';
import 'log_navigation_callbacks.dart';
import 'default_error_widget.dart';

/// Pure Flutter log manager using ChangeNotifier for state management
class SuperLogManager extends ChangeNotifier {
  static SuperLogManager? _instance;
  static SuperLogConfig? _config;
  static bool _isCapturingPrint = false;
  static bool _isInDebugPrint = false;

  static SuperLogManager init({SuperLogConfig? config}) {
    _config = config ?? const SuperLogConfig();
    if (!_config!.enabled) {
      return _instance ??= SuperLogManager._disabled();
    }
    _instance ??= SuperLogManager._();
    return _instance!;
  }

  static bool get isInitialized =>
      _instance != null && _config?.enabled != false;

  static SuperLogConfig? get config => _config;

  static SuperLogNavigationCallbacks get navigationCallbacks {
    final configCallbacks = _config?.navigationCallbacks;
    return configCallbacks ?? SuperLogNavigationCallbacks.flutter();
  }

  static SuperLogManager get instance {
    if (_config?.enabled == false) {
      return _instance ??= SuperLogManager._disabled();
    }
    _instance ??= SuperLogManager._();
    return _instance!;
  }

  /// Run app with automatic error handling
  ///
  /// CRITICAL FIX: Don't use runZonedGuarded - it creates a new zone that causes
  /// binding mismatch. Instead, use FlutterError.onError and PlatformDispatcher.instance.onError
  static void runApp(
    flutter.Widget app, {
    SuperLogConfig? config,
    flutter.Widget Function(Object error)? errorWidget,
    FutureOr<bool> Function()? preRun,
    void Function()? postRun,
  }) async {
    final finalConfig = config ?? const SuperLogConfig();
    final finalErrorWidget =
        errorWidget ?? ((error) => SuperDefaultErrorWidget(error));

    // Initialize bindings first (in current zone)
    flutter.WidgetsFlutterBinding.ensureInitialized();

    // Initialize LogManager if enabled
    if (finalConfig.enabled) {
      init(config: finalConfig);
    }

    // Set up error handlers (works in same zone)
    if (finalConfig.enabled) {
      _setupErrorHandlers(finalConfig, finalErrorWidget);
    }

    try {
      // Run preRun hook
      if (preRun != null) {
        final preRunResult = await preRun();
        if (preRunResult == false) {
          debugPrint('preRun returned false, aborting app start');
          return;
        }
      }

      // Run app in the SAME zone (no runZonedGuarded)
      flutter.runApp(finalConfig.enabled ? SuperDebugWrapper(child: app) : app);

      // Run postRun hook after first frame
      if (postRun != null) {
        // SchedulerBinding.instance.addPostFrameCallback((_) {
        Future.microtask(() async {
          try {
            postRun();
          } catch (e) {
            debugPrint('Error in postRun: $e');
            if (isInitialized) {
              try {
                instance.addLog(
                  'Error in postRun: $e',
                  level: LogLevel.error,
                  error: e,
                );
              } catch (logError) {
                debugPrint('Error logging postRun error: $logError');
              }
            }
          }
        });
        // });
      }
    } catch (e, stackTrace) {
      debugPrint('Error initializing app: $e');
      debugPrint('Stack trace: $stackTrace');

      if (isInitialized) {
        try {
          instance.addLog(
            'Error initializing app: $e',
            level: LogLevel.error,
            error: e,
            stackTrace: stackTrace,
          );
        } catch (logError) {
          debugPrint('Error logging initialization error: $logError');
        }
      }

      try {
        flutter.runApp(finalErrorWidget(e));
      } catch (errorWidgetError) {
        debugPrint('Error showing error widget: $errorWidgetError');
        flutter.runApp(
          flutter.MaterialApp(
            home: flutter.Scaffold(
              body: flutter.Center(
                child: flutter.Text('Failed to initialize app: $e'),
              ),
            ),
          ),
        );
      }
    }
  }

  /// Set up error handlers without creating new zones
  static void _setupErrorHandlers(
    SuperLogConfig config,
    flutter.Widget Function(Object error) errorWidget,
  ) {
    // Handle Flutter framework errors
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      // Log to LogManager
      if (isInitialized) {
        try {
          instance.addLog(
            details.exception.toString(),
            level: LogLevel.error,
            error: details.exception,
            stackTrace: details.stack,
          );
        } catch (e) {
          debugPrint('Error logging Flutter error: $e');
        }
      }

      // Call original handler
      if (originalOnError != null) {
        originalOnError(details);
      } else {
        // Default behavior
        FlutterError.presentError(details);
      }

      // Crash reporting if enabled
      if (config.enableCrashReporting && config.onCrashReport != null) {
        try {
          config.onCrashReport!(details.exception, details.stack);
        } catch (e) {
          debugPrint('Error in crash reporter: $e');
        }
      }
    };

    // Handle async errors
    PlatformDispatcher.instance.onError = (error, stack) {
      // Log to LogManager
      if (isInitialized) {
        try {
          instance.addLog(
            error.toString(),
            level: LogLevel.error,
            error: error,
            stackTrace: stack,
          );
        } catch (e) {
          debugPrint('Error logging platform error: $e');
        }
      }

      debugPrint('Uncaught platform error: $error');

      // Crash reporting if enabled
      if (config.enableCrashReporting && config.onCrashReport != null) {
        try {
          config.onCrashReport!(error, stack);
        } catch (e) {
          debugPrint('Error in crash reporter: $e');
        }
      }

      return true; // Prevent app from crashing
    };

    // Hook print if capturePrint is enabled
    if (config.capturePrint) {
      _hookPrint();
    }
  }

  /// Hook into print() to capture logs
  static void _hookPrint() {
    // Store original print
    final originalPrint = print;

    // Override print in current zone
    Zone.current
        .fork(
          specification: ZoneSpecification(
            print: (self, parent, zone, line) {
              // Call original print
              originalPrint(line);

              // Capture in LogManager
              if (isInitialized && !_isCapturingPrint && !_isInDebugPrint) {
                _isCapturingPrint = true;
                try {
                  instance.addLog(line, skipDebugPrint: true);
                } finally {
                  _isCapturingPrint = false;
                }
              }
            },
          ),
        )
        .run(() {
          // This establishes the zone specification for future prints
          // The zone is active for the entire app lifecycle
        });
  }

  final bool _isDisabled;

  SuperLogManager._() : _isDisabled = false {
    if (_config?.captureDebugPrint == true) {
      _hookDebugPrint();
    }
  }

  SuperLogManager._disabled() : _isDisabled = true;

  final List<SuperLogEntry> _logs = [];

  int get maxLogs => _config?.maxLogs ?? 1000;

  List<SuperLogEntry> get logs => List.unmodifiable(_logs);

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  LogLevel? _levelFilter;
  LogLevel? get levelFilter => _levelFilter;

  List<SuperLogEntry>? _cachedFilteredLogs;
  String? _cachedSearchQuery;
  LogLevel? _cachedLevelFilter;
  int? _cachedLogsLength;

  final bool _isExpanded = false;
  bool get isExpanded => _isExpanded;

  Timer? _batchTimer;
  final List<SuperLogEntry> _pendingLogs = [];

  void _hookDebugPrint() {
    final originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) {
        _isInDebugPrint = true;
        try {
          addLog(message, level: LogLevel.debug, skipDebugPrint: true);
          originalDebugPrint(message, wrapWidth: wrapWidth);
        } finally {
          _isInDebugPrint = false;
        }
      }
    };
  }

  void addLog(
    String message, {
    LogLevel level = LogLevel.info,
    String? tag,
    Object? error,
    StackTrace? stackTrace,
    bool skipDebugPrint = false,
  }) {
    if (_isDisabled) return;

    String finalMsg = message;
    if (_config?.maxLogMessageLength != null &&
        finalMsg.length > _config!.maxLogMessageLength!) {
      finalMsg =
          '${finalMsg.substring(0, _config!.maxLogMessageLength!)}... [truncated]';
    }

    String? finalTag = tag;
    if (finalTag == null && finalMsg.startsWith('[')) {
      final endIdx = finalMsg.indexOf(']');
      if (endIdx > 1) {
        finalTag = finalMsg.substring(1, endIdx);
      }
    }

    LogLevel finalLevel = level;
    if (_config?.autoDetectErrorLevel == true &&
        (level == LogLevel.info || level == LogLevel.debug)) {
      if (finalMsg.toLowerCase().contains('error') ||
          finalMsg.toLowerCase().contains('exception') ||
          finalMsg.toLowerCase().contains('fail')) {
        finalLevel = LogLevel.error;
      } else if (finalMsg.toLowerCase().contains('warn')) {
        finalLevel = LogLevel.warning;
      }
    }

    final entry = SuperLogEntry(
      message: finalMsg,
      timestamp: DateTime.now(),
      level: finalLevel,
      tag: finalTag,
      error: error,
      stackTrace: stackTrace,
    );

    _pendingLogs.add(entry);
    _scheduleBatchAdd();
  }

  void _scheduleBatchAdd() {
    _batchTimer?.cancel();
    _batchTimer = Timer(const Duration(milliseconds: 16), () {
      if (_pendingLogs.isEmpty) return;

      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (_pendingLogs.isEmpty) return;

        if (_config?.logRetentionDuration != null &&
            _logs.isNotEmpty &&
            _logs.length % 100 == 0) {
          final cutoffTime = DateTime.now().subtract(
            _config!.logRetentionDuration!,
          );
          _logs.removeWhere((log) => log.timestamp.isBefore(cutoffTime));
        }

        _logs.addAll(_pendingLogs);
        _pendingLogs.clear();

        if (_logs.length > maxLogs) {
          final removeCount = _logs.length - maxLogs;
          _logs.removeRange(0, removeCount);
        }

        _cachedFilteredLogs = null;
        _cachedSearchQuery = null;
        _cachedLevelFilter = null;
        _cachedLogsLength = null;

        notifyListeners();
      });
    });
  }

  List<SuperLogEntry> get filteredLogs {
    final effectiveLevelFilter = _levelFilter ?? _config?.defaultLogLevelFilter;

    final logsLength = _logs.length;
    final isCacheValid =
        _cachedFilteredLogs != null &&
        _cachedSearchQuery == _searchQuery &&
        _cachedLevelFilter == effectiveLevelFilter &&
        _cachedLogsLength == logsLength;

    if (isCacheValid) {
      return _cachedFilteredLogs!;
    }

    if (_searchQuery.isEmpty && effectiveLevelFilter == null) {
      final result = _logs.reversed.toList();
      _cachedFilteredLogs = result;
      _cachedSearchQuery = _searchQuery;
      _cachedLevelFilter = effectiveLevelFilter;
      _cachedLogsLength = logsLength;
      return result;
    }

    final normalizedQuery = _searchQuery.toLowerCase();

    final result = <SuperLogEntry>[];
    for (int i = _logs.length - 1; i >= 0; i--) {
      final log = _logs[i];

      if (effectiveLevelFilter != null && log.level != effectiveLevelFilter) {
        continue;
      }

      if (normalizedQuery.isNotEmpty) {
        if (!log.matchesFilter(_searchQuery)) {
          continue;
        }
      }

      result.add(log);
    }

    _cachedFilteredLogs = result;
    _cachedSearchQuery = _searchQuery;
    _cachedLevelFilter = effectiveLevelFilter;
    _cachedLogsLength = logsLength;

    return result;
  }

  void setSearchQuery(String query) {
    if (_searchQuery != query) {
      _searchQuery = query;
      _cachedFilteredLogs = null;
      _cachedSearchQuery = null;
      notifyListeners();
    }
  }

  void setLevelFilter(LogLevel? level) {
    if (_levelFilter != level) {
      _levelFilter = level;
      _cachedFilteredLogs = null;
      _cachedLevelFilter = null;
      notifyListeners();
    }
  }

  void clearLogs() {
    _logs.clear();
    _pendingLogs.clear();
    _cachedFilteredLogs = null;
    _cachedSearchQuery = null;
    _cachedLevelFilter = null;
    _cachedLogsLength = null;
    notifyListeners();
  }

  int _cachedErrorCount = 0;
  int? _cachedErrorCountLogsLength;

  int get errorCount {
    final logsLength = _logs.length;
    if (_cachedErrorCountLogsLength == logsLength) {
      return _cachedErrorCount;
    }

    _cachedErrorCount = _logs
        .where((log) => log.level == LogLevel.error)
        .length;
    _cachedErrorCountLogsLength = logsLength;
    return _cachedErrorCount;
  }

  @override
  void dispose() {
    _batchTimer?.cancel();
    _batchTimer = null;
    _pendingLogs.clear();
    _cachedFilteredLogs = null;
    super.dispose();
  }

  void deleteLog(SuperLogEntry log) {
    _logs.remove(log);
    _cachedFilteredLogs = null;
    _cachedErrorCountLogsLength = null;
    notifyListeners();
  }

  void deleteLogs(List<SuperLogEntry> logsToRemove) {
    _logs.removeWhere((log) => logsToRemove.contains(log));
    _cachedFilteredLogs = null;
    _cachedErrorCountLogsLength = null;
    notifyListeners();
  }

  static void reset() {
    _instance?.dispose();
    _instance = null;
    _config = null;
  }
}
