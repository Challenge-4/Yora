import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:media_kit/media_kit.dart';
import '../models/repeat_mode.dart';
import '../state/library_state.dart';
import '../state/playback_state.dart';
import '../state/selection_state.dart';
import '../state/general_settings_state.dart';
import '../services/yt_dlp_service.dart';
import '../utils/track_formatting.dart';
import '../l10n/generated/app_localizations.dart';
import 'download_cache_controller.dart';
import 'taskbar_sync_controller.dart';

class PlaybackController {
  final Player audioPlayer;
  final LibraryState library;
  final PlaybackState playback;
  final SelectionState selection;
  final DownloadCacheController downloads;
  final TaskbarSyncController taskbarSync;
  final GeneralSettingsState generalSettings;
  final Future<void> Function() saveMedia;
  final void Function(String message, {IconData icon, Color iconColor, bool persistent}) showAppToast;
  final void Function(String path, YtSearchResult video, File realFile) completeTrackMetadata;
  final VoidCallback refreshSearchOverlay;
  final bool Function() isMounted;
  final VoidCallback requestRebuild;
  final AppLocalizations Function() l10n;
  final VoidCallback onPresenceUpdateNeeded;

  PlaybackController({
    required this.audioPlayer,
    required this.library,
    required this.playback,
    required this.selection,
    required this.downloads,
    required this.taskbarSync,
    required this.generalSettings,
    required this.saveMedia,
    required this.showAppToast,
    required this.completeTrackMetadata,
    required this.refreshSearchOverlay,
    required this.onPresenceUpdateNeeded,
    required this.isMounted,
    required this.requestRebuild,
    required this.l10n,
  });

  void _recordSessionForResume(String path) {
    generalSettings.recordSession(
      path: path,
      queue: playback.queue,
      queueIndex: playback.queueIndex,
      sourcePlaylist: playback.currentQueueSourcePlaylist,
    );
  }

  void _showPlaybackError(String logLabel, Object error, String userMessage) {
    debugPrint('$logLabel : $error');
    showAppToast(userMessage, icon: Icons.error_outline, iconColor: Colors.redAccent);
  }

  bool get _hasNextTrack {
    if (playback.customQueue.isNotEmpty || playback.repeatMode == RepeatMode.all) return true;
    if (playback.shuffle) return playback.shufflePos + 1 < playback.shuffleIndices.length;
    return playback.queueIndex + 1 < playback.queue.length;
  }

  Future<bool> _autoSkipUnavailable(int skipDepth) async {
    final maxAutoSkips = (playback.queue.length + playback.customQueue.length).clamp(1, 1000);
    if (skipDepth >= maxAutoSkips || !_hasNextTrack) return false;
    showAppToast(l10n().unavailableTrackSkippedToast, icon: Icons.skip_next);
    await playNext(userInitiated: true, skipDepth: skipDepth + 1);
    return true;
  }

  Future<void> onTrackTap(List<String> queueSource, int index, {String? sourcePlaylist}) async {
    final path = queueSource[index];
    if (playback.currentPlayingPath == path) {
      await togglePlayPause();
      return;
    }
    if (playback.currentPlayingPath == null || playback.currentQueueSourcePlaylist != sourcePlaylist) {
      await startQueue(queueSource, index, sourcePlaylist: sourcePlaylist);
      return;
    }
    final existingIndex = playback.queue.indexOf(path);
    if (existingIndex != -1) {
      await jumpToAutomaticQueueIndex(existingIndex);
    } else {
      await playPathDirectly(path);
    }
  }

  Future<void> jumpToAutomaticQueueIndex(int index) async {
    if (index < 0 || index >= playback.queue.length) return;
    playback.queueIndex = index;
    if (playback.shuffle) {
      final pos = playback.shuffleIndices.indexOf(index);
      if (pos != -1) playback.shufflePos = pos;
    }
    requestRebuild();
    await playCurrentQueueIndex();
  }

  Future<void> playStandaloneTrack(String path) async {
    if (playback.currentPlayingPath == null) {
      await startQueue([path], 0);
    } else {
      await playPathDirectly(path);
    }
  }

  Future<void> playPathDirectly(String path) => _playPath(path);

  Future<void> togglePlayPause() async {
    if (playback.currentPlayingPath == null) return;
    if (playback.isPlaying) {
      playback.userPaused = true;
      requestRebuild();
      await audioPlayer.pause();
    } else {
      playback.userPaused = false;
      requestRebuild();
      await audioPlayer.play();
    }
    taskbarSync.update();
    onPresenceUpdateNeeded();
  }

  static const _slowLoadThreshold = Duration(seconds: 2);

  void scheduleLoadingSpinnerIfSlow(String path) {
    Future.delayed(_slowLoadThreshold, () {
      if (!isMounted()) return;
      if (playback.currentPlayingPath == path && !playback.isPlaying) {
        playback.loadingQueuePath = path;
        requestRebuild();
      }
    });
  }

  void cleanupUnclaimedPreview({bool resumeInterrupted = false}) {
    if (playback.previewClaimed) return;
    final preview = playback.previewVideo;
    final tempPath = playback.previewTempPath;
    if (preview == null || tempPath == null) return;
    final shouldStopPlayback = playback.currentPlayingPath == 'preview:${preview.id}';
    final file = File(tempPath);
    playback.previewVideo = null;
    playback.previewTempPath = null;
    if (shouldStopPlayback && resumeInterrupted) {
      unawaited(resumeInterruptedByPreview());
    } else {
      if (shouldStopPlayback) playback.currentPlayingPath = null;
      requestRebuild();
      if (shouldStopPlayback) audioPlayer.stop();
    }
    file.exists().then((exists) {
      if (exists) file.delete().catchError((_) => file);
    });
  }

  String? _interruptedByPreviewPath;
  Duration _interruptedByPreviewPosition = Duration.zero;
  Duration _interruptedByPreviewDuration = Duration.zero;
  bool _interruptedByPreviewWasPaused = false;
  List<String> _interruptedByPreviewQueue = const [];
  int _interruptedByPreviewQueueIndex = -1;
  String? _interruptedByPreviewSourcePlaylist;

  void _captureInterruptedByPreviewIfNeeded() {
    final current = playback.currentPlayingPath;
    if (_interruptedByPreviewPath != null) return;
    if (current == null || current.startsWith('preview:')) return;
    _interruptedByPreviewPath = current;
    _interruptedByPreviewPosition = playback.position;
    _interruptedByPreviewDuration = playback.duration;
    _interruptedByPreviewWasPaused = playback.userPaused;
    _interruptedByPreviewQueue = List<String>.from(playback.queue);
    _interruptedByPreviewQueueIndex = playback.queueIndex;
    _interruptedByPreviewSourcePlaylist = playback.currentQueueSourcePlaylist;
  }

  bool _resumingAfterPreview = false;
  bool get isResumingAfterPreview => _resumingAfterPreview;

  Future<void> resumeInterruptedByPreview() async {
    final path = _interruptedByPreviewPath;
    if (path == null) {
      playback.currentPlayingPath = null;
      requestRebuild();
      return;
    }
    final position = _interruptedByPreviewPosition;
    final duration = _interruptedByPreviewDuration;
    final wasPaused = _interruptedByPreviewWasPaused;
    playback.queue = _interruptedByPreviewQueue;
    playback.queueIndex = _interruptedByPreviewQueueIndex;
    playback.currentQueueSourcePlaylist = _interruptedByPreviewSourcePlaylist;
    _interruptedByPreviewPath = null;
    _interruptedByPreviewQueue = const [];
    _interruptedByPreviewQueueIndex = -1;
    _interruptedByPreviewSourcePlaylist = null;
    _resumingAfterPreview = true;
    try {
      await _playPath(path, autoPlay: !wasPaused);
      if (position > Duration.zero) {
        playback.duration = duration;
        playback.setPosition(position);
        await audioPlayer.stream.duration.firstWhere((d) => d > Duration.zero).timeout(
              const Duration(seconds: 5),
              onTimeout: () => Duration.zero,
            );
        await audioPlayer.seek(position);
      }
    } finally {
      _resumingAfterPreview = false;
    }
    onPresenceUpdateNeeded();
  }

  Future<void> playPreview(YtSearchResult video) async {
    if (playback.currentPlayingPath == 'preview:${video.id}') {
      await togglePlayPause();
      return;
    }
    _captureInterruptedByPreviewIfNeeded();
    if (playback.previewVideo?.id == video.id && playback.previewTempPath != null) {
      playback.currentPlayingPath = 'preview:${video.id}';
      requestRebuild();
      await audioPlayer.open(Media(playback.previewTempPath!));
      return;
    }
    cleanupUnclaimedPreview();
    final requestId = ++playback.previewRequestId;
    playback.loadingPreviewId = video.id;
    requestRebuild();
    refreshSearchOverlay();
    try {
      final youtubeId = await downloads.resolveYoutubeVideoId(video);
      File tempFile;
      final inFlight = downloads.fullCacheInFlight[youtubeId];
      final bool isFullTrack;
      if (inFlight != null) {
        tempFile = await inFlight;
        isFullTrack = true;
      } else {
        final existingFullCache = downloads.fullCacheFilePath(youtubeId);
        if (await existingFullCache.exists()) {
          tempFile = existingFullCache;
          isFullTrack = true;
        } else {
          tempFile = await downloads.downloadPreviewSnippet(youtubeId, trackDurationMs: video.durationMs);
          isFullTrack = false;
        }
      }
      if (requestId != playback.previewRequestId) {
        if (!isFullTrack) tempFile.delete().catchError((_) => tempFile);
        return;
      }
      playback.previewVideo = video;
      playback.previewTempPath = tempFile.path;
      playback.previewClaimed = isFullTrack;
      playback.currentPlayingPath = 'preview:${video.id}';
      playback.loadingPreviewId = null;
      playback.queue = [];
      playback.queueIndex = -1;
      playback.currentQueueSourcePlaylist = null;
      requestRebuild();
      refreshSearchOverlay();
      await audioPlayer.open(Media(tempFile.path));
    } catch (e) {
      if (requestId == playback.previewRequestId) {
        playback.loadingPreviewId = null;
        requestRebuild();
      }
      _showPlaybackError('Erreur aperçu (yt-dlp)', e, l10n().previewUnavailableError);
    }
  }

  Future<void> startQueue(
    List<String> queue,
    int startIndex, {
    String? sourcePlaylist,
    bool autoPlay = true,
    bool shuffleFromStart = false,
  }) async {
    playback.queue = List<String>.from(queue);
    playback.queueIndex = startIndex;
    playback.currentQueueSourcePlaylist = sourcePlaylist;
    if (sourcePlaylist != null) {
      library.playlistPlayCounts[sourcePlaylist] = (library.playlistPlayCounts[sourcePlaylist] ?? 0) + 1;
    }
    if (playback.shuffle) {
      playback.generateShuffleOrder(keepCurrent: !shuffleFromStart);
      playback.queueIndex = playback.shuffleIndices[playback.shufflePos];
    }
    requestRebuild();
    await playCurrentQueueIndex(autoPlay: autoPlay);
  }

  Future<void> addToQueue(Iterable<String> paths) async {
    final pathList = paths.toList();
    if (pathList.isEmpty) return;
    if (playback.currentPlayingPath == null) {
      await startQueue(pathList, 0);
      return;
    }
    playback.customQueue.addAll(pathList);
    requestRebuild();
    showAppToast(
      l10n().tracksAddedToQueueToast(pathList.length),
      icon: Icons.queue_music,
    );
  }

  void clearCustomQueue() {
    if (playback.customQueue.isEmpty) return;
    playback.customQueue.clear();
    requestRebuild();
  }

  void removeFromCustomQueue(int index) {
    if (index < 0 || index >= playback.customQueue.length) return;
    playback.customQueue.removeAt(index);
    requestRebuild();
  }

  void removeFromAutomaticQueue(int index) {
    if (index < 0 || index >= playback.queue.length) return;
    playback.queue.removeAt(index);
    if (playback.queueIndex > index) playback.queueIndex--;
    if (playback.shuffle) {
      playback.shuffleIndices.remove(index);
      for (var i = 0; i < playback.shuffleIndices.length; i++) {
        if (playback.shuffleIndices[i] > index) playback.shuffleIndices[i]--;
      }
    }
    requestRebuild();
  }

  void reorderCustomQueue(int oldIndex, int newIndex) {
    if (oldIndex != newIndex && _moveItem(playback.customQueue, oldIndex, newIndex)) requestRebuild();
  }

  void reorderUpcoming(int oldPos, int newPos) {
    if (oldPos == newPos || oldPos < 0 || newPos < 0) return;
    final bool moved;
    if (playback.shuffle && playback.shuffleIndices.isNotEmpty) {
      final base = playback.shuffleIndices.indexOf(playback.queueIndex) + 1;
      moved = base > 0 && _moveItem(playback.shuffleIndices, base + oldPos, base + newPos);
    } else {
      final base = playback.queueIndex + 1;
      moved = _moveItem(playback.queue, base + oldPos, base + newPos);
    }
    if (moved) requestRebuild();
  }

  static bool _moveItem<T>(List<T> list, int from, int to) {
    if (from < 0 || to < 0 || from >= list.length || to >= list.length) return false;
    list.insert(to, list.removeAt(from));
    return true;
  }

  Future<void> playCurrentQueueIndex({bool autoPlay = true, int skipDepth = 0}) async {
    if (playback.queueIndex < 0 || playback.queueIndex >= playback.queue.length) return;
    await _playPath(playback.queue[playback.queueIndex], autoPlay: autoPlay, skipDepth: skipDepth);
  }

  int _playRequestId = 0;

  Future<void> _playPath(String path, {bool autoPlay = true, int skipDepth = 0}) async {
    final requestId = ++_playRequestId;
    _crossfadeArmedForPath = null;
    library.trackLastPlayedDates[path] = DateTime.now().toIso8601String();
    unawaited(saveMedia());
    if (selection.selectedTrackPaths.length == 1 && selection.selectedTrackPaths.contains(playback.currentPlayingPath)) {
      selection.selectedTrackPaths = {path};
      requestRebuild();
    }
    if (isOnlineTrack(path)) {
      downloads.prioritizeRewarm(path);
      final rawId = path.substring('online:'.length);
      final meta = library.trackMetadata[path];
      if (meta?['unavailable'] == 'true') {
        if (await _autoSkipUnavailable(skipDepth)) return;
        _showPlaybackError(
          'Piste indisponible',
          Exception('Marquée indisponible (vidéo supprimée ou privée sur YouTube).'),
          l10n().trackNoLongerAvailableError,
        );
        return;
      }
      final video = YtSearchResult(
        id: rawId,
        title: meta?['title'] ?? '',
        author: meta?['author'] ?? '',
        thumbnailUrl: meta?['thumbnailUrl'] ?? '',
        album: meta?['album'],
        releaseYear: meta?['year'],
      );
      playback.userPaused = !autoPlay;
      requestRebuild();
      try {
        final youtubeId = await downloads.resolveYoutubeVideoId(video);
        final cacheFile = downloads.fullCacheFilePath(youtubeId);
        if (!await cacheFile.exists()) {
          playback.loadingQueuePath = path;
          requestRebuild();
        }
        final tempFile = await downloads.fullCacheFor(youtubeId);
        completeTrackMetadata(path, video, tempFile);
        library.cachingTracks.remove(path);
        if (requestId != _playRequestId) {
          return;
        }
        await audioPlayer.stop();
        playback.currentPlayingPath = path;
        playback.position = Duration.zero;
        playback.duration = Duration.zero;
        _recordSessionForResume(path);
        onPresenceUpdateNeeded();
        requestRebuild();
        taskbarSync.update();
        final stalePreview = playback.previewVideo;
        final stalePreviewPath = playback.previewTempPath;
        if (stalePreview != null &&
            stalePreviewPath != null &&
            stalePreview.id == rawId &&
            stalePreviewPath != tempFile.path) {
          final staleFile = File(stalePreviewPath);
          playback.previewVideo = null;
          playback.previewTempPath = null;
          playback.previewClaimed = false;
          requestRebuild();
          staleFile.exists().then((exists) {
            if (exists) staleFile.delete().catchError((_) => staleFile);
          });
        }
        refreshSearchOverlay();
        await audioPlayer.open(Media(tempFile.path), play: autoPlay);
        unawaited(Future.delayed(const Duration(seconds: 3), () {
          if (isMounted() && playback.loadingQueuePath == path) {
            playback.loadingQueuePath = null;
            requestRebuild();
          }
        }));
      } catch (e) {
        playback.loadingQueuePath = null;
        library.cachingTracks.remove(path);
        requestRebuild();
        if (isPermanentlyUnavailableError(e)) {
          final updated = Map<String, String>.from(library.trackMetadata[path] ?? {});
          updated['unavailable'] = 'true';
          library.trackMetadata[path] = updated;
          requestRebuild();
          await saveMedia();
          if (await _autoSkipUnavailable(skipDepth)) return;
        }
        _showPlaybackError('Erreur lecture piste en ligne (yt-dlp)', e, l10n().onlineTrackUnavailableError);
      }
      return;
    }
    try {
      scheduleLoadingSpinnerIfSlow(path);
      await audioPlayer.stop();
      playback.currentPlayingPath = path;
      playback.position = Duration.zero;
      playback.duration = Duration.zero;
      _recordSessionForResume(path);
      playback.userPaused = !autoPlay;
      onPresenceUpdateNeeded();
      requestRebuild();
      taskbarSync.update();
      refreshSearchOverlay();
      await audioPlayer.open(Media(path), play: autoPlay);
    } catch (e) {
      playback.loadingQueuePath = null;
      requestRebuild();
      _showPlaybackError('Erreur audio', e, l10n().trackPlaybackError);
    }
  }

  Future<void> playNext({bool userInitiated = true, int skipDepth = 0}) async {
    if (playback.repeatMode == RepeatMode.one && !userInitiated) {
      await audioPlayer.seek(Duration.zero);
      await audioPlayer.play();
      return;
    }
    if (playback.customQueue.isNotEmpty) {
      final path = playback.customQueue.removeAt(0);
      requestRebuild();
      await _playPath(path, skipDepth: skipDepth);
      return;
    }
    if (playback.queue.isEmpty) {
      await _continueToNextPlaylist();
      return;
    }
    if (playback.shuffle) {
      int nextPos = playback.shufflePos + 1;
      if (nextPos >= playback.shuffleIndices.length) {
        if (playback.repeatMode == RepeatMode.all) {
          playback.generateShuffleOrder(keepCurrent: false);
          nextPos = 0;
        } else {
          await _continueToNextPlaylist();
          return;
        }
      }
      playback.shufflePos = nextPos;
      playback.queueIndex = playback.shuffleIndices[playback.shufflePos];
      requestRebuild();
    } else {
      int newIndex = playback.queueIndex + 1;
      if (newIndex >= playback.queue.length) {
        if (playback.repeatMode == RepeatMode.all) {
          newIndex = 0;
        } else {
          await _continueToNextPlaylist();
          return;
        }
      }
      playback.queueIndex = newIndex;
      requestRebuild();
    }
    await playCurrentQueueIndex(skipDepth: skipDepth);
  }

  Future<void> _continueToNextPlaylist() async {
    if (!generalSettings.smoothPlaylistTransitions) return;
    final sourcePlaylist = playback.currentQueueSourcePlaylist;
    if (sourcePlaylist == null) return;
    final names = library.musicPlaylists.keys.toList();
    final currentPos = names.indexOf(sourcePlaylist);
    if (currentPos == -1) return;
    for (var i = currentPos + 1; i < names.length; i++) {
      final nextName = names[i];
      final tracks = library.musicPlaylists[nextName]?['tracks'] as List<String>?;
      if (tracks != null && tracks.isNotEmpty) {
        await startQueue(tracks, 0, sourcePlaylist: nextName);
        return;
      }
    }
  }

  String? _crossfadeArmedForPath;

  bool _crossfadeAdvancing = false;
  bool get isCrossfadeAdvancing => _crossfadeAdvancing;

  void maybeTriggerCrossfade() {
    if (!generalSettings.crossfadeEnabled || _crossfadeAdvancing) return;
    final path = playback.currentPlayingPath;
    if (path == null || path == _crossfadeArmedForPath) return;
    if (path.startsWith('preview:')) return;
    final duration = playback.duration;
    if (duration <= Duration.zero) return;
    final thresholdMs = (generalSettings.crossfadeDurationSeconds * 1000).round().clamp(500, 20000);
    final remainingMs = duration.inMilliseconds - playback.position.inMilliseconds;
    if (remainingMs > thresholdMs || remainingMs <= 200) return;
    _crossfadeArmedForPath = path;
    unawaited(_runCrossfade(path, thresholdMs));
  }

  Future<bool> _rampVolume({required bool up, required int totalMs, required String guardPath}) async {
    const steps = 12;
    final stepMs = (totalMs / steps).round().clamp(20, 1000);
    for (var i = 1; i <= steps; i++) {
      if (!isMounted() || playback.currentPlayingPath != guardPath) return true;
      final target = playback.volume;
      final factor = up ? i / steps : 1 - (i / steps);
      await audioPlayer.setVolume((target * factor).clamp(0.0, 100.0));
      await Future.delayed(Duration(milliseconds: stepMs));
    }
    return false;
  }

  Future<void> _runCrossfade(String armedPath, int fadeMs) async {
    _crossfadeAdvancing = true;
    try {
      final abortedDown = await _rampVolume(up: false, totalMs: fadeMs, guardPath: armedPath);
      if (abortedDown) return;
      await playNext(userInitiated: false);
      _crossfadeAdvancing = false;
      final newPath = playback.currentPlayingPath;
      if (newPath != null) {
        await _rampVolume(up: true, totalMs: fadeMs, guardPath: newPath);
      }
    } finally {
      _crossfadeAdvancing = false;
      if (isMounted()) unawaited(audioPlayer.setVolume(playback.volume));
    }
  }

  Future<void> seekCurrentToZero() async {
    await audioPlayer.seek(Duration.zero);
  }

  Future<void> seekBy(Duration delta) async {
    if (playback.currentPlayingPath == null) return;
    var target = playback.position + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (playback.duration > Duration.zero && target > playback.duration) target = playback.duration;
    await audioPlayer.seek(target);
  }

  Future<void> playPrevious() async {
    if (playback.queue.isEmpty) return;
    if (playback.position.inSeconds > 3) {
      await seekCurrentToZero();
      return;
    }
    if (playback.shuffle) {
      if (playback.shufflePos <= 0) {
        await seekCurrentToZero();
        return;
      }
      playback.shufflePos--;
      playback.queueIndex = playback.shuffleIndices[playback.shufflePos];
      requestRebuild();
    } else {
      int newIndex = playback.queueIndex - 1;
      if (newIndex < 0) {
        if (playback.repeatMode == RepeatMode.all) {
          newIndex = playback.queue.length - 1;
        } else {
          await seekCurrentToZero();
          return;
        }
      }
      playback.queueIndex = newIndex;
      requestRebuild();
    }
    await playCurrentQueueIndex();
  }
}
