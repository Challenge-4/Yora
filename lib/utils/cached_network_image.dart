import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;
import 'platform_paths.dart';

int _fnv1a(String text, int seed) {
  var hash = seed;
  for (final unit in text.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}

String _cacheFileName(String url) {
  final first = _fnv1a(url, 0x811c9dc5).toRadixString(16).padLeft(8, '0');
  final second = _fnv1a(url.split('').reversed.join(), 0x050c5d1f).toRadixString(16).padLeft(8, '0');
  return '$first$second${url.length}';
}

File _cacheFileFor(String url) =>
    File(joinPath([defaultCacheBasePath(), 'thumbnails', _cacheFileName(url)]));

class CachedNetworkImage extends ImageProvider<CachedNetworkImage> {
  final String url;
  final double scale;

  const CachedNetworkImage(this.url, {this.scale = 1.0});

  @override
  Future<CachedNetworkImage> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(CachedNetworkImage key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(codec: _load(decode), scale: scale, debugLabel: url);
  }

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    final file = _cacheFileFor(url);
    Uint8List? bytes;
    try {
      if (await file.exists()) bytes = await file.readAsBytes();
    } catch (_) {}
    if (bytes != null && bytes.isNotEmpty) {
      try {
        return await decode(await ui.ImmutableBuffer.fromUint8List(bytes));
      } catch (_) {
        bytes = null;
        try {
          await file.delete();
        } catch (_) {}
      }
    }
    if (bytes == null || bytes.isEmpty) {
      final uri = Uri.parse(url);
      final response = await http.get(uri).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        throw NetworkImageLoadException(statusCode: response.statusCode, uri: uri);
      }
      bytes = response.bodyBytes;
      try {
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes);
      } catch (_) {}
    }
    return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
  }

  @override
  bool operator ==(Object other) => other is CachedNetworkImage && other.url == url && other.scale == scale;

  @override
  int get hashCode => Object.hash(url, scale);
}
