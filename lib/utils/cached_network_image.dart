import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;
import 'platform_paths.dart';

String Function()? coverDirectoryResolver;

final RegExp _youtubeThumbnail = RegExp(r'/vi(?:_webp)?/([A-Za-z0-9_-]{11})/([A-Za-z0-9_]+)\.(?:jpg|webp)');

int _fnv1a(String text, int seed) {
  var hash = seed;
  for (final unit in text.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}

String _coverFileName(String url) {
  final youtube = _youtubeThumbnail.firstMatch(url);
  if (youtube != null) return '${youtube.group(1)}.cover.${youtube.group(2)}.jpg';
  final first = _fnv1a(url, 0x811c9dc5).toRadixString(16).padLeft(8, '0');
  final second = _fnv1a(url.split('').reversed.join(), 0x050c5d1f).toRadixString(16).padLeft(8, '0');
  return 'cover.$first$second.jpg';
}

File? _coverFileFor(String url) {
  final directory = coverDirectoryResolver?.call();
  if (directory == null || directory.isEmpty) return null;
  return File(joinPath([directory, _coverFileName(url)]));
}

bool isCoverFileName(String name) => name.contains('.cover.') || name.startsWith('cover.');

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
    final file = _coverFileFor(url);
    if (file != null) {
      try {
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          if (bytes.isNotEmpty) return await decode(await ui.ImmutableBuffer.fromUint8List(bytes));
        }
      } catch (_) {
        try {
          await file.delete();
        } catch (_) {}
      }
    }
    final uri = Uri.parse(url);
    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      throw NetworkImageLoadException(statusCode: response.statusCode, uri: uri);
    }
    return decode(await ui.ImmutableBuffer.fromUint8List(response.bodyBytes));
  }

  @override
  bool operator ==(Object other) => other is CachedNetworkImage && other.url == url && other.scale == scale;

  @override
  int get hashCode => Object.hash(url, scale);
}

Future<void> saveCover(String url) async {
  if (url.isEmpty) return;
  final file = _coverFileFor(url);
  if (file == null || await file.exists()) return;
  final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
  if (response.statusCode != 200 || response.bodyBytes.isEmpty) return;
  await file.parent.create(recursive: true);
  await file.writeAsBytes(response.bodyBytes);
}

bool _savingCovers = false;

Future<void> saveCovers(Iterable<String> urls, {int concurrency = 4}) async {
  if (_savingCovers) return;
  _savingCovers = true;
  try {
    final queue = urls.where((url) => url.isNotEmpty).toSet().toList();
    var next = 0;
    Future<void> worker() async {
      while (next < queue.length) {
        final url = queue[next++];
        try {
          await saveCover(url);
        } catch (_) {}
      }
    }

    await Future.wait(List.generate(concurrency, (_) => worker()));
  } finally {
    _savingCovers = false;
  }
}

Future<void> deleteCoversFor(String youtubeVideoId) async {
  final directory = coverDirectoryResolver?.call();
  if (directory == null) return;
  try {
    await for (final entry in Directory(directory).list()) {
      if (entry is File && entry.uri.pathSegments.last.startsWith('$youtubeVideoId.cover.')) {
        try {
          await entry.delete();
        } catch (_) {}
      }
    }
  } catch (_) {}
}

Future<void> deleteLegacyThumbnailFolder() async {
  try {
    final legacy = Directory(joinPath([defaultCacheBasePath(), 'thumbnails']));
    if (await legacy.exists()) await legacy.delete(recursive: true);
  } catch (_) {}
}
