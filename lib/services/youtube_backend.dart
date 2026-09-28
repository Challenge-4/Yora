import 'yt_dlp_service.dart';

abstract class YoutubeBackend {
  String get audioExtension;

  Future<List<YtSearchResult>> search(String query, {int count = 8});

  Future<List<YtSearchResult>> searchWithFallback(String primaryQuery, String fallbackQuery) async {
    final primary = await search(primaryQuery);
    if (primary.isNotEmpty) return primary;
    return search(fallbackQuery);
  }

  Future<(String title, List<YtSearchResult> tracks)> fetchPlaylist(String url);

  Future<YtSearchResult?> fetchVideoInfo(String videoId);

  Future<List<({String id, String title})>> listChannelPlaylists(String channelUrl);

  Future<void> downloadAudio(
    String videoId,
    String outputTemplate, {
    required Duration perAttemptTimeout,
    void Function(double progress)? onProgress,
  });

  Future<void> downloadAudioClip(
    String videoId,
    String outputTemplate, {
    required Duration maxDuration,
    required Duration perAttemptTimeout,
    Duration startOffset = Duration.zero,
  });

  Future<Duration?> probeDuration(String filePath);

  Future<String?> resolveFfmpegPath();
}

double scoreSearchCandidate({
  required String title,
  required String author,
  String? query,
}) {
  final lowerTitle = title.toLowerCase();
  final lowerAuthor = author.toLowerCase();
  double score = 0;
  if (lowerAuthor.endsWith('- topic')) score += 5;
  if (lowerTitle.contains('official audio')) score += 3;
  if (lowerTitle.contains('official video') || lowerTitle.contains('official music video')) score += 2;
  if (lowerTitle.contains('lyrics') || lowerTitle.contains('lyric video')) score += 1;
  if (lowerTitle.contains('live') || lowerTitle.contains('en direct') || lowerTitle.contains('concert')) score -= 4;
  if (lowerTitle.contains('cover')) score -= 3;
  if (lowerTitle.contains('remix') || lowerTitle.contains('sped up') || lowerTitle.contains('slowed')) score -= 2;
  if (lowerTitle.contains('reaction')) score -= 5;
  if (lowerTitle.contains('instrumental') || lowerTitle.contains('karaoke')) score -= 3;

  if (query != null) {
    final queryWords = _normalizeForMatch(query).split(' ').where((w) => w.isNotEmpty).toSet();
    final authorWords = _normalizeForMatch(author).split(' ').where((w) => w.isNotEmpty).toSet();
    if (authorWords.isNotEmpty && authorWords.every(queryWords.contains)) {
      score += 4;
    }
  }
  return score;
}

String _normalizeForMatch(String s) {
  return s.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}
