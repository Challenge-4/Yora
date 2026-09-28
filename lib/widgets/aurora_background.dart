import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;

class AuroraBackground extends StatefulWidget {
  const AuroraBackground({super.key});

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBand {
  final Color color;
  final double verticalPosition;
  final double amplitude;
  final double frequency;
  final double speed;
  final double phase;
  final double thickness;
  final double opacityPhase;

  const _AuroraBand({
    required this.color,
    required this.verticalPosition,
    required this.amplitude,
    required this.frequency,
    required this.speed,
    required this.phase,
    required this.thickness,
    required this.opacityPhase,
  });
}

const List<Color> _auroraColors = [
  Color(0xFF00FFA3),
  Color(0xFF7C4DFF),
  Color(0xFF00E5FF),
];

class _AuroraBackgroundState extends State<AuroraBackground> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _elapsedSeconds = 0;
  late final List<_AuroraBand> _bands;

  @override
  void initState() {
    super.initState();
    final random = Random(3);
    _bands = List.generate(3, (i) {
      return _AuroraBand(
        color: _auroraColors[i % _auroraColors.length],
        verticalPosition: 0.08 + i * 0.1 + random.nextDouble() * 0.05,
        amplitude: 36 + random.nextDouble() * 30,
        frequency: 0.8 + random.nextDouble() * 0.5,
        speed: 0.05 + random.nextDouble() * 0.05,
        phase: random.nextDouble() * 2 * pi,
        thickness: 110 + random.nextDouble() * 60,
        opacityPhase: random.nextDouble() * 2 * pi,
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
          painter: _AuroraPainter(elapsedSeconds: _elapsedSeconds, bands: _bands),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final double elapsedSeconds;
  final List<_AuroraBand> bands;

  _AuroraPainter({required this.elapsedSeconds, required this.bands});

  static const _steps = 20;

  @override
  void paint(Canvas canvas, Size size) {
    for (final band in bands) {
      final baseY = band.verticalPosition * size.height;
      double wave(double x) => sin(
            x / size.width * 2 * pi * band.frequency + elapsedSeconds * band.speed * 2 * pi + band.phase,
          );

      final path = Path();
      for (var i = 0; i <= _steps; i++) {
        final x = size.width * i / _steps;
        final y = baseY + wave(x) * band.amplitude;
        i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      for (var i = _steps; i >= 0; i--) {
        final x = size.width * i / _steps;
        final y = baseY + band.thickness + wave(x) * band.amplitude * 0.6;
        path.lineTo(x, y);
      }
      path.close();

      final opacity = (0.12 + 0.14 * (0.5 + 0.5 * sin(elapsedSeconds * 0.3 + band.opacityPhase))).clamp(0.0, 1.0);
      final rect = Rect.fromLTWH(0, baseY - band.amplitude, size.width, band.thickness + band.amplitude * 2);
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [band.color.withValues(alpha: opacity), band.color.withValues(alpha: 0)],
        ).createShader(rect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14)
        ..blendMode = BlendMode.plus;
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter oldDelegate) => true;
}
