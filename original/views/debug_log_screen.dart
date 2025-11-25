import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../super_log_manager.dart';
import '../models/log_entry.dart';

/// Debug log screen using pure Flutter state management
/// Uses LogManager.instance directly (singleton pattern)
class SuperDebugLogScreen extends StatefulWidget {
  const SuperDebugLogScreen({super.key});

  @override
  State<SuperDebugLogScreen> createState() => _SuperDebugLogScreenState();
}

class _SuperDebugLogScreenState extends State<SuperDebugLogScreen> {
  late final SuperLogManager _logManager;
  final ValueNotifier<double> _fontSize = ValueNotifier<double>(16.0);
  final ValueNotifier<Set<SuperLogEntry>> _selectedLogs =
      ValueNotifier<Set<SuperLogEntry>>(<SuperLogEntry>{});
  final ValueNotifier<bool> _isSelectionMode = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _logManager = SuperLogManager.instance;
  }

  // Cache dropdown items to avoid rebuilding
  static const List<DropdownMenuItem<double>> _fontSizeItems = [
    DropdownMenuItem(value: 15.0, child: Text('15')),
    DropdownMenuItem(value: 16.0, child: Text('16')),
    DropdownMenuItem(value: 17.0, child: Text('17')),
    DropdownMenuItem(value: 18.0, child: Text('18')),
    DropdownMenuItem(value: 19.0, child: Text('19')),
    DropdownMenuItem(value: 20.0, child: Text('20')),
  ];

  @override
  void dispose() {
    _fontSize.dispose();
    _selectedLogs.dispose();
    _isSelectionMode.dispose();
    super.dispose();
  }

  void _toggleSelection(SuperLogEntry log) {
    final current = Set<SuperLogEntry>.from(_selectedLogs.value);
    if (current.contains(log)) {
      current.remove(log);
      if (current.isEmpty) {
        _isSelectionMode.value = false;
      }
    } else {
      current.add(log);
      _isSelectionMode.value = true;
    }
    _selectedLogs.value = current;
  }

  void _selectAll() {
    final allLogs = _logManager.filteredLogs;
    _selectedLogs.value = Set<SuperLogEntry>.from(allLogs);
    _isSelectionMode.value = true;
  }

  void _clearSelection() {
    _selectedLogs.value = <SuperLogEntry>{};
    _isSelectionMode.value = false;
  }

  Future<void> _deleteSelected() async {
    if (_selectedLogs.value.isEmpty) return;

    final confirmed = await _showDeleteConfirmationDialog(
      context,
      'Delete ${_selectedLogs.value.length} selected log(s)?',
      'This action cannot be undone.',
    );

    if (confirmed == true) {
      _logManager.deleteLogs(_selectedLogs.value.toList());
      _clearSelection();
    }
  }

  Future<bool?> _showDeleteConfirmationDialog(
    BuildContext context,
    String title,
    String content,
  ) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearAllLogs(BuildContext context) async {
    final confirmed = await _showDeleteConfirmationDialog(
      context,
      'Clear all logs?',
      'This will delete all logs. This action cannot be undone.',
    );

    if (confirmed == true) {
      _logManager.clearLogs();
    }
  }

  Future<void> _deleteSingleLog(BuildContext context, SuperLogEntry log) async {
    final confirmed = await _showDeleteConfirmationDialog(
      context,
      'Delete this log?',
      'This action cannot be undone.',
    );

    if (confirmed == true) {
      _logManager.deleteLog(log);
    }
  }

  void _copySelected(BuildContext context) {
    if (_selectedLogs.value.isEmpty) return;
    final text = _selectedLogs.value
        .map((l) => '${l.timestamp} ${l.message}')
        .join('\n\n');
    Clipboard.setData(ClipboardData(text: text));
    final callbacks = SuperLogManager.navigationCallbacks;
    if (callbacks.onShowSnackbar != null) {
      callbacks.onShowSnackbar!(
        context,
        '${_selectedLogs.value.length} logs copied to clipboard',
      );
    } else {
      // Fallback to ScaffoldMessenger
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_selectedLogs.value.length} logs copied to clipboard',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
    _clearSelection();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: _buildAppBar(context, theme, isDark),
      body: Column(
        children: [
          _buildFilterBar(context, theme, isDark),
          Expanded(
            child: AnimatedBuilder(
              animation: _logManager,
              builder: (context, child) {
                final logs = _logManager.filteredLogs;
                final logsLength = logs.length;

                if (logsLength == 0) {
                  return Center(
                    child: Text(
                      'No logs found',
                      style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                    ),
                  );
                }

                return ListView.separated(
                  key: const PageStorageKey('debug_logs_list'),
                  itemCount: logsLength,
                  cacheExtent: 500, // Cache 500px worth of items
                  // Performance optimizations
                  addAutomaticKeepAlives:
                      false, // Don't keep items alive when off-screen
                  addRepaintBoundaries:
                      true, // Add repaint boundaries for better performance
                  addSemanticIndexes:
                      false, // Disable semantic indexes for better performance
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    thickness: 0.5,
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                  ),
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    return _LogItem(
                      key: ValueKey(
                        '${log.timestamp.millisecondsSinceEpoch}_${log.message.hashCode}',
                      ),
                      log: log,
                      fontSize: _fontSize,
                      selectedLogs: _selectedLogs,
                      isSelectionMode: _isSelectionMode,
                      isDark: isDark,
                      theme: theme,
                      onTap: () {
                        if (_isSelectionMode.value) {
                          _toggleSelection(log);
                        }
                      },
                      onLongPress: () => _toggleSelection(log),
                      onCopy: () {
                        final text = '${log.timestamp} ${log.message}';
                        Clipboard.setData(ClipboardData(text: text));
                        final callbacks = SuperLogManager.navigationCallbacks;
                        if (callbacks.onShowSnackbar != null) {
                          callbacks.onShowSnackbar!(
                            context,
                            'Log entry copied',
                          );
                        } else {
                          // Fallback to ScaffoldMessenger
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Log entry copied'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      onDelete: () => _deleteSingleLog(context, log),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    ThemeData theme,
    bool isDark,
  ) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: ValueListenableBuilder<bool>(
        valueListenable: _isSelectionMode,
        builder: (context, isSelectionMode, child) {
          return ValueListenableBuilder<Set<SuperLogEntry>>(
            valueListenable: _selectedLogs,
            builder: (context, selectedLogs, child) {
              return AppBar(
                backgroundColor: isDark
                    ? theme.appBarTheme.backgroundColor ??
                          theme.colorScheme.surface
                    : theme.appBarTheme.backgroundColor ??
                          theme.colorScheme.surface,
                foregroundColor:
                    theme.appBarTheme.foregroundColor ??
                    theme.colorScheme.onSurface,
                title: isSelectionMode
                    ? Text('${selectedLogs.length} selected')
                    : const Text('Debug Logs'),
                leading: isSelectionMode
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: _clearSelection,
                        tooltip: 'Cancel Selection',
                      )
                    : IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () {
                          final callbacks = SuperLogManager.navigationCallbacks;
                          if (callbacks.onNavigateBack != null) {
                            callbacks.onNavigateBack!(context);
                          } else {
                            // Fallback to Navigator
                            Navigator.of(context).pop();
                          }
                        },
                      ),
                actions: _buildAppBarActions(context, theme, isDark),
              );
            },
          );
        },
      ),
    );
  }

  List<Widget> _buildAppBarActions(
    BuildContext context,
    ThemeData theme,
    bool isDark,
  ) {
    final iconColor =
        theme.appBarTheme.iconTheme?.color ?? theme.colorScheme.onSurface;
    final textColor =
        theme.appBarTheme.titleTextStyle?.color ?? theme.colorScheme.onSurface;

    return [
      ValueListenableBuilder<bool>(
        valueListenable: _isSelectionMode,
        builder: (context, isSelectionMode, child) {
          if (isSelectionMode) {
            return ValueListenableBuilder<Set<SuperLogEntry>>(
              valueListenable: _selectedLogs,
              builder: (context, selectedLogs, child) {
                final filteredCount = _logManager.filteredLogs.length;
                final selectedCount = selectedLogs.length;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (selectedCount < filteredCount)
                      IconButton(
                        icon: const Icon(Icons.select_all),
                        onPressed: _selectAll,
                        tooltip: 'Select All',
                      ),
                    if (selectedCount > 0) ...[
                      IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () => _copySelected(context),
                        tooltip: 'Copy Selected',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: _deleteSelected,
                        tooltip: 'Delete Selected',
                      ),
                    ],
                  ],
                );
              },
            );
          }

          // Default Mode Actions
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Font Size Selector
              ValueListenableBuilder<double>(
                valueListenable: _fontSize,
                builder: (context, fontSize, child) {
                  return DropdownButton<double>(
                    dropdownColor: isDark
                        ? theme.colorScheme.surface
                        : theme.colorScheme.surface,
                    value: fontSize,
                    style: TextStyle(color: textColor),
                    icon: Icon(Icons.text_fields, color: iconColor),
                    underline: Container(),
                    items: _fontSizeItems
                        .map(
                          (item) => DropdownMenuItem<double>(
                            value: item.value,
                            child: Text(
                              item.value.toString(),
                              style: TextStyle(color: textColor),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) _fontSize.value = val;
                    },
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_sweep),
                onPressed: () => _clearAllLogs(context),
                tooltip: 'Clear All',
              ),
            ],
          );
        },
      ),
    ];
  }

  Widget _buildFilterBar(BuildContext context, ThemeData theme, bool isDark) {
    final surfaceColor = isDark
        ? theme.colorScheme.surface
        : theme.colorScheme.surface;
    final onSurfaceColor = theme.colorScheme.onSurface;
    final hintColor = theme.hintColor;

    return Container(
      color: isDark
          ? theme.colorScheme.surfaceContainerHighest
          : theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: AnimatedBuilder(
              animation: _logManager,
              builder: (context, child) {
                return TextField(
                  style: TextStyle(color: onSurfaceColor),
                  decoration: InputDecoration(
                    hintText: 'Search logs...',
                    hintStyle: TextStyle(color: hintColor),
                    prefixIcon: Icon(Icons.search, color: hintColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: surfaceColor,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 0,
                    ),
                  ),
                  onChanged: (val) => _logManager.setSearchQuery(val),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: AnimatedBuilder(
              animation: _logManager,
              builder: (context, child) {
                return DropdownButtonHideUnderline(
                  child: DropdownButton<LogLevel?>(
                    value: _logManager.levelFilter,
                    hint: Text('Level', style: TextStyle(color: hintColor)),
                    icon: Icon(Icons.filter_list, color: onSurfaceColor),
                    dropdownColor: isDark
                        ? theme.colorScheme.surface
                        : theme.colorScheme.surface,
                    style: TextStyle(color: onSurfaceColor),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(
                          'All',
                          style: TextStyle(color: onSurfaceColor),
                        ),
                      ),
                      ...LogLevel.values.map(
                        (l) => DropdownMenuItem(
                          value: l,
                          child: _buildLevelBadge(l, theme, isDark),
                        ),
                      ),
                    ],
                    onChanged: (val) => _logManager.setLevelFilter(val),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelBadge(LogLevel level, ThemeData theme, bool isDark) {
    final color = _getLevelColor(level, isDark);
    return Text(
      level.name.toUpperCase(),
      style: TextStyle(color: color, fontWeight: FontWeight.bold),
    );
  }

  Color _getLevelColor(LogLevel level, bool isDark) {
    switch (level) {
      case LogLevel.error:
        return isDark ? Colors.red.shade400 : Colors.red.shade700;
      case LogLevel.warning:
        return isDark ? Colors.orange.shade400 : Colors.orange.shade700;
      case LogLevel.debug:
        return isDark ? Colors.blue.shade400 : Colors.blue.shade700;
      case LogLevel.info:
        return isDark ? Colors.green.shade400 : Colors.green.shade700;
    }
  }
}

class _LogItem extends StatefulWidget {
  final SuperLogEntry log;
  final ValueNotifier<double> fontSize;
  final ValueNotifier<Set<SuperLogEntry>> selectedLogs;
  final ValueNotifier<bool> isSelectionMode;
  final bool isDark;
  final ThemeData theme;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onCopy;
  final VoidCallback onDelete;

  const _LogItem({
    super.key,
    required this.log,
    required this.fontSize,
    required this.selectedLogs,
    required this.isSelectionMode,
    required this.isDark,
    required this.theme,
    required this.onTap,
    required this.onLongPress,
    required this.onCopy,
    required this.onDelete,
  });

  @override
  State<_LogItem> createState() => _LogItemState();
}

class _LogItemState extends State<_LogItem> {
  bool _expanded = false;
  late final Color _textColor;
  late final Color _tagColor;

  @override
  void initState() {
    super.initState();
    _textColor = _getTextColorForLevel(widget.log.level, widget.isDark);
    _tagColor = _getTagColorForLevel(widget.log.level, widget.isDark);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.isSelectionMode,
      builder: (context, isSelectionMode, child) {
        return ValueListenableBuilder<Set<SuperLogEntry>>(
          valueListenable: widget.selectedLogs,
          builder: (context, selectedLogs, child) {
            return ValueListenableBuilder<double>(
              valueListenable: widget.fontSize,
              builder: (context, currentFontSize, child) {
                final isSelected = selectedLogs.contains(widget.log);

                final bgColor = isSelected
                    ? (widget.isDark
                          ? Colors.blue.shade900.withValues(alpha: 0.3)
                          : Colors.blue.shade100)
                    : _getBackgroundColorForLevel(
                        widget.log.level,
                        widget.isDark,
                        widget.theme,
                      );

                return Directionality(
                  textDirection: TextDirection.ltr,
                  child: Container(
                    color: bgColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: InkWell(
                      onTap: widget.onTap,
                      onLongPress: widget.onLongPress,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Selection Checkbox (visible in selection mode)
                          if (isSelectionMode)
                            Padding(
                              padding: const EdgeInsets.only(right: 12, top: 4),
                              child: Icon(
                                isSelected
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                color: isSelected
                                    ? (widget.isDark
                                          ? Colors.blue.shade300
                                          : Colors.blue.shade700)
                                    : (widget.isDark
                                          ? Colors.grey.shade600
                                          : Colors.grey.shade400),
                                size: 20,
                              ),
                            ),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      _formatTimestamp(widget.log.timestamp),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: widget.isDark
                                            ? Colors.grey.shade400
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (widget.log.tag != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _tagColor,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          widget.log.tag!,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: _textColor,
                                          ),
                                        ),
                                      ),

                                    // Individual Action Buttons (only if NOT in selection mode)
                                    if (!isSelectionMode) ...[
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: widget.onCopy,
                                        child: Icon(
                                          Icons.copy,
                                          size: 16,
                                          color: widget.isDark
                                              ? Colors.grey.shade400
                                              : Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: widget.onDelete,
                                        child: Icon(
                                          Icons.delete_outline,
                                          size: 16,
                                          color: widget.isDark
                                              ? Colors.grey.shade400
                                              : Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                _buildMessage(_textColor, currentFontSize),
                                if (widget.log.error != null) ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: widget.isDark
                                          ? Colors.red.shade900.withValues(
                                              alpha: 0.3,
                                            )
                                          : Colors.red.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      widget.log.error.toString(),
                                      style: TextStyle(
                                        color: widget.isDark
                                            ? Colors.red.shade300
                                            : Colors.red.shade900,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMessage(Color textColor, double fontSize) {
    const int maxLinesCollapsed = 3;
    final textStyle = TextStyle(
      color: textColor,
      fontFamily: 'Courier',
      fontSize: fontSize,
      height: 1.2,
    );

    final message = widget.log.message;
    final isShort = message.length < 150 && message.split('\n').length < 3;

    // If message is short, just show it
    if (isShort) {
      return Text(message, style: textStyle);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message,
          style: textStyle,
          maxLines: _expanded ? null : maxLinesCollapsed,
          overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
        ),
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              _expanded ? 'Show less' : 'Show more',
              style: TextStyle(
                color: widget.isDark
                    ? Colors.blue.shade300
                    : Colors.blue.shade700,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    final ms = timestamp.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  Color _getBackgroundColorForLevel(
    LogLevel level,
    bool isDark,
    ThemeData theme,
  ) {
    if (isDark) {
      switch (level) {
        case LogLevel.error:
          return Colors.red.shade900.withValues(alpha: 0.2);
        case LogLevel.warning:
          return Colors.orange.shade900.withValues(alpha: 0.2);
        case LogLevel.debug:
          return Colors.blue.shade900.withValues(alpha: 0.2);
        case LogLevel.info:
          return theme.colorScheme.surface;
      }
    } else {
      switch (level) {
        case LogLevel.error:
          return Colors.red.shade50;
        case LogLevel.warning:
          return Colors.orange.shade50;
        case LogLevel.debug:
          return Colors.blue.shade50;
        case LogLevel.info:
          return Colors.white;
      }
    }
  }

  Color _getTextColorForLevel(LogLevel level, bool isDark) {
    if (isDark) {
      switch (level) {
        case LogLevel.error:
          return Colors.red.shade300;
        case LogLevel.warning:
          return Colors.orange.shade300;
        case LogLevel.debug:
          return Colors.blue.shade300;
        case LogLevel.info:
          return Colors.grey.shade300;
      }
    } else {
      switch (level) {
        case LogLevel.error:
          return Colors.red.shade900;
        case LogLevel.warning:
          return Colors.orange.shade900;
        case LogLevel.debug:
          return Colors.blue.shade900;
        case LogLevel.info:
          return Colors.grey.shade800;
      }
    }
  }

  Color _getTagColorForLevel(LogLevel level, bool isDark) {
    if (isDark) {
      switch (level) {
        case LogLevel.error:
          return Colors.red.shade800.withValues(alpha: 0.4);
        case LogLevel.warning:
          return Colors.orange.shade800.withValues(alpha: 0.4);
        case LogLevel.debug:
          return Colors.blue.shade800.withValues(alpha: 0.4);
        case LogLevel.info:
          return Colors.grey.shade700;
      }
    } else {
      switch (level) {
        case LogLevel.error:
          return Colors.red.shade200;
        case LogLevel.warning:
          return Colors.orange.shade200;
        case LogLevel.debug:
          return Colors.blue.shade200;
        case LogLevel.info:
          return Colors.grey.shade300;
      }
    }
  }
}
