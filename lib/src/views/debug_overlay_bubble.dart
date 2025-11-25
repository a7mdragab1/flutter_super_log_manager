import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/super_log_manager.dart';
import '../models/log_config.dart';

/// Draggable debug overlay bubble widget implemented as an OverlayEntry.
class SuperDebugOverlayBubble extends StatefulWidget {
  final VoidCallback onShowLogScreen;
  final Function(String) onShowMessage;

  const SuperDebugOverlayBubble({
    super.key,
    required this.onShowLogScreen,
    required this.onShowMessage,
  });

  /// Creates an [OverlayEntry] for the debug bubble.
  ///
  /// [key] is required to identify the widget.
  /// [onShowLogScreen] is the callback when the bubble is tapped.
  static OverlayEntry createOverlayEntry({
    required GlobalKey key,
    required VoidCallback onShowLogScreen,
    required Function(String) onShowMessage,
  }) {
    return OverlayEntry(
      builder: (context) => SuperDebugOverlayBubble(
        key: key,
        onShowLogScreen: onShowLogScreen,
        onShowMessage: onShowMessage,
      ),
    );
  }

  @override
  State<SuperDebugOverlayBubble> createState() =>
      _SuperDebugOverlayBubbleState();
}

class _SuperDebugOverlayBubbleState extends State<SuperDebugOverlayBubble> {
  late SuperLogManager _logManager;
  late SuperLogConfig _config;
  late ValueNotifier<Offset> _position;
  late ValueNotifier<int> _errorCount;
  late Size _screenSize;
  bool _isDragging = false;
  Offset _dragStartPosition = Offset.zero;
  TextDirection _textDirection = TextDirection.ltr;

  @override
  void initState() {
    super.initState();
    _logManager = SuperLogManager.instance;
    _config = SuperLogManager.config ?? const SuperLogConfig();
    _errorCount = ValueNotifier<int>(_logManager.errorCount);
    _logManager.addListener(_updateErrorCount);

    _position = ValueNotifier<Offset>(Offset.zero);
    _screenSize = Size.zero;

    // Initialize position after the first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializePosition();
    });
  }

  void _initializePosition() {
    if (!mounted) return;
    final mediaQuery = MediaQuery.of(context);
    _screenSize = mediaQuery.size;
    _textDirection = Directionality.of(context);

    final bubbleRadius = _config.bubbleSize / 2;
    final cornerPosition = _config.initialBubblePosition;

    // Calculate center position based on initial offset
    final centerX = cornerPosition.dx + bubbleRadius;
    final centerY = cornerPosition.dy + bubbleRadius;

    _position.value = Offset(centerX, centerY);
  }

  void _updateErrorCount() {
    final count = _logManager.errorCount;
    if (_errorCount.value != count) {
      _errorCount.value = count;
    }
  }

  void _onPanStart(DragStartDetails details) {
    _isDragging = false;
    _dragStartPosition = details.globalPosition;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDragging &&
        (_dragStartPosition - details.globalPosition).distance > 5) {
      _isDragging = true;
    }

    if (_isDragging) {
      final newPosition = _position.value + details.delta;
      final bubbleRadius = _config.bubbleSize / 2;
      final constrainedX = newPosition.dx.clamp(
        bubbleRadius,
        _screenSize.width - bubbleRadius,
      );
      final constrainedY = newPosition.dy.clamp(
        bubbleRadius,
        _screenSize.height - bubbleRadius,
      );
      _position.value = Offset(constrainedX, constrainedY);
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isDragging) {
      _snapToEdge();
    }
    _isDragging = false;
  }

  void _snapToEdge() {
    final screenWidth = _screenSize.width;
    final bubbleRadius = _config.bubbleSize / 2;
    final currentX = _position.value.dx;

    final distanceToLeft = currentX - bubbleRadius;
    final distanceToRight = screenWidth - currentX - bubbleRadius;

    final newX = _textDirection == TextDirection.rtl
        ? (distanceToRight < distanceToLeft
              ? screenWidth - bubbleRadius - 16
              : bubbleRadius + 16)
        : (distanceToLeft < distanceToRight
              ? bubbleRadius + 16
              : screenWidth - bubbleRadius - 16);

    _position.value = Offset(newX, _position.value.dy);
  }

  void _onTap() {
    if (_isDragging) return; // Ignore tap if dragging
    widget.onShowLogScreen();
  }

  Future<void> _onLongPress() async {
    if (_isDragging) return;
    if (!_config.enableLongBubbleClickExport) return;

    final logs = _logManager.logs;
    if (logs.isEmpty) return;

    try {
      final text = logs
          .map(
            (l) =>
                '${l.timestamp} - ${l.level.name.toUpperCase()}: ${l.message}',
          )
          .join('\n\n');

      await Clipboard.setData(ClipboardData(text: text));

      if (mounted) {
        showSnackBar(context, 'Logs exported to clipboard');
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, 'Failed to export logs: $e');
      }
    }
  }

  void showSnackBar(BuildContext context, String message) {
    widget.onShowMessage(message);
  }

  @override
  void dispose() {
    _logManager.removeListener(_updateErrorCount);
    _position.dispose();
    _errorCount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = _config; // Use local var to avoid repeated access

    return ValueListenableBuilder<Offset>(
      valueListenable: _position,
      builder: (context, position, child) {
        final bubbleRadius = config.bubbleSize / 2;
        return Positioned(
          left: position.dx - bubbleRadius,
          top: position.dy - bubbleRadius,
          child: IgnorePointer(
            ignoring: false, // Ensure the bubble is interactive
            child: GestureDetector(
              onPanStart: config.enableBubbleDrag ? _onPanStart : null,
              onPanUpdate: config.enableBubbleDrag ? _onPanUpdate : null,
              onPanEnd: config.enableBubbleDrag ? _onPanEnd : null,
              onTap: _onTap,
              onLongPress: _onLongPress,
              child: Material(
                color: Colors.transparent,
                elevation: 8,
                shape: const CircleBorder(),
                child: Container(
                  width: config.bubbleSize,
                  height: config.bubbleSize,
                  decoration: BoxDecoration(
                    color: config.bubbleColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(51),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(Icons.bug_report, color: config.bubbleIconColor),
                      // Error count badge
                      ValueListenableBuilder<int>(
                        valueListenable: _errorCount,
                        builder: (context, count, child) {
                          if (count == 0) return const SizedBox();
                          return Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: config.errorBadgeColor,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 18,
                                minHeight: 18,
                              ),
                              child: Text(
                                count > 99 ? '99+' : count.toString(),
                                style: TextStyle(
                                  color: config.errorBadgeTextColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
