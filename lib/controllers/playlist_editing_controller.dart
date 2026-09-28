import 'package:flutter/material.dart';
import '../models/playlist_undo_entry.dart';
import '../state/library_state.dart';
import '../state/playback_state.dart';
import '../state/playlist_view_state.dart';
import '../state/selection_state.dart';
import '../state/theme_state.dart';
import '../presenters/track_presenter.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/playlist_display_name.dart';

class PlaylistEditingController {
  final LibraryState library;
  final SelectionState selection;
  final PlaybackState playback;
  final PlaylistViewState playlistView;
  final TrackPresenter trackPresenter;
  final ThemeState themeState;
  final Future<void> Function() saveMedia;
  final void Function(String message, {IconData icon, Color? iconColor, bool persistent}) showAppToast;
  final AppLocalizations Function() l10n;

  PlaylistEditingController({
    required this.library,
    required this.selection,
    required this.playback,
    required this.playlistView,
    required this.trackPresenter,
    required this.themeState,
    required this.saveMedia,
    required this.showAppToast,
    required this.l10n,
  });

  void _pushUndo(PlaylistUndoEntry entry) {
    selection.undoStack.add(entry);
    selection.redoStack.clear();
    if (selection.undoStack.length > 50) selection.undoStack.removeAt(0);
  }

  void pushUndoSnapshot(String playlistName, List<String> currentTracks) {
    _pushUndo(TrackListSnapshot(playlistName, List<String>.from(currentTracks)));
  }

  bool deletePlaylist(String playlistName) {
    final playlistData = library.musicPlaylists[playlistName];
    if (playlistData == null) return false;
    if (playlistData['isLiked'] == true || playlistData['isLocalFiles'] == true) return false;
    final index = library.musicPlaylists.keys.toList().indexOf(playlistName);
    _pushUndo(PlaylistDeletionSnapshot(playlistName, Map<String, dynamic>.from(playlistData), index));
    library.musicPlaylists.remove(playlistName);
    if (selection.selectedPlaylistFilter == playlistName) {
      selection.selectedPlaylistFilter = 'Fichiers locaux';
    }
    if (playback.currentQueueSourcePlaylist == playlistName) {
      playback.currentQueueSourcePlaylist = null;
    }
    playlistView.resetFor(playlistName);
    return true;
  }

  bool _restorePlaylistAt(String playlistName, Map<String, dynamic> data, int index) {
    if (library.musicPlaylists.containsKey(playlistName)) return false;
    final entries = library.musicPlaylists.entries.toList();
    final clampedIndex = index.clamp(0, entries.length);
    final rebuilt = <String, Map<String, dynamic>>{};
    for (var i = 0; i < entries.length; i++) {
      if (i == clampedIndex) rebuilt[playlistName] = data;
      rebuilt[entries[i].key] = entries[i].value;
    }
    if (clampedIndex == entries.length) rebuilt[playlistName] = data;
    library.musicPlaylists = rebuilt;
    return true;
  }

  void reorderPlaylists(int oldIndex, int newIndex) {
    final entries = library.musicPlaylists.entries.toList();
    var pinnedCount = 0;
    for (final entry in entries) {
      if (entry.value['isLiked'] == true || entry.value['isLocalFiles'] == true) {
        pinnedCount++;
      } else {
        break;
      }
    }
    if (oldIndex < pinnedCount) return;
    final target = newIndex < pinnedCount ? pinnedCount : newIndex;
    if (target == oldIndex) return;
    final moved = entries.removeAt(oldIndex);
    entries.insert(target, moved);
    final rebuilt = <String, Map<String, dynamic>>{};
    for (final entry in entries) {
      rebuilt[entry.key] = entry.value;
    }
    library.musicPlaylists = rebuilt;
    saveMedia();
  }

  void handleTrackReorder(String playlistName, List<String> tracks, int oldIndex, int newIndex) {
    pushUndoSnapshot(playlistName, tracks);
    final draggedPath = tracks[oldIndex];
    final currentSelection = selection.selectedTrackPaths;
    final isMultiDrag = currentSelection.length > 1 && currentSelection.contains(draggedPath);

    if (!isMultiDrag) {
      final item = tracks.removeAt(oldIndex);
      tracks.insert(newIndex, item);
    } else {
      final withoutDragged = List<String>.from(tracks)..removeAt(oldIndex);
      String? anchorAfter;
      for (var i = newIndex; i < withoutDragged.length; i++) {
        if (!currentSelection.contains(withoutDragged[i])) {
          anchorAfter = withoutDragged[i];
          break;
        }
      }
      final movingGroup = tracks.where(currentSelection.contains).toList();
      tracks.removeWhere(currentSelection.contains);
      final insertIndex = anchorAfter == null ? tracks.length : tracks.indexOf(anchorAfter);
      tracks.insertAll(insertIndex, movingGroup);
    }
    saveMedia();
  }

  void undo() {
    if (selection.undoStack.isEmpty) return;
    final entry = selection.undoStack.removeLast();
    switch (entry) {
      case TrackListSnapshot(:final playlistName, :final tracks):
        final currentTracks = library.musicPlaylists[playlistName]?['tracks'] as List<String>?;
        if (currentTracks == null) return;
        final restoredCount = tracks.length - currentTracks.length;
        selection.redoStack.add(TrackListSnapshot(playlistName, List<String>.from(currentTracks)));
        currentTracks
          ..clear()
          ..addAll(tracks);
        selection.selectedTrackPaths.clear();
        playback.syncQueueWithPlaylistTracks(playlistName, currentTracks);
        if (restoredCount > 0) {
          showAppToast(
            l10n().restoredTracksToast(restoredCount),
            icon: Icons.restore,
            iconColor: themeState.accent,
          );
        }
      case PlaylistDeletionSnapshot(:final playlistName, :final data, :final index):
        final restored = _restorePlaylistAt(playlistName, data, index);
        selection.selectedPlaylistFilter = playlistName;
        selection.redoStack.add(PlaylistDeletionSnapshot(playlistName, data, index));
        if (restored) {
          showAppToast(
            l10n().playlistRestoredToast(playlistDisplayName(playlistName, l10n())),
            icon: Icons.restore,
            iconColor: themeState.accent,
          );
        }
    }
    saveMedia();
  }

  void redo() {
    if (selection.redoStack.isEmpty) return;
    final entry = selection.redoStack.removeLast();
    switch (entry) {
      case TrackListSnapshot(:final playlistName, :final tracks):
        final currentTracks = library.musicPlaylists[playlistName]?['tracks'] as List<String>?;
        if (currentTracks == null) return;
        selection.undoStack.add(TrackListSnapshot(playlistName, List<String>.from(currentTracks)));
        currentTracks
          ..clear()
          ..addAll(tracks);
        selection.selectedTrackPaths.clear();
        playback.syncQueueWithPlaylistTracks(playlistName, currentTracks);
      case PlaylistDeletionSnapshot(:final playlistName, :final data, :final index):
        if (!library.musicPlaylists.containsKey(playlistName)) return;
        library.musicPlaylists.remove(playlistName);
        if (selection.selectedPlaylistFilter == playlistName) {
          selection.selectedPlaylistFilter = 'Fichiers locaux';
        }
        if (playback.currentQueueSourcePlaylist == playlistName) {
          playback.currentQueueSourcePlaylist = null;
        }
        playlistView.resetFor(playlistName);
        selection.undoStack.add(PlaylistDeletionSnapshot(playlistName, data, index));
    }
    saveMedia();
  }

  void selectAllTracksInCurrentPlaylist() {
    final playlistName = selection.selectedPlaylistFilter;
    if (playlistName == null) return;
    final tracks = library.musicPlaylists[playlistName]?['tracks'] as List<String>?;
    if (tracks == null) return;
    final display = trackPresenter.displayTracksForPlaylist(playlistName, tracks);
    selection.selectedTrackPaths = display.toSet();
  }

  void copySelectedTracks({bool notify = true}) {
    final playlistName = selection.selectedPlaylistFilter;
    if (playlistName == null || selection.selectedTrackPaths.isEmpty) return;
    final tracks = library.musicPlaylists[playlistName]?['tracks'] as List<String>? ?? const <String>[];
    final count = selection.selectedTrackPaths.length;
    selection.trackClipboard = tracks.where(selection.selectedTrackPaths.contains).toList();
    if (notify) {
      showAppToast(
        l10n().copiedTracksToast(count),
        icon: Icons.copy,
      );
    }
  }

  void removeSelectedTracksFromPlaylist(String playlistName, List<String> tracks) {
    pushUndoSnapshot(playlistName, tracks);
    tracks.removeWhere(selection.selectedTrackPaths.contains);
    selection.selectedTrackPaths.clear();
    playback.syncQueueWithPlaylistTracks(playlistName, tracks);
    saveMedia();
  }

  void deleteSelectedTracks() {
    final playlistName = selection.selectedPlaylistFilter;
    if (playlistName == null || selection.selectedTrackPaths.isEmpty) return;
    final tracks = library.musicPlaylists[playlistName]?['tracks'] as List<String>?;
    if (tracks == null) return;
    final removedCount = selection.selectedTrackPaths.length;
    removeSelectedTracksFromPlaylist(playlistName, tracks);
    showAppToast(
      l10n().tracksRemovedFromPlaylistToast(removedCount),
      icon: Icons.remove_circle_outline,
    );
  }

  void cutSelectedTracks() {
    final playlistName = selection.selectedPlaylistFilter;
    if (playlistName == null || selection.selectedTrackPaths.isEmpty) return;
    final tracks = library.musicPlaylists[playlistName]?['tracks'] as List<String>?;
    if (tracks == null) return;
    final cutCount = selection.selectedTrackPaths.length;
    copySelectedTracks(notify: false);
    removeSelectedTracksFromPlaylist(playlistName, tracks);
    showAppToast(
      l10n().cutTracksToast(cutCount),
      icon: Icons.content_cut,
    );
  }

  void pasteTracksIntoCurrentPlaylist() {
    final playlistName = selection.selectedPlaylistFilter;
    final clipboard = selection.trackClipboard;
    if (playlistName == null || clipboard == null || clipboard.isEmpty) return;
    final tracks = library.musicPlaylists[playlistName]?['tracks'] as List<String>?;
    if (tracks == null) return;
    if (library.musicPlaylists[playlistName]?['isLocalFiles'] == true) {
      showAppToast(
        l10n().localFilesReadOnlyToast,
        icon: Icons.info_outline,
      );
      return;
    }
    pushUndoSnapshot(playlistName, tracks);
    var pastedCount = 0;
    for (final path in clipboard) {
      if (!tracks.contains(path)) {
        tracks.add(path);
        pastedCount++;
      }
    }
    playback.syncQueueWithPlaylistTracks(playlistName, tracks);
    saveMedia();
    showAppToast(
      pastedCount > 0 ? l10n().pastedTracksToast(pastedCount) : l10n().alreadyInThisPlaylistToast,
      icon: pastedCount > 0 ? Icons.check_circle : Icons.info_outline,
      iconColor: pastedCount > 0 ? themeState.accent : null,
    );
  }
}
