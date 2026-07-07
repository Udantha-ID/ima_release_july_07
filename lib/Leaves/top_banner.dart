import 'dart:async';
import 'package:flutter/material.dart';

class TopBanner {
  static OverlayEntry? _entry;
  static Timer? _timer;

  static void show(
    BuildContext context, {
    required String title,
    required String message,
    IconData? icon,
    String? leftButtonText,
    String rightButtonText = "OK",
    VoidCallback? onLeftTap,
    VoidCallback? onRightTap,
    bool isSuccess = false,
    bool isError = false,
    Duration duration = const Duration(seconds: 4),
  }) {
    hide();

    final overlay = Overlay.of(context);

    _entry = OverlayEntry(
      builder: (_) => _TopBannerWidget(
        title: title,
        message: message,
        icon: icon,
        leftButtonText: leftButtonText,
        rightButtonText: rightButtonText,
        isSuccess: isSuccess,
        isError: isError,
        duration: duration,
        onLeftTap: () {
          hide();
          onLeftTap?.call();
        },
        onRightTap: () {
          hide();
          onRightTap?.call();
        },
      ),
    );

    overlay.insert(_entry!);

    _timer = Timer(duration, hide);
  }

  static void hide() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }
}

class _TopBannerWidget extends StatefulWidget {
  final String title;
  final String message;
  final String? leftButtonText;
  final String rightButtonText;
  final VoidCallback? onLeftTap;
  final VoidCallback? onRightTap;
  final IconData? icon;
  final bool isSuccess;
  final bool isError;
  final Duration duration;

  const _TopBannerWidget({
    required this.title,
    required this.message,
    this.icon,
    required this.leftButtonText,
    required this.rightButtonText,
    this.onLeftTap,
    this.onRightTap,
    required this.isSuccess,
    required this.isError,
    required this.duration,
  });

  @override
  State<_TopBannerWidget> createState() => _TopBannerWidgetState();
}

class _TopBannerWidgetState extends State<_TopBannerWidget>
    with TickerProviderStateMixin {
  late final AnimationController _c;
  late final AnimationController _progress;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic),
    );
    _c.forward();

    _progress = AnimationController(vsync: this, duration: widget.duration)
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    _progress.dispose();
    super.dispose();
  }

  bool get _isSuccess =>
      widget.isSuccess || widget.icon == Icons.check_circle;

  bool get _isError =>
      widget.isError ||
      widget.icon == Icons.cancel ||
      widget.icon == Icons.error ||
      widget.icon == Icons.error_outline;

  List<Color> get _gradientColors {
    if (_isSuccess) {
      return const [Color(0xFF2E9E5B), Color(0xFF1B7A43)];
    }
    if (_isError) {
      return const [Color(0xFFE5484D), Color(0xFFB42318)];
    }
    return const [Color(0xFF2E7BF0), Color(0xFF0D47A1)];
  }

  void _dismiss() => TopBanner.hide();

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    const radius = 22.0;

    // Returning a bare Positioned (rather than a screen-filling Stack/Material)
    // keeps the hit-testable area limited to the card itself, so the rest of
    // the screen stays interactive while the banner is showing.
    return Positioned(
      top: topPad + 8,
      left: 14,
      right: 14,
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: ScaleTransition(
            scale: _scale,
            alignment: Alignment.topCenter,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragEnd: (details) {
                if ((details.primaryVelocity ?? 0) < -250) _dismiss();
              },
              child: Material(
                color: Colors.transparent,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 28,
                        spreadRadius: 0,
                        color: Colors.black.withValues(alpha: 0.24),
                        offset: const Offset(0, 14),
                      ),
                      BoxShadow(
                        blurRadius: 10,
                        color: _gradientColors.first.withValues(alpha: 0.35),
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(radius),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _gradientColors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.20),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (widget.icon != null) ...[
                                      Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.18),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white.withValues(alpha: 0.30),
                                          ),
                                        ),
                                        child: Icon(
                                          widget.icon,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                    ],
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            widget.title,
                                            style: const TextStyle(
                                              fontSize: 16.5,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                              letterSpacing: -0.2,
                                              height: 1.25,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            widget.message,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.white
                                                  .withValues(alpha: 0.92),
                                              height: 1.35,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: _dismiss,
                                        borderRadius: BorderRadius.circular(12),
                                        child: Padding(
                                          padding: const EdgeInsets.all(6),
                                          child: Icon(
                                            Icons.close_rounded,
                                            color: Colors.white.withValues(alpha: 0.85),
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (widget.leftButtonText != null) ...[
                                      _pillButton(
                                        text: widget.leftButtonText!,
                                        onTap: widget.onLeftTap,
                                        filled: false,
                                      ),
                                      const SizedBox(width: 10),
                                    ],
                                    _pillButton(
                                      text: widget.rightButtonText,
                                      onTap: widget.onRightTap,
                                      filled: true,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Slim auto-dismiss countdown bar
                          AnimatedBuilder(
                            animation: _progress,
                            builder: (_, _) => ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(radius),
                              ),
                              child: LinearProgressIndicator(
                                value: 1 - _progress.value,
                                minHeight: 3,
                                backgroundColor: Colors.white.withValues(alpha: 0.16),
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.white.withValues(alpha: 0.80),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pillButton({
    required String text,
    required VoidCallback? onTap,
    required bool filled,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          decoration: BoxDecoration(
            color: filled
                ? Colors.white.withValues(alpha: 0.32)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Colors.white.withValues(alpha: filled ? 0 : 0.45),
              width: 1.2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(
              text,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
