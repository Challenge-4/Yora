import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../state/library_state.dart';
import '../state/playback_state.dart';
import '../state/playlist_view_state.dart';
import '../state/theme_state.dart';
import '../utils/track_formatting.dart';
import '../l10n/generated/app_localizations.dart';

class TrackPresenter {
  final LibraryState library;
  final PlaybackState playback;
  final PlaylistViewState playlistView;
  final ThemeState themeState;
  final AppLocalizations Function() l10n;

  TrackPresenter(this.library, this.playback, this.playlistView, this.themeState, this.l10n);

  MapEntry<String, Map<String, dynamic>>? get likedPlaylistEntry {
    for (final entry in library.musicPlaylists.entries) {
      if (entry.value['isLiked'] == true) return entry;
    }
    return null;
  }

  String likeKeyForPath(String path) {
    if (isPreviewTrack(path)) return 'online:${path.substring('preview:'.length)}';
    return path;
  }

  bool get isCurrentTrackLiked {
    final path = playback.currentPlayingPath;
    final liked = likedPlaylistEntry;
    if (path == null || liked == null) return false;
    return (liked.value['tracks'] as List<String>).contains(likeKeyForPath(path));
  }

  String title(String path) {
    if (isPreviewTrack(path)) return cleanDisplayTitle(playback.previewVideo?.title ?? l10n().previewFallbackTitle);
    final rawTitle = library.trackMetadata[path]?['title'];
    if (rawTitle != null) return cleanDisplayTitle(rawTitle);
    return path.split(Platform.pathSeparator).last;
  }

  String subtitle(String path) {
    if (isPreviewTrack(path)) return playback.previewVideo?.author ?? l10n().previewFallbackAuthor;
    return library.trackMetadata[path]?['author'] ?? l10n().localAudioLabel;
  }

  String? authorFor(String path) {
    if (isPreviewTrack(path)) return playback.previewVideo?.author;
    return library.trackMetadata[path]?['author'];
  }

  String album(String path) {
    final meta = isPreviewTrack(path) ? null : library.trackMetadata[path];
    if (meta == null) return isOnlineTrack(path) || isPreviewTrack(path) ? 'N/A' : 'Local';
    final value = meta['album'];
    return (value != null && value.isNotEmpty) ? value : 'N/A';
  }

  Duration durationValue(String path) {
    if (isOnlineTrack(path)) {
      final ms = int.tryParse(library.trackMetadata[path]?['durationMs'] ?? '');
      return ms != null ? Duration(milliseconds: ms) : Duration.zero;
    }
    return library.trackDurations[path] ?? Duration.zero;
  }

  String durationLabel(String path) {
    if (isOnlineTrack(path)) {
      final durationMs = int.tryParse(library.trackMetadata[path]?['durationMs'] ?? '');
      return durationMs != null ? formatDuration(Duration(milliseconds: durationMs)) : '--:--';
    }
    final cached = library.trackDurations[path];
    return cached != null ? formatDuration(cached) : '--:--';
  }

  int releaseYearValue(String path) => int.tryParse(library.trackMetadata[path]?['year'] ?? '') ?? 0;

  String addedDateLabel(String path) {
    final iso = library.trackAddedDates[path];
    final date = iso != null ? DateTime.tryParse(iso) : null;
    final t = l10n();
    if (date == null) return t.justNowLabel;
    final diff = DateTime.now().difference(date);
    if (diff.inHours < 1) return t.justNowLabel;
    if (diff.inHours < 24) return t.hoursAgoLabel(diff.inHours);
    final days = diff.inDays;
    if (days < 7) return t.daysAgoLabel(days);
    final weeks = days ~/ 7;
    if (weeks <= 4) return t.weeksAgoLabel(weeks);
    return DateFormat('d MMMM y', t.localeName).format(date);
  }

  String playlistTotalDurationLabel(List<String> tracks) {
    var total = Duration.zero;
    for (final path in tracks) {
      total += durationValue(path);
    }
    final hours = total.inHours;
    final minutes = total.inMinutes.remainder(60);
    if (hours > 0) return '$hours h $minutes min';
    if (total.inMinutes > 0) return '${total.inMinutes} min';
    return '${total.inSeconds} s';
  }

  List<String> displayTracksForPlaylist(String playlistName, List<String> tracks) {
    var result = tracks;
    final query = playlistView.searchQueryFor(playlistName).trim().toLowerCase();
    if (query.isNotEmpty) {
      result = result.where((p) => title(p).toLowerCase().contains(query) || subtitle(p).toLowerCase().contains(query)).toList();
    } else {
      result = List<String>.from(result);
    }
    final criterion = playlistView.sortCriterionFor(playlistName);
    switch (criterion) {
      case 'title':
        result.sort((a, b) => title(a).toLowerCase().compareTo(title(b).toLowerCase()));
        break;
      case 'artist':
        result.sort((a, b) => subtitle(a).toLowerCase().compareTo(subtitle(b).toLowerCase()));
        break;
      case 'album':
        result.sort((a, b) => album(a).toLowerCase().compareTo(album(b).toLowerCase()));
        break;
      case 'duration':
        result.sort((a, b) => durationValue(a).compareTo(durationValue(b)));
        break;
      case 'releaseDate':
        result.sort((a, b) => releaseYearValue(a).compareTo(releaseYearValue(b)));
        break;
      case 'recentlyAdded':
        result.sort((a, b) {
          final da = library.trackAddedDates[a];
          final db = library.trackAddedDates[b];
          if (da == null && db == null) return 0;
          if (da == null) return -1;
          if (db == null) return 1;
          return da.compareTo(db);
        });
        break;
      default:
        break;
    }
    if (criterion != null && !playlistView.sortAscendingFor(playlistName)) {
      result = result.reversed.toList();
    }
    return result;
  }

  String? thumbnailUrlFor(String path) =>
      (isPreviewTrack(path) ? playback.previewVideo?.thumbnailUrl : null) ?? library.trackMetadata[path]?['thumbnailUrl'];

  Widget thumbnail(String path, {double size = 40}) {
    final thumbnailUrl = thumbnailUrlFor(path);
    if (thumbnailUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.network(
          thumbnailUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => thumbnailFallback(size),
        ),
      );
    }
    return thumbnailFallback(size);
  }

  Widget thumbnailFallback(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: themeState.accent.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(Icons.music_note, color: themeState.palette.textSecondary, size: 20),
    );
  }
}
