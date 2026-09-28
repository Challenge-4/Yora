import 'yt_dlp_service.dart';
import 'youtube_backend.dart';

class TrackMetadataRepairService {
  final YoutubeBackend ytDlpService;
  const TrackMetadataRepairService({required this.ytDlpService});

  Future<YtSearchResult?> fetchVideoInfo(String videoId) => ytDlpService.fetchVideoInfo(videoId);
}
