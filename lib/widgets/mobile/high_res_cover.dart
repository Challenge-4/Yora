import 'dart:async';
import 'package:flutter/material.dart';
import '../../utils/cached_network_image.dart';
import '../../utils/thumbnail_urls.dart';

final Map<String, String?> _resolvedHighRes = {};
final Set<String> _resolvingHighRes = {};
final Map<String, DateTime> _failedHighRes = {};

void precacheHighResCover(BuildContext context, String url) {
  final failedAt = _failedHighRes[url];
  if (failedAt != null && DateTime.now().difference(failedAt) < const Duration(minutes: 2)) return;
  if (_resolvedHighRes.containsKey(url) || !_resolvingHighRes.add(url)) return;
  final candidates = highResThumbnailUrls(url);
  Future<void> attempt(int index) async {
    if (!context.mounted) {
      _resolvingHighRes.remove(url);
      return;
    }
    if (index >= candidates.length) {
      _failedHighRes[url] = DateTime.now();
      _resolvingHighRes.remove(url);
      return;
    }
    var failed = false;
    await precacheImage(CachedNetworkImage(candidates[index]), context, onError: (_, _) => failed = true);
    if (failed) return attempt(index + 1);
    _resolvedHighRes[url] = candidates[index];
    _resolvingHighRes.remove(url);
  }

  unawaited(attempt(0));
}

class HighResCover extends StatelessWidget {
  final String url;
  final Widget placeholder;

  const HighResCover({super.key, required this.url, required this.placeholder});

  Widget _candidate(List<String> urls, int index) {
    return Image(
      image: CachedNetworkImage(urls[index]),
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) => frame == null && !wasSynchronouslyLoaded
          ? const SizedBox.shrink()
          : child,
      errorBuilder: (_, _, _) => index + 1 < urls.length ? _candidate(urls, index + 1) : const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolved = _resolvedHighRes[url];
    final urls = _resolvedHighRes.containsKey(url) ? [?resolved] : highResThumbnailUrls(url);
    return Stack(
      fit: StackFit.expand,
      children: [
        placeholder,
        if (urls.isNotEmpty) _candidate(urls, 0),
      ],
    );
  }
}
