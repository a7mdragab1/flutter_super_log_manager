import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/super_log_manager.dart';
import '../models/log_config.dart';
import '../models/log_entry.dart';

/// Debug log screen implemented as an OverlayEntry.
class SuperDebugLogScreen extends StatefulWidget {
  final VoidCallback onClose;

  const SuperDebugLogScreen({super.key, required this.onClose});

  static OverlayEntry createOverlayEntry({required VoidCallback onClose}) {
    return OverlayEntry(
      builder: (context) => SuperDebugLogScreen(onClose: onClose),
    );
  }

  @override
  State<SuperDebugLogScreen> createState() => _SuperDebugLogScreenState();
}

class _SuperDebugLogScreenState extends State<SuperDebugLogScreen> {
  late final SuperLogManager _logManager;
  final ValueNotifier<double> _fontSize = ValueNotifier<double>(16.0);
  final ValueNotifier<Set<SuperLogEntry>> _selectedLogs =
      ValueNotifier<Set<SuperLogEntry>>(<SuperLogEntry>{});
  final ValueNotifier<bool> _isSelectionMode = ValueNotifier<bool>(false);
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _logManager = SuperLogManager.instance;
    // Apply default filter if configured
    final config = SuperLogManager.config;
    if (config?.defaultLogLevelFilter != null) {
      _logManager.setLevelFilter(config!.defaultLogLevelFilter);
    }
  }

  @override
  void dispose() {
    _fontSize.dispose();
    _selectedLogs.dispose();
    _isSelectionMode.dispose();

    _scrollController.dispose();
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
        .map(
          (l) => '${l.timestamp} - ${l.level.name.toUpperCase()}: ${l.message}',
        )
        .join('\n\n');
    Clipboard.setData(ClipboardData(text: text));
    _showSnackbar(
      context,
      '${_selectedLogs.value.length} logs copied to clipboard',
    );
    _clearSelection();
  }

  void _showSnackbar(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      // Fallback if ScaffoldMessenger is not available in the context
      debugPrint('Snackbar: $message');
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = SuperLogManager.config ?? const SuperLogConfig();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Determine screen height fraction for the panel
    final screenHeight = MediaQuery.of(context).size.height;
    final panelHeight = screenHeight * config.panelHeightFraction;

    return Scaffold(
      backgroundColor:
          Colors.transparent, // Make background transparent for overlay effect
      body: Stack(
        children: [
          // Dim background
          if (config.dimOverlayBackground)
            GestureDetector(
              onTap: widget.onClose, // Close on background tap
              child: Container(color: Colors.black.withValues(alpha: 0.6)),
            ),
          // Log panel
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: panelHeight,
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 5,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[700] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                  // Content
                  Expanded(
                    child: Column(
                      children: [
                        _buildAppBar(context, theme, isDark),
                        _buildFilterBar(context, theme, isDark),
                        Expanded(child: _buildLogList(context, theme, isDark)),
                      ],
                    ),
                  ),
                ],
              ),
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
                    : AnimatedBuilder(
                        animation: _logManager,
                        builder: (context, _) {
                          return Text(
                            'Debug Logs (${_logManager.filteredLogs.length})',
                          );
                        },
                      ),
                leading: IconButton(
                  icon: Icon(isSelectionMode ? Icons.close : Icons.arrow_back),
                  onPressed: isSelectionMode ? _clearSelection : widget.onClose,
                  tooltip: isSelectionMode ? 'Cancel Selection' : 'Close',
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
    final config = SuperLogManager.config;

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
                      if (config?.enableLogExport ?? true)
                        IconButton(
                          icon: const Icon(Icons.copy),
                          onPressed: () => _copySelected(context),
                          tooltip: 'Copy Selected',
                        ),
                      if (config?.enableLogDeletion ?? true)
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
                    dropdownColor: theme.colorScheme.surface,
                    value: fontSize,
                    style: TextStyle(color: textColor),
                    icon: Icon(Icons.text_fields, color: iconColor),
                    underline: Container(),
                    items:
                        [
                              DropdownMenuItem(value: 15.0, child: Text('15')),
                              DropdownMenuItem(value: 16.0, child: Text('16')),
                              DropdownMenuItem(value: 17.0, child: Text('17')),
                              DropdownMenuItem(value: 18.0, child: Text('18')),
                              DropdownMenuItem(value: 19.0, child: Text('19')),
                              DropdownMenuItem(value: 20.0, child: Text('20')),
                            ]
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
              if (config?.enableLogDeletion ?? true)
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
    final config = SuperLogManager.config;
    final enableSearch = config?.enableLogSearch ?? true;
    final enableFilter = config?.enableLogFiltering ?? true;

    if (!enableSearch && !enableFilter) {
      return const SizedBox.shrink();
    }

    final surfaceColor = theme.colorScheme.surface;
    final onSurfaceColor = theme.colorScheme.onSurface;
    final hintColor = theme.hintColor;

    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          if (enableSearch)
            Expanded(
              child: TextField(
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
              ),
            ),
          if (enableSearch && enableFilter) const SizedBox(width: 8),
          if (enableFilter)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<LogLevel?>(
                  value: _logManager.levelFilter,
                  hint: Text('Level', style: TextStyle(color: hintColor)),
                  icon: Icon(Icons.filter_list, color: onSurfaceColor),
                  dropdownColor: theme.colorScheme.surface,
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
                        child: Text(
                          l.name.toUpperCase(),
                          style: TextStyle(
                            color: _getLevelColor(l, isDark),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                  onChanged: (val) => _logManager.setLevelFilter(val),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLogList(BuildContext context, ThemeData theme, bool isDark) {
    return AnimatedBuilder(
      animation: _logManager,
      builder: (context, child) {
        final logs = _logManager.filteredLogs;
        final logsLength = logs.length;

        if (logsLength == 0) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline, size: 64, color: theme.hintColor),
                const SizedBox(height: 16),
                Text(
                  'No logs found',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
              ],
            ),
          );
        }

        return Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          child: ListView.separated(
            key: const PageStorageKey('debug_logs_list'),
            itemCount: logsLength,
            cacheExtent: 500,
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: true,
            addSemanticIndexes: false,
            controller: _scrollController,
            separatorBuilder: (_, _) => Divider(
              height: 1,
              thickness: 0.5,
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
            ),
            itemBuilder: (context, index) {
              // Access logs in reverse order without creating a new list
              final log = logs[logsLength - 1 - index];
              return _LogItemView(
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
                  final text =
                      '${log.timestamp} - ${log.level.name.toUpperCase()}: ${log.message}';
                  Clipboard.setData(ClipboardData(text: text));
                  _showSnackbar(context, 'Log entry copied');
                },
                onDelete: () => _deleteSingleLog(context, log),
              );
            },
          ),
        );
      },
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

// Log Item Widget
class _LogItemView extends StatefulWidget {
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

  const _LogItemView({
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
  State<_LogItemView> createState() => _LogItemViewState();
}

class _LogItemViewState extends State<_LogItemView> {
  bool _expanded = false;
  late final Color _textColor;
  late final Color _tagColor;
  late final Color _levelColor;

  @override
  void initState() {
    super.initState();
    _textColor = _getTextColorForLevel(widget.log.level, widget.isDark);
    _tagColor = _getTagColorForLevel(widget.log.level, widget.isDark);
    _levelColor = _getLevelColor(widget.log.level, widget.isDark);
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
          return Colors.red.shade800.withAlpha(102);
        case LogLevel.warning:
          return Colors.orange.shade800.withAlpha(102);
        case LogLevel.debug:
          return Colors.blue.shade800.withAlpha(102);
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

  Color _getCardBackgroundColor(bool isSelected, bool isDark, ThemeData theme) {
    if (isSelected) {
      return isDark ? Colors.blue.shade900.withAlpha(77) : Colors.blue.shade50;
    }
    return isDark ? const Color(0xFF1E1E1E) : Colors.white;
  }

  void _handleTap(bool isSelectionMode) {
    if (isSelectionMode) {
      widget.onTap();
    } else {
      // Toggle expand if not in selection mode
      setState(() {
        _expanded = !_expanded;
      });
    }
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
                final bgColor = _getCardBackgroundColor(
                  isSelected,
                  widget.isDark,
                  widget.theme,
                );

                return Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(13),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _handleTap(isSelectionMode),
                      onLongPress: widget.onLongPress,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(color: _levelColor, width: 4),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        if (isSelectionMode)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              right: 8,
                                            ),
                                            child: Icon(
                                              isSelected
                                                  ? Icons.check_circle
                                                  : Icons
                                                        .radio_button_unchecked,
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
                                        Text(
                                          _formatTimestamp(
                                            widget.log.timestamp,
                                          ),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: widget.isDark
                                                ? Colors.grey.shade500
                                                : Colors.grey.shade600,
                                            fontFamily: 'Courier',
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
                                              borderRadius:
                                                  BorderRadius.circular(4),
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
                                        if (!isSelectionMode) ...[
                                          const SizedBox(width: 8),
                                          if (SuperLogManager
                                                  .config
                                                  ?.enableLogExport ??
                                              true) ...[
                                            GestureDetector(
                                              onTap: widget.onCopy,
                                              child: Icon(
                                                Icons.copy,
                                                size: 16,
                                                color: widget.isDark
                                                    ? Colors.grey.shade600
                                                    : Colors.grey.shade400,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                          ],
                                          if (SuperLogManager
                                                  .config
                                                  ?.enableLogDeletion ??
                                              true)
                                            GestureDetector(
                                              onTap: widget.onDelete,
                                              child: Icon(
                                                Icons.delete_outline,
                                                size: 16,
                                                color: widget.isDark
                                                    ? Colors.grey.shade600
                                                    : Colors.grey.shade400,
                                              ),
                                            ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    _buildMessage(_textColor, currentFontSize),
                                    if (widget.log.error != null) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: widget.isDark
                                              ? Colors.red.shade900.withAlpha(
                                                  51,
                                                )
                                              : Colors.red.shade50,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          border: Border.all(
                                            color: widget.isDark
                                                ? Colors.red.shade900.withAlpha(
                                                    128,
                                                  )
                                                : Colors.red.shade100,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Error:',
                                              style: TextStyle(
                                                color: widget.isDark
                                                    ? Colors.red.shade300
                                                    : Colors.red.shade800,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              widget.log.error.toString(),
                                              style: TextStyle(
                                                color: widget.isDark
                                                    ? Colors.red.shade200
                                                    : Colors.red.shade900,
                                                fontSize: 12,
                                                fontFamily: 'Courier',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
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
      fontFamily: 'Courier', // Monospace for logs
      fontSize: fontSize,
      height: 1.3,
    );

    final message = widget.log.message;
    final isShort = message.length < 150 && message.split('\n').length < 3;

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
        if (!_expanded)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              'Show more...',
              style: TextStyle(
                color: widget.isDark
                    ? Colors.blue.shade300.withAlpha(179)
                    : Colors.blue.shade700.withAlpha(179),
                fontSize: 11,
                fontStyle: FontStyle.italic,
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
}
