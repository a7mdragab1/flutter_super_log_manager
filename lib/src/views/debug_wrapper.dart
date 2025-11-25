import 'package:flutter/material.dart';
import '../controllers/super_log_manager.dart';
import '../models/log_config.dart';
import 'debug_log_screen.dart';
import 'debug_overlay_bubble.dart';

/// Widget to wrap the entire app and provide the debug overlay.
class SuperDebugWrapper extends StatefulWidget {
  final Widget child;
  const SuperDebugWrapper({super.key, required this.child});

  @override
  State<SuperDebugWrapper> createState() => _SuperDebugWrapperState();
}

class _SuperDebugWrapperState extends State<SuperDebugWrapper> {
  bool _isLogVisible = false;

  void _showLogScreen() {
    if (!_isLogVisible) {
      setState(() => _isLogVisible = true);
    }
  }

  void _hideLogScreen() {
    if (_isLogVisible) {
      setState(() => _isLogVisible = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = SuperLogManager.config;
    if (!SuperLogManager.isInitialized || config?.showOverlayBubble != true) {
      return widget.child;
    }

    final textDirection = Directionality.maybeOf(context) ?? TextDirection.ltr;
    final effectiveConfig = config ?? const SuperLogConfig();
    final hideBubbleWhenScreenOpen = effectiveConfig.hideBubbleWhenScreenOpen;

    return Directionality(
      textDirection: textDirection,
      child: Stack(
        children: [
          widget.child,
          if (!_isLogVisible || !hideBubbleWhenScreenOpen)
            SuperDebugOverlayBubble(onShowLogScreen: _showLogScreen),
          if (_isLogVisible)
            _DebugLogOverlay(onClose: _hideLogScreen, config: effectiveConfig),
        ],
      ),
    );
  }
}

class _DebugLogOverlay extends StatefulWidget {
  final VoidCallback onClose;
  final SuperLogConfig config;

  const _DebugLogOverlay({required this.onClose, required this.config});

  @override
  State<_DebugLogOverlay> createState() => _DebugLogOverlayState();
}

class _DebugLogOverlayState extends State<_DebugLogOverlay> {
  static const double _minFraction = 0.35;
  static const double _maxFraction = 0.95;

  late double _currentFraction;

  @override
  void initState() {
    super.initState();
    _currentFraction = widget.config.panelHeightFraction.clamp(
      _minFraction,
      _maxFraction,
    );
  }

  void _handleDragUpdate(DragUpdateDetails details, double screenHeight) {
    final delta = (details.primaryDelta ?? 0) / screenHeight;
    if (delta == 0) return;
    setState(() {
      _currentFraction = (_currentFraction - delta).clamp(
        _minFraction,
        _maxFraction,
      );
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity > 800 && _currentFraction <= _minFraction + 0.05) {
      widget.onClose();
    }
  }

  void _handleDragStart(DragStartDetails details) {}

  void _handleDragCancel() {}

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final overlayColor = widget.config.dimOverlayBackground
        ? Colors.black.withAlpha(153)
        : Colors.transparent;
    final panelHeight = mediaQuery.size.height * _currentFraction;

    var theme = Theme.of(context);

    Widget panel = Align(
      alignment: Alignment.bottomCenter,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragStart: _handleDragStart,
        onVerticalDragUpdate: (details) =>
            _handleDragUpdate(details, mediaQuery.size.height),
        onVerticalDragEnd: _handleDragEnd,
        onVerticalDragCancel: _handleDragCancel,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          height: panelHeight,
          width: mediaQuery.size.width,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(51),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8, top: 4),
                child: Center(
                  child: Container(
                    width: 48,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  child: SuperDebugLogScreen(onClose: widget.onClose),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final overlayContent = Stack(
      children: [
        Positioned.fill(
          child: Material(
            color: overlayColor,
            child: SafeArea(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: widget.onClose,
                      behavior: HitTestBehavior.opaque,
                      child: const SizedBox.expand(),
                    ),
                  ),
                  panel,
                ],
              ),
            ),
          ),
        ),
      ],
    );

    return Localizations(
      locale: const Locale('en'),
      delegates: const [
        DefaultWidgetsLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
      ],
      child: Navigator(
        onGenerateRoute: (_) => PageRouteBuilder(
          opaque: false,
          barrierColor: Colors.transparent,
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (context, _, _) {
            return Overlay(
              initialEntries: [OverlayEntry(builder: (_) => overlayContent)],
            );
          },
        ),
      ),
    );
  }
}
