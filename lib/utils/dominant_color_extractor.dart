import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

Future<Color?> extractDominantColor(String imagePath) async {
  final bytes = await File(imagePath).readAsBytes();
  return compute(_dominantColorFromBytes, bytes);
}

class _ColorBucket {
  int count = 0;
  int rSum = 0;
  int gSum = 0;
  int bSum = 0;

  Color get averageColor => Color.fromARGB(255, rSum ~/ count, gSum ~/ count, bSum ~/ count);
}

Color? _dominantColorFromBytes(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final resized = img.copyResize(decoded, width: 48, height: 48, maintainAspect: false);

  Map<int, _ColorBucket> collectBuckets({required bool skipNearGrayscale}) {
    final buckets = <int, _ColorBucket>{};
    for (final pixel in resized) {
      final r = pixel.r.toInt();
      final g = pixel.g.toInt();
      final b = pixel.b.toInt();
      if (skipNearGrayscale) {
        final lightness = HSLColor.fromColor(Color.fromARGB(255, r, g, b)).lightness;
        if (lightness < 0.08 || lightness > 0.92) continue;
      }
      final key = ((r >> 4) << 8) | ((g >> 4) << 4) | (b >> 4);
      final bucket = buckets.putIfAbsent(key, () => _ColorBucket());
      bucket.count++;
      bucket.rSum += r;
      bucket.gSum += g;
      bucket.bSum += b;
    }
    return buckets;
  }

  var buckets = collectBuckets(skipNearGrayscale: true);
  if (buckets.isEmpty) buckets = collectBuckets(skipNearGrayscale: false);
  if (buckets.isEmpty) return null;

  _ColorBucket? best;
  var bestScore = -1.0;
  for (final bucket in buckets.values) {
    final saturation = HSLColor.fromColor(bucket.averageColor).saturation;
    final score = bucket.count * (0.35 + saturation);
    if (score > bestScore) {
      bestScore = score;
      best = bucket;
    }
  }
  return best?.averageColor;
}
