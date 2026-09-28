import 'package:flutter/foundation.dart';
import '../services/charts_service.dart';
import '../services/yt_dlp_service.dart';

class ArtistState extends ChangeNotifier {
  String? openArtistName;

  final Map<String, ArtistPage> artistPages = {};
  final Set<String> artistNamesUnavailable = {};
  final Set<String> artistLoading = {};

  String? openReleasePlaylistId;
  final Map<String, List<YtSearchResult>> tracksByRelease = {};
  final Set<String> releaseTracksLoading = {};
}
