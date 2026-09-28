import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PlayingEqualizerIcon extends StatefulWidget {
  const PlayingEqualizerIcon({super.key});

  @override
  State<PlayingEqualizerIcon> createState() => PlayingEqualizerIconState();
}

class PlayingEqualizerIconState extends State<PlayingEqualizerIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.of(context).accent;
    return SizedBox(
      width: 16,
      height: 16,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(3, (i) {
              final t = (_controller.value + i * 0.33) % 1.0;
              final heightFactor = 0.25 + 0.75 * (0.5 + 0.5 * sin(t * 2 * pi));
              return Container(
                width: 3,
                height: 16 * heightFactor,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(1),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
