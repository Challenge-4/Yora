import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/charts_service.dart';
import '../state/charts_state.dart';

class ChartsController {
  final ChartsState state;
  final ChartsService chartsService;
  final VoidCallback requestRebuild;

  ChartsController({
    required this.state,
    required this.chartsService,
    required this.requestRebuild,
  });

  Future<void> loadGenres() async {
    if (state.genres != null || state.genresLoading) return;
    state.genresLoading = true;
    requestRebuild();
    try {
      state.genres = await chartsService.fetchGenres();
    } catch (e) {
      state.genres ??= [];
    } finally {
      state.genresLoading = false;
      requestRebuild();
    }
  }

  Future<void> loadCountries() async {
    if (state.countries != null || state.countriesLoading) return;
    state.countriesLoading = true;
    requestRebuild();
    try {
      state.countries = await chartsService.fetchCountryCharts();
    } catch (e) {
      state.countries ??= [];
    } finally {
      state.countriesLoading = false;
      requestRebuild();
    }
  }

  Future<void> loadNewReleases() async {
    if (state.newReleases != null || state.newReleasesLoading) return;
    state.newReleasesLoading = true;
    requestRebuild();
    try {
      state.newReleases = await chartsService.fetchNewReleases();
    } catch (e) {
      state.newReleases ??= [];
    } finally {
      state.newReleasesLoading = false;
      requestRebuild();
    }
  }

  void openGenre(YtMusicGenre genre) {
    state.openCountryName = null;
    state.openReleasePlaylistId = null;
    state.showingAllNewReleases = false;
    state.openGenreParams = genre.params;
    requestRebuild();
    if (state.tracksByGenre.containsKey(genre.params) || state.genreTracksLoading.contains(genre.params)) return;
    unawaited(_loadGenreTracks(genre.params));
  }

  Future<void> _loadGenreTracks(String params) async {
    state.genreTracksLoading.add(params);
    requestRebuild();
    try {
      state.tracksByGenre[params] = await chartsService.fetchGenreSongs(params);
    } catch (e) {
      state.tracksByGenre[params] = [];
    } finally {
      state.genreTracksLoading.remove(params);
      requestRebuild();
    }
  }

  void openCountry(YtMusicCountryChart country) {
    state.openGenreParams = null;
    state.openReleasePlaylistId = null;
    state.showingAllNewReleases = false;
    state.openCountryName = country.countryName;
    requestRebuild();
    if (state.tracksByCountry.containsKey(country.countryName) ||
        state.countryTracksLoading.contains(country.countryName)) {
      return;
    }
    unawaited(_loadCountryTracks(country.countryName, country.playlistId));
  }

  Future<void> _loadCountryTracks(String countryName, String playlistId) async {
    state.countryTracksLoading.add(countryName);
    requestRebuild();
    try {
      state.tracksByCountry[countryName] = await chartsService.fetchCountryChartTracks(playlistId);
    } catch (e) {
      state.tracksByCountry[countryName] = [];
    } finally {
      state.countryTracksLoading.remove(countryName);
      requestRebuild();
    }
  }

  void openRelease(NewRelease release) {
    state.openGenreParams = null;
    state.openCountryName = null;
    state.showingAllNewReleases = false;
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

  void openAllNewReleases() {
    state.openGenreParams = null;
    state.openCountryName = null;
    state.openReleasePlaylistId = null;
    state.showingAllNewReleases = true;
    requestRebuild();
  }

  void closeDetail() {
    state.openGenreParams = null;
    state.openCountryName = null;
    state.openReleasePlaylistId = null;
    state.showingAllNewReleases = false;
    requestRebuild();
  }
}
