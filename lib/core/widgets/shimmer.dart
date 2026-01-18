import 'package:flutter/material.dart';

/// A shimmer loading effect widget.
///
/// Creates an animated gradient that moves across the child widget,
/// creating a loading placeholder effect.
class Shimmer extends StatefulWidget {
  const Shimmer({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
    this.duration = const Duration(milliseconds: 1500),
  });

  /// The widget to apply the shimmer effect to.
  final Widget child;

  /// Base color of the shimmer (default: grey).
  final Color? baseColor;

  /// Highlight color of the shimmer (default: lighter grey).
  final Color? highlightColor;

  /// Duration of one shimmer animation cycle.
  final Duration duration;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();

    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final baseColor = widget.baseColor ??
        (brightness == Brightness.dark
            ? const Color(0xFF2A2A2A)
            : const Color(0xFFE0E0E0));
    final highlightColor = widget.highlightColor ??
        (brightness == Brightness.dark
            ? const Color(0xFF3D3D3D)
            : const Color(0xFFF5F5F5));

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: const [0.0, 0.5, 1.0],
              transform: _SlidingGradientTransform(_animation.value),
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform(this.slidePercent);

  final double slidePercent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0.0, 0.0);
  }
}

/// A pre-styled shimmer placeholder box.
///
/// Use this for creating skeleton loading states.
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final color = brightness == Brightness.dark
        ? const Color(0xFF2A2A2A)
        : const Color(0xFFE0E0E0);

    return Shimmer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// A shimmer placeholder for text lines.
class ShimmerText extends StatelessWidget {
  const ShimmerText({
    super.key,
    this.width = double.infinity,
    this.height = 16.0,
    this.borderRadius = 4.0,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ShimmerBox(
      width: width,
      height: height,
      borderRadius: borderRadius,
    );
  }
}

/// A shimmer placeholder for circular elements (avatars, icons).
class ShimmerCircle extends StatelessWidget {
  const ShimmerCircle({
    super.key,
    required this.size,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final color = brightness == Brightness.dark
        ? const Color(0xFF2A2A2A)
        : const Color(0xFFE0E0E0);

    return Shimmer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
