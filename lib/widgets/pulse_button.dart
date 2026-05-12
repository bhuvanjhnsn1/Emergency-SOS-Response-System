import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// Animated pulsing SOS button with concentric ripple rings
class PulseButton extends StatefulWidget {
  final bool isActive;
  final bool isTriggered;
  final VoidCallback onPressed;

  const PulseButton({
    super.key,
    required this.isActive,
    required this.isTriggered,
    required this.onPressed,
  });

  @override
  State<PulseButton> createState() => _PulseButtonState();
}

class _PulseButtonState extends State<PulseButton>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rippleController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.isActive || widget.isTriggered) {
      _pulseController.repeat(reverse: true);
      _rippleController.repeat();
    }
  }

  @override
  void didUpdateWidget(PulseButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive || widget.isTriggered) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
        _rippleController.repeat();
      }
    } else {
      _pulseController.stop();
      _pulseController.reset();
      _rippleController.stop();
      _rippleController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor =
        widget.isTriggered ? AppColors.accentRed : AppColors.accentBlue;

    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ripple rings
          if (widget.isActive || widget.isTriggered)
            ...List.generate(3, (index) {
              return AnimatedBuilder(
                animation: _rippleController,
                builder: (context, child) {
                  final delay = index * 0.3;
                  final progress =
                      ((_rippleController.value + delay) % 1.0).clamp(0.0, 1.0);
                  final scale = 1.0 + progress * 0.6;
                  final opacity = (1.0 - progress) * 0.3;

                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: baseColor.withValues(alpha: opacity),
                          width: 2,
                        ),
                      ),
                    ),
                  );
                },
              );
            }),

          // Outer glow
          Container(
            width: 170,
            height: 170,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: baseColor.withValues(
                    alpha: widget.isActive || widget.isTriggered ? 0.3 : 0.1,
                  ),
                  blurRadius: 40,
                  spreadRadius: 5,
                ),
              ],
            ),
          ),

          // Main button
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: widget.isActive || widget.isTriggered
                    ? _pulseAnimation.value
                    : 1.0,
                child: child,
              );
            },
            child: GestureDetector(
              onTap: widget.onPressed,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: widget.isTriggered
                      ? AppColors.dangerGradient
                      : widget.isActive
                          ? AppColors.safeGradient
                          : const LinearGradient(
                              colors: [
                                AppColors.surfaceLight,
                                AppColors.surface,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                  boxShadow: [
                    BoxShadow(
                      color: baseColor.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.isTriggered
                          ? Icons.warning_rounded
                          : widget.isActive
                              ? Icons.shield_rounded
                              : Icons.power_settings_new_rounded,
                      color: widget.isActive || widget.isTriggered
                          ? Colors.white
                          : AppColors.textMuted,
                      size: 48,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.isTriggered
                          ? 'SOS ACTIVE'
                          : widget.isActive
                              ? 'GUARDING'
                              : 'START',
                      style: TextStyle(
                        color: widget.isActive || widget.isTriggered
                            ? Colors.white
                            : AppColors.textMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Replacement for deprecated AnimatedBuilder — just uses AnimatedBuilder from Flutter
/// Actually AnimatedBuilder is the correct widget. Let's keep using it.
