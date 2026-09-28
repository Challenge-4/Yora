import 'package:flutter/foundation.dart';
import '../services/charts_service.dart';
import '../services/yt_dlp_service.dart';

class ChartsState extends ChangeNotifier {
  List<YtMusicGenre>? genres;
  bool genresLoading = false;

  String? openGenreParams;

  final Map<String, List<YtSearchResult>> tracksByGenre = {};
  final Set<String> genreTracksLoading = {};

  List<YtMusicCountryChart>? countries;
  bool countriesLoading = false;

  String? openCountryName;

  final Map<String, List<YtSearchResult>> tracksByCountry = {};
  final Set<String> countryTracksLoading = {};

  List<NewRelease>? newReleases;
  bool newReleasesLoading = false;

  String? openReleasePlaylistId;

  final Map<String, List<YtSearchResult>> tracksByRelease = {};
  final Set<String> releaseTracksLoading = {};

  bool showingAllNewReleases = false;
}
