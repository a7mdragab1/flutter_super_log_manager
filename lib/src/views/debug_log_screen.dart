import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/super_log_manager.dart';
import '../models/log_config.dart';
import '../models/log_entry.dart';
import 'log_item_view.dart';

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
  late final ValueNotifier<double> _fontSize;
  final ValueNotifier<Set<SuperLogEntry>> _selectedLogs =
      ValueNotifier<Set<SuperLogEntry>>(<SuperLogEntry>{});
  final ValueNotifier<bool> _isSelectionMode = ValueNotifier<bool>(false);
  final ScrollController _scrollController = ScrollController();
  late bool _autoScroll;
  int _lastLogCount = 0;

  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _logManager = SuperLogManager.instance;
    _fontSize = ValueNotifier<double>(_logManager.fontSize);
    _autoScroll = _logManager.autoScroll;

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
      final count = _selectedLogs.value.length;
      _logManager.deleteLogs(_selectedLogs.value.toList());
      _clearSelection();
      if (mounted) _showSnackbar(context, '$count logs deleted');
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

  Future<void> _clearAllLogs() async {
    final confirmed = await _showDeleteConfirmationDialog(
      context,
      'Clear all logs?',
      'This will delete all logs. This action cannot be undone.',
    );
    if (confirmed == true) {
      _logManager.clearLogs();
      if (!mounted) return;
      _showSnackbar(context, 'All logs cleared');
    }
  }

  Future<void> _deleteSingleLog(SuperLogEntry log) async {
    final confirmed = await _showDeleteConfirmationDialog(
      context,
      'Delete this log?',
      'This action cannot be undone.',
    );
    if (confirmed == true) {
      _logManager.deleteLog(log);
      if (!mounted) return;
      _showSnackbar(context, 'Log deleted');
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
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = SuperLogManager.config ?? const SuperLogConfig();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Determine screen height fraction for the panel
    final screenHeight = MediaQuery.of(context).size.height;
    final panelHeight = screenHeight * config.panelHeightFraction;

    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        backgroundColor: Colors
            .transparent, // Make background transparent for overlay effect
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
                          _buildSettingsBar(context, theme, isDark),
                          _buildFilterBar(context, theme, isDark),
                          Expanded(
                            child: _buildLogList(context, theme, isDark),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
              if (config?.enableLogDeletion ?? true)
                IconButton(
                  icon: const Icon(Icons.delete_sweep),
                  onPressed: _clearAllLogs,
                  tooltip: 'Clear All',
                ),
            ],
          );
        },
      ),
    ];
  }

  Widget _buildSettingsBar(BuildContext context, ThemeData theme, bool isDark) {
    final textColor =
        theme.appBarTheme.titleTextStyle?.color ?? theme.colorScheme.onSurface;
    final iconColor =
        theme.appBarTheme.iconTheme?.color ?? theme.colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Auto-scroll Checkbox
          Row(
            children: [
              SizedBox(
                height: 24,
                width: 24,
                child: Checkbox(
                  value: _autoScroll,
                  onChanged: (value) {
                    setState(() {
                      _autoScroll = value ?? false;
                      _logManager.setAutoScroll(_autoScroll);
                    });
                  },
                  fillColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return theme.colorScheme.primary;
                    }
                    return null;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Auto-scroll',
                style: TextStyle(color: textColor, fontSize: 14),
              ),
            ],
          ),
          // Font Size Selector
          Row(
            children: [
              Icon(Icons.text_fields, size: 20, color: iconColor),
              const SizedBox(width: 8),
              ValueListenableBuilder<double>(
                valueListenable: _fontSize,
                builder: (context, fontSize, child) {
                  return DropdownButton<double>(
                    dropdownColor: theme.colorScheme.surface,
                    value: fontSize,
                    isDense: true,
                    style: TextStyle(color: textColor),
                    underline: Container(),
                    items:
                        [
                              DropdownMenuItem(value: 12.0, child: Text('12')),
                              DropdownMenuItem(value: 13.0, child: Text('13')),
                              DropdownMenuItem(value: 14.0, child: Text('14')),
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
                      if (val != null) {
                        _fontSize.value = val;
                        _logManager.setFontSize(val);
                      }
                    },
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
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

        if (_autoScroll && logsLength > _lastLogCount) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
        }
        _lastLogCount = logsLength;

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
              return LogItemView(
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
                onDelete: () => _deleteSingleLog(log),
                index: logsLength - index,
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
