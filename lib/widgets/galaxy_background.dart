import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;

class GalaxyBackground extends StatefulWidget {
  const GalaxyBackground({super.key});

  @override
  State<GalaxyBackground> createState() => _GalaxyBackgroundState();
}

class _Star {
  final double dx;
  final double dy;
  final double radius;
  final double phase;
  final double speed;
  const _Star({required this.dx, required this.dy, required this.radius, required this.phase, required this.speed});
}

class _ShootingStar {
  final double startDx;
  final double startDy;
  final double angle;
  final double lengthFraction;
  final double cycleSeconds;
  final double offsetSeconds;
  const _ShootingStar({
    required this.startDx,
    required this.startDy,
    required this.angle,
    required this.lengthFraction,
    required this.cycleSeconds,
    required this.offsetSeconds,
  });
}

class _GalaxyBackgroundState extends State<GalaxyBackground> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _elapsedSeconds = 0;
  late final List<_Star> _stars;
  late final List<_ShootingStar> _shootingStars;

  @override
  void initState() {
    super.initState();
    final random = Random(7);
    _stars = List.generate(160, (_) {
      return _Star(
        dx: random.nextDouble(),
        dy: random.nextDouble(),
        radius: 0.6 + random.nextDouble() * 1.4,
        phase: random.nextDouble() * 2 * pi,
        speed: 0.6 + random.nextDouble() * 1.4,
      );
    });
    _shootingStars = List.generate(4, (i) {
      return _ShootingStar(
        startDx: random.nextDouble(),
        startDy: random.nextDouble() * 0.4,
        angle: (25 + random.nextDouble() * 35) * pi / 180,
        lengthFraction: 0.12 + random.nextDouble() * 0.08,
        cycleSeconds: 7 + random.nextDouble() * 8,
        offsetSeconds: random.nextDouble() * 12,
      );
    });
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    setState(() => _elapsedSeconds = elapsed.inMicroseconds / 1e6);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _GalaxyPainter(
            elapsedSeconds: _elapsedSeconds,
            stars: _stars,
            shootingStars: _shootingStars,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _GalaxyPainter extends CustomPainter {
  final double elapsedSeconds;
  final List<_Star> stars;
  final List<_ShootingStar> shootingStars;

  _GalaxyPainter({required this.elapsedSeconds, required this.stars, required this.shootingStars});

  @override
  void paint(Canvas canvas, Size size) {
    final starPaint = Paint();
    for (final star in stars) {
      final twinkle = 0.35 + 0.65 * (0.5 + 0.5 * sin(elapsedSeconds * star.speed + star.phase));
      starPaint.color = Colors.white.withValues(alpha: twinkle.clamp(0.0, 1.0));
      canvas.drawCircle(Offset(star.dx * size.width, star.dy * size.height), star.radius, starPaint);
    }

    final trailPaint = Paint()
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final s in shootingStars) {
      final cycleT = ((elapsedSeconds + s.offsetSeconds) % s.cycleSeconds) / s.cycleSeconds;
      const activeStart = 0.85;
      if (cycleT < activeStart) continue;
      final localT = (cycleT - activeStart) / (1 - activeStart);
      final travel = size.longestSide * 0.6;
      final dir = Offset(cos(s.angle), sin(s.angle));
      final start = Offset(s.startDx * size.width, s.startDy * size.height);
      final head = start + dir * (travel * localT);
      final tail = head - dir * (s.lengthFraction * size.longestSide);
      final opacity = sin(localT * pi).clamp(0.0, 1.0);
      trailPaint.shader = ui.Gradient.linear(
        tail,
        head,
        [Colors.white.withValues(alpha: 0), Colors.white.withValues(alpha: opacity)],
      );
      canvas.drawLine(tail, head, trailPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GalaxyPainter oldDelegate) => true;
}
