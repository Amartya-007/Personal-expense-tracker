import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import 'app_card.dart';

/// A softly pulsing placeholder block used while data loads, instead of a
/// bare spinner that makes the layout jump when content arrives.
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
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.45, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          color: p.surface2,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
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
