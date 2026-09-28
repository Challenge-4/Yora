import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/charts_service.dart';
import '../state/artist_state.dart';

class ArtistController {
  final ArtistState state;
  final ChartsService chartsService;
  final VoidCallback requestRebuild;

  ArtistController({
    required this.state,
    required this.chartsService,
    required this.requestRebuild,
  });

  void openArtist(String artistName) {
    state.openReleasePlaylistId = null;
    state.openArtistName = artistName;
    requestRebuild();
    if (state.artistPages.containsKey(artistName) ||
        state.artistNamesUnavailable.contains(artistName) ||
        state.artistLoading.contains(artistName)) {
      return;
    }
    unawaited(_loadArtist(artistName));
  }

  Future<void> _loadArtist(String artistName) async {
    state.artistLoading.add(artistName);
    requestRebuild();
    try {
      final artist = await chartsService.searchArtist(artistName);
      if (artist == null) {
        state.artistNamesUnavailable.add(artistName);
      } else {
        state.artistPages[artistName] = await chartsService.fetchArtist(artist);
      }
    } catch (_) {
      state.artistNamesUnavailable.add(artistName);
    } finally {
      state.artistLoading.remove(artistName);
      requestRebuild();
    }
  }

  void closeArtist() {
    state.openArtistName = null;
    state.openReleasePlaylistId = null;
    requestRebuild();
  }

  void openRelease(NewRelease release) {
    state.openReleasePlaylistId = release.playlistId;
    requestRebuild();
    if (state.tracksByRelease.containsKey(release.playlistId) ||
        state.releaseTracksLoading.contains(release.playlistId)) {
      return;
    }
    unawaited(_loadReleaseTracks(release.playlistId));
  }

  Future<void> _loadReleaseTracks(String playlistId) async {
    state.releaseTracksLoading.add(playlistId);
    requestRebuild();
    try {
      state.tracksByRelease[playlistId] = await chartsService.fetchNewReleaseTracks(playlistId);
    } catch (e) {
      state.tracksByRelease[playlistId] = [];
    } finally {
      state.releaseTracksLoading.remove(playlistId);
      requestRebuild();
    }
  }

  void closeReleaseDetail() {
    state.openReleasePlaylistId = null;
    requestRebuild();
  }
}
