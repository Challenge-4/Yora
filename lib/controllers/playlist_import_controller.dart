import 'dart:async';
import 'package:flutter/material.dart';
import '../services/playlist_import_service.dart';
import '../services/youtube_backend.dart';
import '../state/library_state.dart';
import '../state/selection_state.dart';
import '../l10n/generated/app_localizations.dart';

class PlaylistImportController {
  final LibraryState library;
  final SelectionState selection;
  final PlaylistImportService playlistImportService;
  final YoutubeBackend ytDlpService;
  final Future<void> Function() saveMedia;
  final void Function(String message, {IconData icon, Color iconColor, bool persistent}) showAppToast;
  final Future<void> Function() rewarmMissingOnlineCaches;
  final bool Function() isMounted;
  final VoidCallback requestRebuild;
  final AppLocalizations Function() l10n;

  PlaylistImportController({
    required this.library,
    required this.selection,
    required this.playlistImportService,
    required this.ytDlpService,
    required this.saveMedia,
    required this.showAppToast,
    required this.rewarmMissingOnlineCaches,
    required this.isMounted,
    required this.requestRebuild,
    required this.l10n,
  });

  bool _importing = false;
  String? _activePlaceholderName;
  final Set<String> _cancelledPlaceholders = {};

  void cancelImport(String placeholderName) {
    if (_activePlaceholderName != placeholderName) return;
    library.importingPlaylists.remove(placeholderName);
    _cancelledPlaceholders.add(placeholderName);
    _importing = false;
    _activePlaceholderName = null;
  }

  void importFromUrl(String url) {
    if (_importing) {
      showAppToast(
        l10n().importAlreadyInProgressToast,
        icon: Icons.info_outline,
      );
      return;
    }
    var placeholderName = l10n().importInProgressLabel;
    var suffix = 2;
    while (library.musicPlaylists.containsKey(placeholderName)) {
      placeholderName = l10n().importInProgressWithSuffixLabel(suffix);
      suffix++;
    }
    library.musicPlaylists[placeholderName] = {'tracks': <String>[], 'image': null, 'description': ''};
    library.importingPlaylists.add(placeholderName);
    _importing = true;
    _activePlaceholderName = placeholderName;
    requestRebuild();
    unawaited(_importFromUrl(url, placeholderName));
  }

  Future<void> _importFromUrl(String url, String placeholderName) async {
    String? errorMessage;
    var finalName = placeholderName;
    final resolvedTracks = <String>[];
    final newlyCreatedMetadataPaths = <String>{};
    try {
      final imported = await playlistImportService.importFromUrl(url);
      const maxConcurrent = 3;
      final matches = List<String?>.filled(imported.tracks.length, null);
      var nextIndex = 0;

      Future<void> worker() async {
        while (true) {
          final index = nextIndex;
          if (index >= imported.tracks.length) return;
          nextIndex++;
          final track = imported.tracks[index];
          String? videoId = track.youtubeId;
          if (videoId == null) {
            try {
              final found = await ytDlpService.searchWithFallback(
                '${track.artist} ${track.title} audio',
                '${track.artist} ${track.title}',
              );
              if (found.isNotEmpty) videoId = found.first.id;
            } catch (_) {}
          }
          if (videoId == null) continue;
          final onlinePath = 'online:$videoId';
          matches[index] = onlinePath;
          if (!library.trackMetadata.containsKey(onlinePath)) {
            newlyCreatedMetadataPaths.add(onlinePath);
          }
          library.trackMetadata[onlinePath] = {
            'title': track.title,
            'author': track.artist,
            'thumbnailUrl': track.thumbnailUrl ?? 'https://img.youtube.com/vi/$videoId/mqdefault.jpg',
            if (track.album != null && track.album!.isNotEmpty) 'album': track.album!,
          };
        }
      }

      await Future.wait(List.generate(maxConcurrent, (_) => worker()));
      resolvedTracks.addAll(matches.whereType<String>());
      if (resolvedTracks.isEmpty) {
        throw Exception(l10n().noTrackFoundForPlaylistError);
      }

      final baseName = imported.name.trim().isNotEmpty ? imported.name.trim() : l10n().importedPlaylistDefaultName;
      finalName = baseName;
      var nameSuffix = 2;
      while (library.musicPlaylists.containsKey(finalName) && finalName != placeholderName) {
        finalName = '$baseName ($nameSuffix)';
        nameSuffix++;
      }
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
    }

    if (_activePlaceholderName == placeholderName) {
      _importing = false;
      _activePlaceholderName = null;
    }

    if (!isMounted()) return;
    if (_cancelledPlaceholders.remove(placeholderName)) {
      if (newlyCreatedMetadataPaths.isNotEmpty) {
        final referencedPaths = <String>{
          for (final playlist in library.musicPlaylists.values) ...(playlist['tracks'] as List<String>),
        };
        var removedAny = false;
        for (final path in newlyCreatedMetadataPaths) {
          if (!referencedPaths.contains(path)) {
            library.trackMetadata.remove(path);
            removedAny = true;
          }
        }
        if (removedAny) await saveMedia();
      }
      return;
    }
    library.musicPlaylists.remove(placeholderName);
    library.importingPlaylists.remove(placeholderName);
    if (errorMessage == null) {
      library.musicPlaylists[finalName] = {'tracks': resolvedTracks, 'image': null, 'description': ''};
      library.playlistCreatedDates[finalName] = DateTime.now().toIso8601String();
      if (selection.selectedPlaylistFilter == placeholderName) selection.selectedPlaylistFilter = finalName;
    } else if (selection.selectedPlaylistFilter == placeholderName) {
      selection.selectedPlaylistFilter = null;
    }
    requestRebuild();
    await saveMedia();
    if (errorMessage == null) {
      unawaited(rewarmMissingOnlineCaches());
    } else {
      showAppToast(
        l10n().importFailedToast(errorMessage),
        icon: Icons.error_outline,
        iconColor: Colors.redAccent,
      );
    }
  }
}
