import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart' as flutter;
import '../models/log_entry.dart';
import '../models/log_config.dart';
import '../views/debug_wrapper.dart';
import '../views/default_error_widget.dart';

/// The main class for managing logs and the debug overlay.
///
/// Use [SuperLogManager.runApp] to initialize your application with the logger.
/// You can also use [SuperLogManager.init] for manual initialization if needed.
class SuperLogManager extends ChangeNotifier {
  static SuperLogManager? _instance;
  static SuperLogConfig? _config;
  static bool _isCapturingPrint = false;
  static bool _isInDebugPrint = false;
  static ZoneSpecification? _printZoneSpecification;
  static final flutter.GlobalKey<flutter.NavigatorState> navigatorKey =
      flutter.GlobalKey<flutter.NavigatorState>(
        debugLabel: 'SuperLogManagerNavigator',
      );

  /// Manually initializes the [SuperLogManager] singleton.
  ///
  /// [config] - Optional configuration. If not provided, default configuration is used.
  /// Returns the initialized instance.
  static SuperLogManager init({SuperLogConfig? config}) {
    _config = config ?? const SuperLogConfig();
    if (!_config!.enabled) {
      return _instance ??= SuperLogManager._disabled();
    }
    _instance ??= SuperLogManager._();
    return _instance!;
  }

  /// Checks if the [SuperLogManager] is initialized and enabled.
  static bool get isInitialized =>
      _instance != null && _config?.enabled != false;

  /// Returns the current configuration.
  ///
  /// Returns `null` if the manager hasn't been initialized.
  static SuperLogConfig? get config => _config;

  /// Returns the singleton instance of [SuperLogManager].
  ///
  /// If the manager is disabled via config, it returns a disabled instance that does nothing.
  /// If not initialized, it initializes with default configuration.
  static SuperLogManager get instance {
    if (_config?.enabled == false) {
      return _instance ??= SuperLogManager._disabled();
    }
    _instance ??= SuperLogManager._();
    return _instance!;
  }

  /// Initializes the app with [SuperLogManager] enabled.
  ///
  /// This is the recommended way to start your application. It sets up error handling,
  /// print capturing, and the debug overlay.
  ///
  /// [app] - The root widget of your application.
  /// [config] - Configuration for the logger.
  /// [errorWidget] - Custom error widget builder for synchronous errors during startup.
  /// [preRun] - Async callback to run before [runApp]. Return `false` to abort startup.
  /// [postRun] - Callback to run after the app has started.
  static void runApp(
    flutter.Widget app, {
    SuperLogConfig? config,
    flutter.Widget Function(Object error)? errorWidget,
    FutureOr<bool> Function()? preRun,
    VoidCallback? postRun,
  }) {
    final finalConfig = config ?? const SuperLogConfig();
    final finalErrorWidget =
        errorWidget ?? ((error) => SuperDefaultErrorWidget(error));

    // Initialize LogManager if enabled
    if (finalConfig.enabled) {
      init(config: finalConfig);
    }

    // Hook print and debugPrint BEFORE creating the zone
    // This ensures _printZoneSpecification is ready for runZonedGuarded
    if (finalConfig.enabled &&
        (finalConfig.capturePrint || finalConfig.captureDebugPrint)) {
      _hookDebugPrint(finalConfig);
    }

    // Use runZonedGuarded to capture all errors and prints in the zone
    runZonedGuarded(
      () async {
        // Initialize bindings INSIDE the zone to avoid Zone Mismatch errors
        flutter.WidgetsFlutterBinding.ensureInitialized();

        // Set up Flutter error handlers inside the zone
        if (finalConfig.enabled) {
          _setupFlutterErrorHandlers(finalConfig, finalErrorWidget);
        }

        try {
          // Run preRun hook
          if (preRun != null) {
            final preRunResult = await preRun();
            if (preRunResult == false) {
              return;
            }
          }

          flutter.runApp(
            finalConfig.enabled && finalConfig.showOverlayBubble
                ? SuperDebugWrapper(child: app)
                : app,
          );

          if (postRun != null) {
            SchedulerBinding.instance.addPostFrameCallback((_) {
              Future.microtask(() async {
                try {
                  postRun();
                } catch (e) {
                  if (isInitialized) {
                    try {
                      instance.addLog(
                        'Error in postRun: $e',
                        level: LogLevel.error,
                        error: e,
                      );
                    } catch (_) {}
                  }
                }
              });
            });
          }
        } catch (e, s) {
          // Catch synchronous errors during startup
          if (finalConfig.enabled && isInitialized) {
            try {
              instance.addLog(
                'Error in runApp startup: $e',
                level: LogLevel.error,
                error: e,
                stackTrace: s,
              );
            } catch (_) {}
          }
          flutter.runApp(finalErrorWidget(e));
        }
      },
      (error, stack) {
        // Handle uncaught async errors
        if (isInitialized) {
          try {
            instance.addLog(
              error.toString(),
              level: LogLevel.error,
              error: error,
              stackTrace: stack,
            );
          } catch (_) {}
        }
      },
      zoneSpecification: finalConfig.capturePrint
          ? _printZoneSpecification
          : null,
    );
  }

  /// Set up error handlers for Flutter errors and Dart errors
  static void _setupFlutterErrorHandlers(
    SuperLogConfig config,
    flutter.Widget Function(Object error) errorWidget,
  ) {
    // Handle Flutter framework errors
    flutter.FlutterError.onError = (flutter.FlutterErrorDetails details) {
      if (isInitialized) {
        try {
          instance.addLog(
            details.exceptionAsString(),
            level: LogLevel.error,
            error: details.exception,
            stackTrace: details.stack,
          );
        } catch (_) {}
      }
    };

    // Handle Dart errors
    PlatformDispatcher.instance.onError = (error, stack) {
      if (isInitialized) {
        try {
          instance.addLog(
            error.toString(),
            level: LogLevel.error,
            error: error,
            stackTrace: stack,
          );
        } catch (_) {}
      }
      return false; // Do not exit
    };
  }

  static void _hookDebugPrint(SuperLogConfig config) {
    // Hook debugPrint if enabled
    if (config.captureDebugPrint) {
      final originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        bool captured = false;
        if (!_isInDebugPrint && !_isCapturingPrint && isInitialized) {
          _isInDebugPrint = true;
          try {
            instance.addLog(message ?? '', level: LogLevel.debug);
            captured = true;
          } catch (_) {
          } finally {
            _isInDebugPrint = false;
          }
        }
        if (!captured || _config?.mirrorLogsToConsole != true) {
          originalDebugPrint(message, wrapWidth: wrapWidth);
        }
      };
    }

    // Hook print() if enabled
    if (config.capturePrint) {
      _printZoneSpecification = ZoneSpecification(
        print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
          bool captured = false;
          if (!_isCapturingPrint && !_isInDebugPrint && isInitialized) {
            _isCapturingPrint = true;
            try {
              instance.addLog(line, level: LogLevel.info);
              captured = true;
            } catch (_) {
            } finally {
              _isCapturingPrint = false;
            }
          }
          if (!captured || _config?.mirrorLogsToConsole != true) {
            parent.print(zone, line);
          }
        },
      );
    }
  }

  SuperLogManager._() {
    _initialize();
  }

  SuperLogManager._disabled() {
    _logs = <SuperLogEntry>[];
    _pendingLogs = <SuperLogEntry>[];
  }

  late final List<SuperLogEntry> _logs;
  late final List<SuperLogEntry> _pendingLogs;
  Timer? _batchTimer;

  /// Returns an unmodifiable list of all captured logs.
  List<SuperLogEntry> get logs => List.unmodifiable(_logs);

  void _initialize() {
    _logs = <SuperLogEntry>[];
    _pendingLogs = <SuperLogEntry>[];
  }

  /// Adds a new log entry.
  ///
  /// [message] - The log message.
  /// [level] - The severity level of the log (default: [LogLevel.info]).
  /// [tag] - Optional tag to categorize the log.
  /// [error] - Optional error object associated with the log.
  /// [stackTrace] - Optional stack trace associated with the log.
  void addLog(
    String message, {
    LogLevel level = LogLevel.info,
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    var finalLevel = level;
    // Auto-detect error level if enabled
    if (_config?.autoDetectErrorLevel == true &&
        finalLevel == LogLevel.info &&
        error == null) {
      final lowerMsg = message.toLowerCase();
      if (lowerMsg.contains('error') ||
          lowerMsg.contains('exception') ||
          lowerMsg.contains('fail') ||
          lowerMsg.contains('fatal')) {
        finalLevel = LogLevel.error;
      }
    }

    final log = SuperLogEntry(
      message: message,
      level: finalLevel,
      tag: tag,
      timestamp: DateTime.now(),
      error: error,
      stackTrace: stackTrace,
    );

    if (_config?.mirrorLogsToConsole == true) {
      _printLogToConsole(log);
    }

    _pendingLogs.add(log);

    // Use a timer to batch updates and avoid excessive UI rebuilds
    if (_batchTimer?.isActive ?? false) {
      _batchTimer!.cancel();
    }
    _batchTimer = Timer(const Duration(milliseconds: 16), () {
      _processPendingLogs();
    });
  }

  void _processPendingLogs() {
    if (_pendingLogs.isEmpty) return;
    _logs.addAll(_pendingLogs);
    _pendingLogs.clear();

    // Enforce max log limit
    if (_logs.length > (_config?.maxLogs ?? 1000)) {
      _logs.removeRange(0, _logs.length - (_config?.maxLogs ?? 1000));
    }

    // Invalidate caches
    _cachedFilteredLogs = null;
    _cachedSearchQuery = null;
    _cachedLevelFilter = null;
    _cachedLogsLength = null;

    notifyListeners(); // Notify UI listeners
  }

  void _printLogToConsole(SuperLogEntry log) {
    final buffer = StringBuffer('[SuperLog]');
    buffer.write(' ${log.level.name.toUpperCase()}');
    if (log.tag != null && log.tag!.isNotEmpty) {
      buffer.write(' [${log.tag}]');
    }
    buffer.write(' ${log.message}');
    if (log.error != null) {
      buffer.write(' | error: ${log.error}');
    }
    if (log.stackTrace != null) {
      buffer.write('\n${log.stackTrace}');
    }

    _isInDebugPrint = true;
    try {
      debugPrintSynchronously(buffer.toString());
    } finally {
      _isInDebugPrint = false;
    }
  }

  // Caching for filtered logs
  List<SuperLogEntry>? _cachedFilteredLogs;
  String? _cachedSearchQuery;
  LogLevel? _cachedLevelFilter;
  int? _cachedLogsLength;

  /// Returns the list of logs filtered by [searchQuery] and [levelFilter].
  ///
  /// The result is cached for performance.
  List<SuperLogEntry> get filteredLogs {
    final logsLength = _logs.length;
    if (_cachedFilteredLogs != null &&
        _cachedLogsLength == logsLength &&
        _cachedSearchQuery == _searchQuery &&
        _cachedLevelFilter == _levelFilter) {
      return _cachedFilteredLogs!;
    }

    List<SuperLogEntry> filtered = _logs;

    if (_levelFilter != null) {
      filtered = filtered.where((log) => log.level == _levelFilter).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final lowerQuery = _searchQuery.toLowerCase();
      filtered = filtered
          .where((log) => log.matchesLowerQuery(lowerQuery))
          .toList();
    }

    _cachedFilteredLogs = filtered;
    _cachedLogsLength = logsLength;
    _cachedSearchQuery = _searchQuery;
    _cachedLevelFilter = _levelFilter;
    return filtered;
  }

  String _searchQuery = '';
  LogLevel? _levelFilter;

  /// The current search query used for filtering logs.
  String get searchQuery => _searchQuery;

  /// The current log level filter.
  LogLevel? get levelFilter => _levelFilter;

  /// Sets the search query for filtering logs.
  void setSearchQuery(String query) {
    if (_searchQuery != query) {
      _searchQuery = query;
      _cachedFilteredLogs = null; // Invalidate cache
      notifyListeners();
    }
  }

  /// Sets the log level filter.
  void setLevelFilter(LogLevel? level) {
    if (_levelFilter != level) {
      _levelFilter = level;
      _cachedFilteredLogs = null; // Invalidate cache
      notifyListeners();
    }
  }

  /// Clears all captured logs.
  void clearLogs() {
    _logs.clear();
    _pendingLogs.clear();
    _cachedFilteredLogs = null;
    _cachedSearchQuery = null;
    _cachedLevelFilter = null;
    _cachedLogsLength = null;
    notifyListeners();
  }

  // Caching for error count
  int _cachedErrorCount = 0;
  int? _cachedErrorCountLogsLength;

  /// Returns the total count of logs with [LogLevel.error].
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

  /// Deletes a specific log entry.
  void deleteLog(SuperLogEntry log) {
    _logs.remove(log);
    _cachedFilteredLogs = null;
    _cachedErrorCountLogsLength = null; // Error count might change
    notifyListeners();
  }

  /// Deletes a list of log entries.
  void deleteLogs(List<SuperLogEntry> logsToRemove) {
    _logs.removeWhere((log) => logsToRemove.contains(log));
    _cachedFilteredLogs = null;
    _cachedErrorCountLogsLength = null; // Error count might change
    notifyListeners();
  }

  /// Resets the singleton instance and configuration.
  ///
  /// Useful for testing or restarting the logger.
  static void reset() {
    _instance = null;
    _config = null;
  }
}
