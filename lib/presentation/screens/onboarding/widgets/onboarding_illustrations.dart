import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_text.dart';
import '../../../widgets/pressable.dart';

/// Animated recreations of the onboarding mockup's five SVG illustrations
/// (`logo`, `sms`, `rcp`, `bud`, `done`) plus the confetti burst and the
/// biometric fingerprint target, rendered in MyKhata's teal design system.
///
/// All art is built from Flutter primitives (no SVG package, no new
/// dependency). Every animation is gated on
/// `MediaQuery.of(context).disableAnimations`: when reduce-motion is on each
/// controller is pinned to its STATIC END-STATE and never driven, so the final
/// frame renders instantly. Controllers are disposed in `dispose()`. These are
/// pure view widgets — no business logic lives in the painters.

/// The fixed logical canvas the mockup draws into (`viewBox="0 0 300 220"`).
const Size _kArtSize = Size(300, 220);

/// Scales the art down to fit the available width while preserving the mockup's
/// aspect ratio, matching the mockup's `max-width:300px` art box.
class _ArtBox extends StatelessWidget {
  final double height;
  final Widget child;

  const _ArtBox({required this.height, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Center(
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: _kArtSize.width,
            height: _kArtSize.height,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// The two stacked background discs shared by every illustration
/// (`--s2` r92, `--ln` @0.6 r62).
class _ArtBackdrop extends StatelessWidget {
  const _ArtBackdrop();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return CustomPaint(
      size: _kArtSize,
      painter: _BackdropPainter(disc: p.surface2, inner: p.border),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  final Color disc;
  final Color inner;

  _BackdropPainter({required this.disc, required this.inner});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = disc;
    canvas.drawCircle(const Offset(150, 115), 92, paint);
    paint.color = inner.withValues(alpha: 0.6);
    canvas.drawCircle(const Offset(150, 115), 62, paint);
  }

  @override
  bool shouldRepaint(_BackdropPainter old) =>
      old.disc != disc || old.inner != inner;
}

// ---------------------------------------------------------------------------
// 0 · Logo — floating gradient card + orbiting coin group.
// ---------------------------------------------------------------------------

class OnbLogoArt extends StatefulWidget {
  final double height;

  const OnbLogoArt({super.key, this.height = 270});

  @override
  State<OnbLogoArt> createState() => _OnbLogoArtState();
}

class _OnbLogoArtState extends State<OnbLogoArt> with TickerProviderStateMixin {
  late final AnimationController _orbit = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  );
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );
  bool _wired = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_wired) return;
    _wired = true;
    if (MediaQuery.of(context).disableAnimations) {
      _orbit.value = 0;
      _float.value = 0;
    } else {
      _orbit.repeat();
      _float.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _orbit.dispose();
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return _ArtBox(
      height: widget.height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const _ArtBackdrop(),
          // Orbiting group of coins/dots around the card centre (150, 120).
          AnimatedBuilder(
            animation: _orbit,
            builder: (context, child) => Transform.rotate(
              angle: _orbit.value * 2 * math.pi,
              origin: const Offset(0, 120 - 110),
              child: child,
            ),
            child: CustomPaint(
              size: _kArtSize,
              painter: _OrbPainter(
                coin: p.secondary,
                coinInk: AppColors.darkFabText,
                dotA: p.primary,
                dotB: p.income,
              ),
            ),
          ),
          // Floating gradient logo card.
          AnimatedBuilder(
            animation: _float,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, -9 * math.sin(_float.value * math.pi)),
              child: child,
            ),
            child: CustomPaint(
              size: _kArtSize,
              painter: _LogoCardPainter(
                gradient: p.heroGradient,
                ring: p.secondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  final Color coin;
  final Color coinInk;
  final Color dotA;
  final Color dotB;

  _OrbPainter({
    required this.coin,
    required this.coinInk,
    required this.dotA,
    required this.dotB,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    // Gold ₹ coin at top.
    paint.color = coin;
    canvas.drawCircle(const Offset(150, 22), 13, paint);
    _text(canvas, '₹', const Offset(150, 22), 14, FontWeight.w800, coinInk);
    // Two orbiting dots.
    paint.color = dotA.withValues(alpha: 0.8);
    canvas.drawCircle(const Offset(240, 120), 9, paint);
    paint.color = dotB;
    canvas.drawCircle(const Offset(60, 150), 7, paint);
  }

  @override
  bool shouldRepaint(_OrbPainter old) =>
      old.coin != coin || old.dotA != dotA || old.dotB != dotB;
}

class _LogoCardPainter extends CustomPainter {
  final LinearGradient gradient;
  final Color ring;

  _LogoCardPainter({required this.gradient, required this.ring});

  @override
  void paint(Canvas canvas, Size size) {
    final card = const Rect.fromLTWH(98, 62, 104, 124);
    final rrect = RRect.fromRectAndRadius(card, const Radius.circular(20));
    final paint = Paint()..shader = gradient.createShader(card);
    canvas.drawRRect(rrect, paint);

    // Left dark edge strip.
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(98, 62, 16, 124),
        const Radius.circular(8),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );
    canvas.restore();

    // Gold ₹ ring + glyph.
    canvas.drawCircle(
      const Offset(160, 112),
      22,
      Paint()
        ..color = ring
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    _text(canvas, '₹', const Offset(160, 112), 26, FontWeight.w800, ring);

    // Two muted bars.
    final bar = Paint()..color = Colors.white.withValues(alpha: 0.6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(132, 150, 56, 5),
        const Radius.circular(2.5),
      ),
      bar,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(144, 162, 32, 5),
        const Radius.circular(2.5),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.35),
    );
  }

  @override
  bool shouldRepaint(_LogoCardPainter old) => old.ring != ring;
}

// ---------------------------------------------------------------------------
// 1 · SMS — bubble slides in, connector draws, transaction card pops.
// ---------------------------------------------------------------------------

class OnbSmsArt extends StatefulWidget {
  final double height;

  const OnbSmsArt({super.key, this.height = 250});

  @override
  State<OnbSmsArt> createState() => _OnbSmsArtState();
}

class _OnbSmsArtState extends State<OnbSmsArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  );
  bool _wired = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_wired) return;
    _wired = true;
    if (MediaQuery.of(context).disableAnimations) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _seg(double start, double end) =>
      ((_c.value - start) / (end - start)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return _ArtBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          // slideL: delay .3s, dur 1s → window ~0.18..0.76 of 1.7s.
          final slide = Curves.easeOutCubic.transform(_seg(0.18, 0.76));
          // draw: delay .4s, dur 1.6s.
          final draw = Curves.ease.transform(_seg(0.24, 1.0));
          // popA: delay .9s, dur .7s.
          final pop = Curves.easeOutBack.transform(_seg(0.53, 0.94));
          return CustomPaint(
            size: _kArtSize,
            painter: _SmsPainter(
              p: p,
              slide: slide,
              draw: draw,
              pop: pop.clamp(0.0, 1.0),
            ),
          );
        },
      ),
    );
  }
}

class _SmsPainter extends CustomPainter {
  final AppPalette p;
  final double slide;
  final double draw;
  final double pop;

  _SmsPainter({
    required this.p,
    required this.slide,
    required this.draw,
    required this.pop,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _BackdropPainter(disc: p.surface2, inner: p.border).paint(canvas, size);

    // SMS bubble, sliding in from the left (-60 → 0) with fade.
    canvas.save();
    canvas.translate(-60 * (1 - slide), 0);
    final bubbleAlpha = slide;
    _rrect(
      canvas,
      const Rect.fromLTWH(34, 52, 148, 62),
      18,
      p.surface.withValues(alpha: bubbleAlpha),
    );
    _rrect(
      canvas,
      const Rect.fromLTWH(50, 68, 90, 7),
      3.5,
      p.muted.withValues(alpha: 0.5 * bubbleAlpha),
    );
    _rrect(
      canvas,
      const Rect.fromLTWH(50, 83, 116, 7),
      3.5,
      p.muted.withValues(alpha: 0.3 * bubbleAlpha),
    );
    _rrect(
      canvas,
      const Rect.fromLTWH(50, 98, 60, 7),
      3.5,
      p.muted.withValues(alpha: 0.3 * bubbleAlpha),
    );
    canvas.restore();

    // Connector path drawn progressively (replaces stroke-dashoffset).
    final path = Path()
      ..moveTo(150, 120)
      ..cubicTo(150, 140, 170, 140, 176, 150);
    final metric = path.computeMetrics().first;
    final drawn = metric.extractPath(0, metric.length * draw);
    canvas.drawPath(
      drawn,
      Paint()
        ..color = p.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    // Transaction card pops in (scale .6 → 1, fade), origin at its centre.
    const cardRect = Rect.fromLTWH(112, 142, 160, 66);
    final center = cardRect.center;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    final scale = 0.6 + 0.4 * pop;
    canvas.scale(scale);
    canvas.translate(-center.dx, -center.dy);
    _rrect(canvas, cardRect, 18, p.primary.withValues(alpha: pop));
    _text(
      canvas,
      'Swiggy · UPI',
      const Offset(130 + 36, 142 + 18),
      12,
      FontWeight.w500,
      p.onPrimary.withValues(alpha: 0.8 * pop),
      align: TextAlign.left,
      anchorLeft: true,
      baselineX: 130,
    );
    _text(
      canvas,
      '−₹450',
      const Offset(130, 142 + 44),
      20,
      FontWeight.w800,
      p.onPrimary.withValues(alpha: pop),
      anchorLeft: true,
      baselineX: 130,
    );
    // Green check circle.
    canvas.drawCircle(
      const Offset(248, 175),
      14,
      Paint()..color = p.income.withValues(alpha: pop),
    );
    final check = Path()
      ..moveTo(241, 175)
      ..lineTo(246, 180)
      ..lineTo(255, 170);
    canvas.drawPath(
      check,
      Paint()
        ..color = Colors.white.withValues(alpha: pop)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SmsPainter old) =>
      old.slide != slide || old.draw != draw || old.pop != pop;
}

// ---------------------------------------------------------------------------
// 2 · Receipt — floating receipt with a scanning bar.
// ---------------------------------------------------------------------------

class OnbReceiptArt extends StatefulWidget {
  final double height;

  const OnbReceiptArt({super.key, this.height = 250});

  @override
  State<OnbReceiptArt> createState() => _OnbReceiptArtState();
}

class _OnbReceiptArtState extends State<OnbReceiptArt>
    with TickerProviderStateMixin {
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );
  late final AnimationController _scan = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  bool _wired = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_wired) return;
    _wired = true;
    if (MediaQuery.of(context).disableAnimations) {
      _float.value = 0;
      _scan.value = 0;
    } else {
      _float.repeat(reverse: true);
      _scan.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _float.dispose();
    _scan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return _ArtBox(
      height: widget.height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const _ArtBackdrop(),
          AnimatedBuilder(
            animation: _float,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, -9 * math.sin(_float.value * math.pi)),
              child: child,
            ),
            child: CustomPaint(
              size: _kArtSize,
              painter: _ReceiptPainter(p: p),
            ),
          ),
          AnimatedBuilder(
            animation: _scan,
            builder: (context, _) => CustomPaint(
              size: _kArtSize,
              painter: _ScanPainter(
                color: p.secondary,
                // Eased 0 → 96 so it rests at the ends like the mockup.
                dy: 96 * Curves.easeInOut.transform(_scan.value),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptPainter extends CustomPainter {
  final AppPalette p;

  _ReceiptPainter({required this.p});

  @override
  void paint(Canvas canvas, Size size) {
    // Receipt body with a jagged bottom edge.
    final receipt = Path()
      ..moveTo(104, 40)
      ..lineTo(196, 40)
      ..lineTo(196, 178)
      ..lineTo(185, 170)
      ..lineTo(173, 178)
      ..lineTo(162, 170)
      ..lineTo(150, 178)
      ..lineTo(138, 170)
      ..lineTo(127, 178)
      ..lineTo(115, 170)
      ..lineTo(104, 178)
      ..close();
    canvas.drawPath(receipt, Paint()..color = p.surface);

    _rrect(
      canvas,
      const Rect.fromLTWH(118, 58, 64, 7),
      3.5,
      p.muted.withValues(alpha: 0.6),
    );
    _rrect(
      canvas,
      const Rect.fromLTWH(118, 78, 48, 6),
      3,
      p.muted.withValues(alpha: 0.35),
    );
    _rrect(
      canvas,
      const Rect.fromLTWH(118, 94, 56, 6),
      3,
      p.muted.withValues(alpha: 0.35),
    );
    _rrect(
      canvas,
      const Rect.fromLTWH(118, 110, 40, 6),
      3,
      p.muted.withValues(alpha: 0.35),
    );
    _rrect(
      canvas,
      const Rect.fromLTWH(118, 134, 64, 9),
      4.5,
      p.primary.withValues(alpha: 0.8),
    );
  }

  @override
  bool shouldRepaint(_ReceiptPainter old) => false;
}

class _ScanPainter extends CustomPainter {
  final Color color;
  final double dy;

  _ScanPainter({required this.color, required this.dy});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(0, dy);
    _rrect(canvas, const Rect.fromLTWH(84, 46, 132, 4), 2, color);
    canvas.drawRect(
      const Rect.fromLTWH(84, 46, 132, 26),
      Paint()..color = color.withValues(alpha: 0.15),
    );
  }

  @override
  bool shouldRepaint(_ScanPainter old) => old.dy != dy || old.color != color;
}

// ---------------------------------------------------------------------------
// 3 · Budget — donut ring draws to 16%, alert badge pops.
// ---------------------------------------------------------------------------

class OnbBudgetArt extends StatefulWidget {
  final double height;

  const OnbBudgetArt({super.key, this.height = 250});

  @override
  State<OnbBudgetArt> createState() => _OnbBudgetArtState();
}

class _OnbBudgetArtState extends State<OnbBudgetArt>
    with TickerProviderStateMixin {
  late final AnimationController _draw = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );
  bool _wired = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_wired) return;
    _wired = true;
    if (MediaQuery.of(context).disableAnimations) {
      _draw.value = 1;
      _float.value = 0;
    } else {
      _draw.forward();
      _float.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _draw.dispose();
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return _ArtBox(
      height: widget.height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const _ArtBackdrop(),
          AnimatedBuilder(
            animation: Listenable.merge([_draw, _float]),
            builder: (context, _) => Transform.translate(
              offset: Offset(0, -9 * math.sin(_float.value * math.pi)),
              child: CustomPaint(
                size: _kArtSize,
                painter: _BudgetRingPainter(
                  track: p.surface2,
                  arc: p.primary,
                  // Pop badge once the ring is mostly drawn (popA delay).
                  progress: Curves.ease.transform(_draw.value),
                ),
                child: _budgetLabels(p),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _draw,
            builder: (context, _) => CustomPaint(
              size: _kArtSize,
              painter: _AlertBadgePainter(
                fill: p.secondary,
                ink: AppColors.darkFabText,
                pop: Curves.easeOutBack
                    .transform(((_draw.value - 0.6) / 0.4).clamp(0.0, 1.0))
                    .clamp(0.0, 1.0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _budgetLabels(AppPalette p) => SizedBox(
    width: _kArtSize.width,
    height: _kArtSize.height,
    child: Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 92,
          child: Text(
            'Food',
            textAlign: TextAlign.center,
            style: AppText.caption(p.muted).copyWith(fontSize: 12),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 108,
          child: Text(
            '84%',
            textAlign: TextAlign.center,
            style: AppText.display(p.ink).copyWith(fontSize: 20),
          ),
        ),
      ],
    ),
  );
}

class _BudgetRingPainter extends CustomPainter {
  final Color track;
  final Color arc;
  final double progress;

  _BudgetRingPainter({
    required this.track,
    required this.arc,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const center = Offset(150, 112);
    const r = 56.0;
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16,
    );
    // Target sweep is 16% of the circle (--end:.16); animate up to it.
    final sweep = 2 * math.pi * 0.16 * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r),
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..color = arc
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_BudgetRingPainter old) => old.progress != progress;
}

class _AlertBadgePainter extends CustomPainter {
  final Color fill;
  final Color ink;
  final double pop;

  _AlertBadgePainter({
    required this.fill,
    required this.ink,
    required this.pop,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (pop <= 0) return;
    const rect = Rect.fromLTWH(206, 36, 70, 32);
    final center = rect.center;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(0.6 + 0.4 * pop);
    canvas.translate(-center.dx, -center.dy);
    _rrect(canvas, rect, 16, fill.withValues(alpha: pop));
    _text(
      canvas,
      '90% alert',
      center,
      12,
      FontWeight.w800,
      ink.withValues(alpha: pop),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AlertBadgePainter old) => old.pop != pop;
}

// ---------------------------------------------------------------------------
// 7 · Done — teal/green circle pops, check draws, confetti bursts.
// ---------------------------------------------------------------------------

class OnbDoneArt extends StatefulWidget {
  final double height;

  const OnbDoneArt({super.key, this.height = 250});

  @override
  State<OnbDoneArt> createState() => _OnbDoneArtState();
}

class _OnbDoneArtState extends State<OnbDoneArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2300),
  );
  bool _wired = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_wired) return;
    _wired = true;
    if (MediaQuery.of(context).disableAnimations) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _seg(double start, double end) =>
      ((_c.value - start) / (end - start)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final reduce = MediaQuery.of(context).disableAnimations;
    return _ArtBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final circle = Curves.easeOutBack.transform(_seg(0.0, 0.35));
          final check = Curves.ease.transform(_seg(0.39, 0.74));
          // confetti burst runs across the whole timeline (delay ~.5s).
          final burst = _seg(0.22, 1.0);
          return CustomPaint(
            size: _kArtSize,
            painter: _DonePainter(
              circleColor: p.income,
              circlePop: circle.clamp(0.0, 1.0),
              checkDraw: check,
              // Under reduce-motion the confetti must not emit; the end state
              // is fully dispersed/faded, so painting nothing is correct.
              burst: reduce ? 1.0 : burst,
              reduce: reduce,
              colors: [p.primary, p.secondary, p.income, p.expense],
            ),
          );
        },
      ),
    );
  }
}

class _DonePainter extends CustomPainter {
  final Color circleColor;
  final double circlePop;
  final double checkDraw;
  final double burst;
  final bool reduce;
  final List<Color> colors;

  _DonePainter({
    required this.circleColor,
    required this.circlePop,
    required this.checkDraw,
    required this.burst,
    required this.reduce,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Confetti (24 particles, flying outward) painted behind the circle.
    if (!reduce && burst > 0 && burst < 1) {
      const n = 24;
      final eased = Curves.easeOut.transform(burst);
      for (var i = 0; i < n; i++) {
        final angle = i / n * 2 * math.pi;
        // Deterministic radius so the burst is stable frame-to-frame.
        final radius = 100 + (i * 37 % 60);
        final dx = math.cos(angle) * radius * eased;
        final dy = math.sin(angle) * radius * eased - 20 * eased;
        final paint = Paint()
          ..color = colors[i % colors.length].withValues(alpha: 1 - burst);
        canvas.save();
        canvas.translate(150 + dx, 115 + dy);
        canvas.rotate(burst * 300 * math.pi / 180);
        final s = 0.2 + 0.8 * eased;
        _rrect(
          canvas,
          Rect.fromCenter(center: Offset.zero, width: 9 * s, height: 9 * s),
          3,
          paint.color,
        );
        canvas.restore();
      }
    }

    // Circle pops in.
    if (circlePop > 0) {
      canvas.drawCircle(
        const Offset(150, 115),
        56 * circlePop,
        Paint()..color = circleColor,
      );
    }

    // Check draws (124,116 → 144,136 → 178,96).
    if (checkDraw > 0) {
      final path = Path()
        ..moveTo(124, 116)
        ..lineTo(144, 136)
        ..lineTo(178, 96);
      final metric = path.computeMetrics().first;
      canvas.drawPath(
        metric.extractPath(0, metric.length * checkDraw),
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(_DonePainter old) =>
      old.circlePop != circlePop ||
      old.checkDraw != checkDraw ||
      old.burst != burst;
}

// ---------------------------------------------------------------------------
// 6 · Fingerprint target — pulsing rings, success state.
// ---------------------------------------------------------------------------

class OnbFingerprint extends StatefulWidget {
  final VoidCallback? onTap;
  final bool ok;

  const OnbFingerprint({super.key, this.onTap, this.ok = false});

  @override
  State<OnbFingerprint> createState() => _OnbFingerprintState();
}

class _OnbFingerprintState extends State<OnbFingerprint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ring = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );
  bool _wired = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_wired) return;
    _wired = true;
    // Pulsing rings only animate while idle and motion is allowed.
    if (!MediaQuery.of(context).disableAnimations && !widget.ok) {
      _ring.repeat();
    }
  }

  @override
  void didUpdateWidget(OnbFingerprint old) {
    super.didUpdateWidget(old);
    if (widget.ok && _ring.isAnimating) _ring.stop();
  }

  @override
  void dispose() {
    _ring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final reduce = MediaQuery.of(context).disableAnimations;

    return Pressable(
      onTap: widget.onTap,
      child: SizedBox(
        width: 150,
        height: 150,
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (!widget.ok && !reduce)
                AnimatedBuilder(
                  animation: _ring,
                  builder: (context, _) => CustomPaint(
                    size: const Size(150, 150),
                    painter: _RingPulsePainter(
                      color: p.primary,
                      t: _ring.value,
                    ),
                  ),
                ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutBack,
                width: 110,
                height: 110,
                transform: widget.ok
                    ? (Matrix4.identity()..scaleByDouble(1.12, 1.12, 1.12, 1))
                    : Matrix4.identity(),
                transformAlignment: Alignment.center,
                decoration: BoxDecoration(
                  color: widget.ok ? p.income : p.surface2,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (widget.ok ? p.income : p.primary).withValues(
                        alpha: 0.3,
                      ),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Text(
                    widget.ok ? '✓' : '👆',
                    key: ValueKey<bool>(widget.ok),
                    style: TextStyle(
                      fontSize: 50,
                      color: widget.ok ? Colors.white : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPulsePainter extends CustomPainter {
  final Color color;
  final double t;

  _RingPulsePainter({required this.color, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    const baseR = 55.0;
    void ring(double phase) {
      final v = (t + phase) % 1.0;
      final scale = 1 + v * 0.9; // 1 → 1.9
      final alpha = (0.6 * (1 - v)).clamp(0.0, 1.0);
      canvas.drawCircle(
        center,
        baseR * scale,
        Paint()
          ..color = color.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    ring(0);
    ring(0.5);
  }

  @override
  bool shouldRepaint(_RingPulsePainter old) => old.t != t;
}

// ---------------------------------------------------------------------------
// Shared painter helpers.
// ---------------------------------------------------------------------------

void _rrect(Canvas canvas, Rect rect, double radius, Color color) {
  canvas.drawRRect(
    RRect.fromRectAndRadius(rect, Radius.circular(radius)),
    Paint()..color = color,
  );
}

/// Draws [text] centred on [at] (or left-anchored at [baselineX] when
/// [anchorLeft]). The anchor's y is treated as the text baseline, matching the
/// SVG `<text y=...>` convention the mockup uses.
void _text(
  Canvas canvas,
  String text,
  Offset at,
  double size,
  FontWeight weight,
  Color color, {
  TextAlign align = TextAlign.center,
  bool anchorLeft = false,
  double baselineX = 0,
}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: AppText.body(color).copyWith(fontSize: size, fontWeight: weight),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  // Approximate baseline placement: shift up by the font ascent (~0.8em).
  final dy = at.dy - size * 0.8;
  final dx = anchorLeft ? baselineX : at.dx - tp.width / 2;
  tp.paint(canvas, Offset(dx, dy));
}
