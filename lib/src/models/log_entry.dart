/// Log severity levels.
enum LogLevel {
  /// General information and successful operations.
  info,

  /// Warnings that don't break functionality but should be noted.
  warning,

  /// Errors and exceptions that might cause issues.
  error,

  /// Debug information for development purposes.
  debug,
}

/// A single log entry captured by [SuperLogManager].
///
/// Contains the message, timestamp, level, and optional error details.
/// It also caches lowercase strings for efficient filtering.
class SuperLogEntry {
  /// The main log message.
  final String message;

  /// The time when the log was created.
  final DateTime timestamp;

  /// The severity level of the log.
  final LogLevel level;

  /// Optional tag to categorize the log (e.g., "AUTH", "NETWORK").
  final String? tag;

  /// Optional error object (e.g., Exception or Error).
  final Object? error;

  /// Optional stack trace associated with the error.
  final StackTrace? stackTrace;

  // Cache lowercase strings for efficient filtering
  late final String _lowerMessage;
  late final String? _lowerTag;
  late final String _lowerLevelName;

  SuperLogEntry({
    required this.message,
    required this.timestamp,
    this.level = LogLevel.info,
    this.tag,
    this.error,
    this.stackTrace,
  }) {
    // Pre-compute lowercase strings once
    _lowerMessage = message.toLowerCase();
    _lowerTag = tag?.toLowerCase();
    _lowerLevelName = level.name.toLowerCase();
  }

  /// Efficient filter matching using pre-computed lowercase strings.
  ///
  /// [query] is the search query. It will be lowercased inside this method.
  /// For better performance in loops, use [matchesLowerQuery] with a pre-lowercased query.
  bool matchesFilter(String query) {
    if (query.isEmpty) return true;
    return matchesLowerQuery(query.toLowerCase());
  }

  /// Efficient filter matching using a pre-lowercased query.
  ///
  /// [lowerQuery] must be already lowercased.
  bool matchesLowerQuery(String lowerQuery) {
    if (lowerQuery.isEmpty) return true;
    return _lowerMessage.contains(lowerQuery) ||
        (_lowerTag?.contains(lowerQuery) ?? false) ||
        _lowerLevelName.contains(lowerQuery);
  }
}
