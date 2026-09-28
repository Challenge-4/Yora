import 'package:flutter/material.dart';
import '../../utils/thumbnail_urls.dart';

class HighResCover extends StatelessWidget {
  final String url;
  final Widget placeholder;

  const HighResCover({super.key, required this.url, required this.placeholder});

  Widget _candidate(List<String> urls, int index) {
    return Image.network(
      urls[index],
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
    final urls = highResThumbnailUrls(url);
    return Stack(
      fit: StackFit.expand,
      children: [
        placeholder,
        if (urls.isNotEmpty) _candidate(urls, 0),
      ],
    );
  }
}
