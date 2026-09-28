import '../services/yt_dlp_service.dart';

bool isPermanentlyUnavailableError(Object error) {
  final message = error.toString().toLowerCase();
  const permanentPatterns = [
    'video unavailable',
    'private video',
    'this video is not available',
    'this video is no longer available',
    "n'est pas disponible",
    'vidéo non disponible',
    'video has been removed',
    'terminated',
    'was removed following',
    'copyright removal request',
    'copyright claim',
    'copyright infringement',
  ];
  return permanentPatterns.any(message.contains);
}

bool isPreviewTrack(String path) => path.startsWith('preview:');

bool isOnlineTrack(String path) => path.startsWith('online:');

Map<String, String> metadataMap(YtSearchResult video) {
  return {
    'title': video.title,
    'author': video.author,
    'thumbnailUrl': video.thumbnailUrl,
    if (video.album != null && video.album!.isNotEmpty) 'album': video.album!,
    if (video.releaseYear != null && video.releaseYear!.isNotEmpty) 'year': video.releaseYear!,
    if (video.durationMs != null) 'durationMs': video.durationMs!.toString(),
  };
}

final RegExp titleNoisePattern = RegExp(
  r'[([]\s*(?:'
  r'official\s*music\s*video|'
  r'official\s*video|'
  r'official\s*audio|'
  r'official\s*visuali[sz]er|'
  r'lyric\s*video|'
  r'visuali[sz]er|'
  r'clip\s*officiel|'
  r'vid[ée]o\s*officiell?e?|'
  r'audio\s*officiell?e?'
  r')[^)\]]*[)\]]',
  caseSensitive: false,
);

String cleanDisplayTitle(String rawTitle) {
  var title = rawTitle;
  final dashMatch = RegExp(r'\s[-–—]\s').firstMatch(title);
  if (dashMatch != null) {
    final afterDash = title.substring(dashMatch.end).trim();
    if (afterDash.isNotEmpty) title = afterDash;
  }
  final withoutNoise = title.replaceAll(titleNoisePattern, '').replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  return withoutNoise.isEmpty ? title : withoutNoise;
}

String formatDuration(Duration duration) {
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  return '${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}';
}
