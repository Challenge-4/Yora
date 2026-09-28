final RegExp _youtubeThumbnail = RegExp(r'^(https?://(?:img\.youtube\.com|i\.ytimg\.com)/vi/[^/?]+/)[a-z0-9]+\.jpg');
final RegExp _sizedGoogleImage = RegExp(r'=w\d+-h\d+');

List<String> highResThumbnailUrls(String url) {
  final youtube = _youtubeThumbnail.firstMatch(url);
  if (youtube != null) {
    final base = youtube.group(1)!;
    return ['${base}maxresdefault.jpg', '${base}sddefault.jpg', '${base}hqdefault.jpg'];
  }
  final isGoogleImage = url.contains('googleusercontent.com') || url.contains('ggpht.com');
  if (isGoogleImage && _sizedGoogleImage.hasMatch(url)) {
    return [url.replaceFirst(_sizedGoogleImage, '=w1080-h1080')];
  }
  return const [];
}
