import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../super_log_manager.dart';
import 'debug_log_screen.dart';

/// Draggable debug overlay bubble widget
/// Uses pure Flutter with optimized performance techniques:
/// - GestureDetector for drag handling
/// - ValueNotifier for position updates (minimal rebuilds)
/// - Constrained position within screen bounds
/// - Overlay for debug screen (like messenger chat bubble)
///
/// [logManager] is optional - if not provided, uses LogManager.instance (singleton)
class SuperDebugOverlayBubble extends StatefulWidget {
  final SuperLogManager? logManager;
  final VoidCallback? onTap;
  final bool hideWhenScreenOpen;

  const SuperDebugOverlayBubble({
    super.key,
    this.logManager,
    this.onTap,
    this.hideWhenScreenOpen = true,
  });

  @override
  State<SuperDebugOverlayBubble> createState() =>
      _SuperDebugOverlayBubbleState();
}

class _SuperDebugOverlayBubbleState extends State<SuperDebugOverlayBubble> {
  late ValueNotifier<Offset> _position;
  final ValueNotifier<int> _errorCount = ValueNotifier<int>(0);
  final ValueNotifier<bool> _isOverlayOpen = ValueNotifier<bool>(false);

  Size _screenSize = Size.zero;
  bool _isDragging = false;
  Offset _dragStartPosition = Offset.zero;
  TextDirection _textDirection = TextDirection.ltr;

  late final SuperLogManager _logManager;
  late final SuperLogConfig _config;

  double get _bubbleSize => _config.bubbleSize;

  @override
  void initState() {
    super.initState();
    // Use provided logManager or fallback to singleton instance
    _logManager = widget.logManager ?? SuperLogManager.instance;
    // Get config
    _config = SuperLogManager.config ?? const SuperLogConfig();
    // Listen to log changes to update error count
    _logManager.addListener(_updateErrorCount);
    _updateErrorCount();
    // Initialize position - will be set based on config in first build
    _position = ValueNotifier<Offset>(Offset.zero);
  }

  @override
  void dispose() {
    // Don't call Get.back() in dispose - it can cause widget tree assertion errors
    // during navigation. Just reset the state - navigation will handle itself.
    _isOverlayOpen.value = false;
    _logManager.removeListener(_updateErrorCount);
    _position.dispose();
    _errorCount.dispose();
    _isOverlayOpen.dispose();
    super.dispose();
  }

  void _updateErrorCount() {
    // Use optimized errorCount getter instead of filtering all logs
    final count = _logManager.errorCount;
    if (_errorCount.value != count) {
      _errorCount.value = count;
    }
  }

  void _onPanStart(DragStartDetails details) {
    _isDragging = false;
    _dragStartPosition = details.globalPosition;
  }

  void _onPanUpdate(DragUpdateDetails details, Size screenSize) {
    // Only start dragging if movement exceeds a threshold
    if (!_isDragging &&
        (_dragStartPosition - details.globalPosition).distance > 5) {
      _isDragging = true;
    }

    if (_isDragging) {
      final newPosition = _position.value + details.delta;

      // Constrain position within screen bounds (using bubble radius)
      final bubbleRadius = _bubbleSize / 2;
      final constrainedX = newPosition.dx.clamp(
        bubbleRadius,
        screenSize.width - bubbleRadius,
      );
      final constrainedY = newPosition.dy.clamp(
        bubbleRadius,
        screenSize.height - bubbleRadius,
      );

      _position.value = Offset(constrainedX, constrainedY);
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isDragging) {
      // Snap to nearest horizontal edge
      _snapToEdge();
    }
    _isDragging = false;
  }

  void _snapToEdge() {
    final screenWidth = _screenSize.width;
    final bubbleRadius = _bubbleSize / 2;
    final currentX = _position.value.dx;

    // Determine which edge is closer
    final distanceToLeft = currentX - bubbleRadius;
    final distanceToRight = screenWidth - currentX - bubbleRadius;

    // Snap to edge based on text direction preference
    // RTL: prefer right edge, LTR: prefer left edge
    final newX = _textDirection == TextDirection.rtl
        ? (distanceToRight < distanceToLeft
              ? screenWidth -
                    bubbleRadius -
                    16 // Snap to right with padding
              : bubbleRadius + 16) // Snap to left with padding
        : (distanceToLeft < distanceToRight
              ? bubbleRadius +
                    16 // Snap to left with padding
              : screenWidth - bubbleRadius - 16); // Snap to right with padding

    _position.value = Offset(newX, _position.value.dy);
  }

  void _onTap() {
    if (_isDragging) return; // Ignore tap if we just finished dragging

    if (widget.onTap != null) {
      widget.onTap!();
    } else {
      if (_isOverlayOpen.value) {
        _closeOverlay();
      } else {
        _showOverlay();
      }
    }
  }

  void _onLongPress() {
    if (!mounted) return;

    // Copy all log messages to clipboard
    final allLogs = _logManager.logs;
    final logText = allLogs
        .map((log) {
          final timestamp = log.timestamp.toString().substring(0, 19);
          final level = log.level.name.toUpperCase();
          final tag = log.tag != null ? '[${log.tag}]' : '';
          return '[$timestamp] $level $tag ${log.message}';
        })
        .join('\n');

    Clipboard.setData(ClipboardData(text: logText));

    // Show feedback using navigation callbacks
    final callbacks = SuperLogManager.navigationCallbacks;
    if (callbacks.onShowSnackbar != null) {
      callbacks.onShowSnackbar!(
        context,
        'All log messages copied to clipboard',
      );
    } else if (mounted) {
      // Fallback to ScaffoldMessenger
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('All log messages copied to clipboard'),
          backgroundColor: Colors.green.withOpacity(0.9),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showOverlay() {
    if (_isOverlayOpen.value || !mounted) return;

    _isOverlayOpen.value = true;

    // Navigate to full screen debug log using navigation callbacks
    // Add retry logic for when app is starting
    void tryNavigate() {
      if (!mounted) return;

      final callbacks = SuperLogManager.navigationCallbacks;
      if (callbacks.onNavigateToDebugLog != null) {
        callbacks
            .onNavigateToDebugLog!(context, () => const SuperDebugLogScreen())
            .then((_) {
              // Screen was closed
              if (mounted) {
                _isOverlayOpen.value = false;
              }
            })
            .catchError((e) {
              // Navigation failed, retry after delay
              if (mounted && _isOverlayOpen.value) {
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (mounted && _isOverlayOpen.value) {
                    tryNavigate();
                  }
                });
              }
            });
      } else {
        // Fallback to default Navigator
        final navigator = Navigator.of(context, rootNavigator: true);
        navigator
            .push(
              MaterialPageRoute(
                builder: (_) => const SuperDebugLogScreen(),
                fullscreenDialog: true,
              ),
            )
            .then((_) {
              if (mounted) {
                _isOverlayOpen.value = false;
              }
            })
            .catchError((e) {
              if (mounted && _isOverlayOpen.value) {
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (mounted && _isOverlayOpen.value) {
                    tryNavigate();
                  }
                });
              }
            });
      }
    }

    // Wait for next frame to ensure context is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isOverlayOpen.value) {
        tryNavigate();
      }
    });
  }

  void _closeOverlay() {
    if (!_isOverlayOpen.value || !mounted) return;

    // Use navigation callbacks
    final callbacks = SuperLogManager.navigationCallbacks;
    if (callbacks.onNavigateBack != null) {
      callbacks.onNavigateBack!(context);
    } else {
      // Fallback to default Navigator
      final navigator = Navigator.of(context, rootNavigator: true);
      if (navigator.canPop()) {
        navigator.pop();
      }
    }
    _isOverlayOpen.value = false;
  }

  @override
  Widget build(BuildContext context) {
    // Check if debug screen is open (optional feature)
    if (_config.hideBubbleWhenScreenOpen || widget.hideWhenScreenOpen) {
      final route = ModalRoute.of(context);
      if (route?.settings.name?.toLowerCase().contains('debug') == true) {
        return const SizedBox.shrink();
      }
    }

    // Get screen size for constraints
    final screenSize = MediaQuery.of(context).size;
    _screenSize = screenSize;

    // Determine text direction: check locale first, then fallback to Directionality
    final locale = Localizations.maybeLocaleOf(context);
    final newTextDirection = locale != null
        ? (locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr)
        : Directionality.of(context);
    
    // Recalculate position if direction changed or position not initialized
    final needsRecalculation = _textDirection != newTextDirection || _position.value == Offset.zero;
    _textDirection = newTextDirection;

    // Initialize or recalculate position based on config
    if (needsRecalculation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final bubbleRadius = _bubbleSize / 2;
          final cornerPosition = _config.initialBubblePosition;

          // Calculate center position based on text direction:
          // - RTL: dx = distance from right edge (position on right)
          // - LTR: dx = distance from left edge (position on left)
          // - dy = distance from top edge (same for both)
          final centerX = _textDirection == TextDirection.rtl
              ? screenSize.width - cornerPosition.dx - bubbleRadius
              : cornerPosition.dx + bubbleRadius;
          final centerY = cornerPosition.dy + bubbleRadius;

          _position.value = Offset(centerX, centerY);
        }
      });
    }

    // Positioned must be a direct child of Stack (from DebugWrapper)
    return ValueListenableBuilder<bool>(
      valueListenable: _isOverlayOpen,
      builder: (context, isOverlayOpen, child) {
        // Hide bubble if overlay is open
        if (isOverlayOpen ||
            ((_config.hideBubbleWhenScreenOpen || widget.hideWhenScreenOpen) &&
                _isOverlayOpen.value)) {
          return const SizedBox.shrink();
        }
        return ValueListenableBuilder<Offset>(
          valueListenable: _position,
          builder: (context, position, child) {
            final bubbleRadius = _bubbleSize / 2;
            return Positioned(
              left: position.dx - bubbleRadius,
              top: position.dy - bubbleRadius,
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: GestureDetector(
                  onPanStart: _config.enableBubbleDrag ? _onPanStart : null,
                  onPanUpdate: _config.enableBubbleDrag
                      ? (details) => _onPanUpdate(details, screenSize)
                      : null,
                  onPanEnd: _config.enableBubbleDrag ? _onPanEnd : null,
                  onTap: _onTap,
                  onLongPress: _onLongPress,
                  child: Material(
                    color: Colors.transparent,
                    elevation: 8,
                    shape: const CircleBorder(),
                    child: Container(
                      width: _bubbleSize,
                      height: _bubbleSize,
                      decoration: BoxDecoration(
                        color: _config.bubbleColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.bug_report,
                            color: _config.bubbleIconColor,
                          ),
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
                                    color: _config.errorBadgeColor,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 18,
                                    minHeight: 18,
                                  ),
                                  child: Text(
                                    count > 99 ? '99+' : count.toString(),
                                    style: TextStyle(
                                      color: _config.errorBadgeTextColor,
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
      },
    );
  }
}
