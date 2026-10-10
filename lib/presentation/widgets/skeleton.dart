import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import 'app_card.dart';

/// A placeholder block with a soft light sweep, shown while data loads. It
/// keeps the layout stable (no jump when content arrives) and the moving
/// highlight tells the user something is happening. With "reduce motion" on it
/// stays still.
class Skeleton extends StatefulWidget {
  final double height;
  final double? width;
  final double radius;

  const Skeleton({super.key, this.height = 16, this.width, this.radius = 10});

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final base = p.surface2;
    final highlight = Color.lerp(base, Colors.white, p.isDark ? 0.07 : 0.7)!;
    final still = MediaQuery.of(context).disableAnimations;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(
            colors: [base, highlight, base],
            stops: const [0.3, 0.5, 0.7],
            transform: _SlideGradient(still ? 0 : _controller.value * 2 - 1),
          ),
        ),
      ),
    );
  }
}

/// Slides a gradient horizontally by a fraction of its width (-1 .. 1).
class _SlideGradient extends GradientTransform {
  final double slide;

  const _SlideGradient(this.slide);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * slide, 0, 0);
}

/// A card-shaped loading placeholder with a few text-line skeletons.
class SkeletonCard extends StatelessWidget {
  final double height;

  const SkeletonCard({super.key, this.height = 110});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      shadow: false,
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        height: height - 32,
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Skeleton(height: 14, width: 140),
            SizedBox(height: 12),
            Skeleton(height: 12),
            SizedBox(height: 8),
            Skeleton(height: 12, width: 220),
          ],
        ),
      ),
    );
  }
}
