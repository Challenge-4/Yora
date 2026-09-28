import 'dart:io';
import 'package:flutter/material.dart';

class ImageThemeBackground extends StatelessWidget {
  final String imagePath;
  const ImageThemeBackground({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            File(imagePath),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
          Container(color: Colors.black.withValues(alpha: 0.35)),
        ],
      ),
    );
  }
}
