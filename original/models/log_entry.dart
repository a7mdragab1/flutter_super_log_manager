enum LogLevel { info, warning, error, debug }

/// Optimized log entry with cached lowercase strings for filtering
class SuperLogEntry {
  final String message;
  final DateTime timestamp;
  final LogLevel level;
  final String? tag;
  final Object? error;
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

  /// Efficient filter matching using pre-computed lowercase strings
  bool matchesFilter(String query) {
    if (query.isEmpty) return true;
    final lowerQuery = query.toLowerCase();
    return _lowerMessage.contains(lowerQuery) ||
        (_lowerTag?.contains(lowerQuery) ?? false) ||
        _lowerLevelName.contains(lowerQuery);
  }
}
