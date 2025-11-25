// Log Item Widget
import 'package:flutter/material.dart';

import '../controllers/super_log_manager.dart';
import '../models/log_entry.dart';

class LogItemView extends StatefulWidget {
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
  final int index;

  const LogItemView({
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
    required this.index,
  });

  @override
  State<LogItemView> createState() => _LogItemViewState();
}

class _LogItemViewState extends State<LogItemView> {
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
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          margin: const EdgeInsets.only(
                                            right: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _tagColor,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            '#${widget.index}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: _textColor,
                                              fontFamily: 'Courier',
                                            ),
                                          ),
                                        ),
                                        Text(
                                          _formatTimestamp(
                                            widget.log.timestamp,
                                          ),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: widget.isDark
                                                ? Colors.grey.shade300
                                                : Colors.grey.shade800,
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
                                                size: 20,
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
                                                size: 20,
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
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    // final y = timestamp.year.toString();
    final mo = months[timestamp.month - 1];
    final d = timestamp.day.toString().padLeft(2, '0');
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    return '$d-$mo $h:$m:$s';
  }
}
