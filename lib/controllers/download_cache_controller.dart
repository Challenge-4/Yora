import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../state/library_state.dart';
import '../state/playback_state.dart';
import '../state/selection_state.dart';
import '../state/theme_state.dart';
import '../services/yt_dlp_service.dart';
import '../services/youtube_backend.dart';
import '../services/metadata_tagger.dart';
import '../services/android_media_store_service.dart';
import '../utils/track_formatting.dart';
import '../utils/platform_paths.dart';
import '../l10n/generated/app_localizations.dart';

class DownloadCacheController {
  final LibraryState library;
  final PlaybackState playback;
  final SelectionState selection;
  final YoutubeBackend ytDlpService;
  final ThemeState themeState;
  final Future<void> Function() saveMedia;
  final void Function(String message, {IconData icon, Color? iconColor, bool persistent}) showAppToast;
  final void Function(String path, YtSearchResult video, File realFile) completeTrackMetadata;
  final bool Function() isMounted;
  final VoidCallback requestRebuild;
  final AppLocalizations Function() l10n;
  final Future<bool> Function() networkAllowsDownloads;

  DownloadCacheController({
    required this.library,
    required this.playback,
    required this.selection,
    required this.ytDlpService,
    required this.themeState,
    required this.saveMedia,
    required this.showAppToast,
    required this.completeTrackMetadata,
    required this.isMounted,
    required this.requestRebuild,
    required this.l10n,
    required this.networkAllowsDownloads,
  });

  Future<bool> _checkNetworkForDownload() async {
    if (await networkAllowsDownloads()) return true;
    showAppToast(l10n().wifiRequiredForDownloadToast, icon: Icons.wifi_off, iconColor: Colors.orangeAccent);
    return false;
  }

  Future<int> _flatDirectorySize(Directory dir) async {
    var total = 0;
    try {
      if (!await dir.exists()) return 0;
      await for (final entry in dir.list(followLinks: false)) {
        if (entry is File) total += await entry.length();
      }
    } catch (_) {}
    return total;
  }

  Future<({int downloads, int cache})> storageUsage() async =>
      (downloads: await _flatDirectorySize(onlineDownloadsDir), cache: await _flatDirectorySize(previewCacheDir));

  Future<void> clearOnlineCache() async {
    final dir = previewCacheDir;
    if (!await dir.exists()) return;
    final current = playback.currentPlayingPath;
    final inUse = <String>{
      if (current != null && isOnlineTrack(current)) fullCacheFilePath(current.substring('online:'.length)).path,
      ?playback.previewTempPath,
    };
    await for (final entry in dir.list(followLinks: false)) {
      if (entry is! File || inUse.contains(entry.path)) continue;
      try {
        await entry.delete();
      } catch (_) {}
    }
  }

  String? customDownloadDir;
  String? customCacheDir;

  Directory get onlineDownloadsDir {
    final custom = customDownloadDir;
    if (custom != null && custom.isNotEmpty) return Directory(custom);
    return Directory(defaultDownloadsPath());
  }

  String sanitizeFileNamePart(String name) {
    return name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '').trim();
  }

  Future<String> resolveYoutubeVideoId(YtSearchResult video) async {
    if (!video.id.startsWith('spotify:')) return video.id;
    final primaryQuery = '${video.title} ${video.author} audio';
    final fallbackQuery = '${video.title} ${video.author}';
    final matches = await ytDlpService.searchWithFallback(primaryQuery, fallbackQuery);
    if (matches.isEmpty) {
      throw Exception('Aucune correspondance YouTube trouvée pour "${video.title}" de ${video.author}.');
    }
    return matches.first.id;
  }

  Future<void> tagDownloadedFile(String mp3Path, YtSearchResult video) async {
    try {
      final ffmpegPath = await ytDlpService.resolveFfmpegPath();
      if (ffmpegPath == null) return;
      await MetadataTagger(ffmpegPath).tagMp3(
        filePath: mp3Path,
        title: video.title,
        artist: video.author,
        album: video.album,
        year: video.releaseYear,
        coverImageUrl: video.thumbnailUrl.isNotEmpty ? video.thumbnailUrl : null,
      );
    } catch (e) {
      debugPrint('Tagging ID3 échoué (fichier conservé sans tags) : $e');
    }
  }

  Future<String> downloadTrackToLibrary(YtSearchResult video, {void Function(double)? onProgress}) async {
    final dir = onlineDownloadsDir;
    if (!await dir.exists()) await dir.create(recursive: true);
    final baseName = '${sanitizeFileNamePart(video.author)} - ${sanitizeFileNamePart(video.title)}';
    final audioFile = File('${dir.path}${Platform.pathSeparator}$baseName.${ytDlpService.audioExtension}');
    if (await audioFile.exists()) {
      return audioFile.path;
    }
    final youtubeId = await resolveYoutubeVideoId(video);
    final outputTemplate = '${dir.path}${Platform.pathSeparator}$baseName.%(ext)s';
    try {
      await ytDlpService.downloadAudio(
        youtubeId,
        outputTemplate,
        perAttemptTimeout: const Duration(seconds: 45),
        onProgress: onProgress,
      );
    } finally {
      await deleteDownloadLeftovers(dir, baseName);
    }
    if (!await audioFile.exists()) {
      throw Exception('Échec du téléchargement.');
    }
    await tagDownloadedFile(audioFile.path, video);
    if (Platform.isAndroid) {
      unawaited(AndroidMediaStoreService.publishAudio(
        sourcePath: audioFile.path,
        fileName: '$baseName.${ytDlpService.audioExtension}',
        title: video.title,
        artist: video.author,
        album: video.album,
      ));
    }
    unawaited(deleteCachedPreviewSnippet(youtubeId));
    unawaited(deleteCachedFullPlaybackFile(youtubeId));
    return audioFile.path;
  }

  Future<void> deleteCachedPreviewSnippet(String youtubeVideoId) async {
    final file = File('${previewCacheDir.path}${Platform.pathSeparator}${previewSnippetBaseName(youtubeVideoId)}.${ytDlpService.audioExtension}');
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  Future<void> deleteCachedFullPlaybackFile(String youtubeVideoId) async {
    final file = fullCacheFilePath(youtubeVideoId);
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  Future<void> deleteOrphanedDownload(String path) async {
    if (path.startsWith(onlineDownloadsDir.path)) {
      final file = File(path);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
      return;
    }
    if (path.startsWith('online:')) {
      final id = path.substring('online:'.length);
      await deleteCachedPreviewSnippet(id);
      await deleteCachedFullPlaybackFile(id);
    }
  }

  Future<void> deleteDownloadLeftovers(Directory dir, String baseName) async {
    try {
      await for (final entry in dir.list()) {
        if (entry is File) {
          final name = entry.uri.pathSegments.last;
          if (name.startsWith(baseName) && !name.toLowerCase().endsWith('.${ytDlpService.audioExtension}')) {
            try {
              await entry.delete();
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
  }

  String get defaultCacheBase => defaultCacheBasePath();

  Directory get previewCacheDir {
    final custom = customCacheDir;
    final base = custom != null && custom.isNotEmpty ? custom : defaultCacheBase;
    return Directory('$base${Platform.pathSeparator}yora_online');
  }

  File fullCacheFilePath(String youtubeId) => File('${previewCacheDir.path}${Platform.pathSeparator}$youtubeId.${ytDlpService.audioExtension}');

  Future<File> downloadForPlaybackCache(String youtubeVideoId) async {
    final dir = previewCacheDir;
    if (!await dir.exists()) await dir.create(recursive: true);
    final tempFile = fullCacheFilePath(youtubeVideoId);
    if (await tempFile.exists()) return tempFile;
    final outputTemplate = '${dir.path}${Platform.pathSeparator}$youtubeVideoId.%(ext)s';
    try {
      await ytDlpService.downloadAudio(
        youtubeVideoId,
        outputTemplate,
        perAttemptTimeout: const Duration(seconds: 45),
      );
    } finally {
      await deleteDownloadLeftovers(dir, youtubeVideoId);
    }
    if (!await tempFile.exists()) {
      throw Exception('Échec du téléchargement de l\'aperçu.');
    }
    return tempFile;
  }

  static const previewClipDuration = Duration(seconds: 8);

  String previewSnippetBaseName(String youtubeVideoId) => '$youtubeVideoId.preview8';

  Duration previewStartOffset(int? trackDurationMs) {
    if (trackDurationMs == null || trackDurationMs <= 0) return Duration.zero;
    final total = Duration(milliseconds: trackDurationMs);
    if (total <= previewClipDuration) return Duration.zero;
    final target = Duration(seconds: (total.inSeconds * 0.35).round());
    final maxStart = total - previewClipDuration;
    return target > maxStart ? maxStart : target;
  }

  Future<File> downloadPreviewSnippet(String youtubeVideoId, {int? trackDurationMs}) async {
    final dir = previewCacheDir;
    if (!await dir.exists()) await dir.create(recursive: true);
    final baseName = previewSnippetBaseName(youtubeVideoId);
    final tempFile = File('${dir.path}${Platform.pathSeparator}$baseName.${ytDlpService.audioExtension}');
    if (await tempFile.exists()) return tempFile;
    final outputTemplate = '${dir.path}${Platform.pathSeparator}$baseName.%(ext)s';
    try {
      await ytDlpService.downloadAudioClip(
        youtubeVideoId,
        outputTemplate,
        maxDuration: previewClipDuration,
        startOffset: previewStartOffset(trackDurationMs),
        perAttemptTimeout: const Duration(seconds: 20),
      );
    } finally {
      await deleteDownloadLeftovers(dir, baseName);
    }
    if (!await tempFile.exists()) {
      throw Exception('Échec du téléchargement de l\'aperçu.');
    }
    return tempFile;
  }

  static const _rewarmMaxConcurrent = 2;
  final List<MapEntry<String, YtSearchResult>> _rewarmQueue = [];
  final Set<String> _rewarmQueuedPaths = {};
  int _rewarmActiveWorkers = 0;

  Future<void> rewarmMissingOnlineCaches() async {
    if (!await networkAllowsDownloads()) return;
    var added = false;
    for (final playlist in library.musicPlaylists.values) {
      for (final path in playlist['tracks'] as List<String>) {
        if (!isOnlineTrack(path)) continue;
        if (_rewarmQueuedPaths.contains(path) || library.cachingTracks.contains(path)) continue;
        final meta = library.trackMetadata[path];
        if (meta?['unavailable'] == 'true') continue;
        final video = YtSearchResult(
          id: path.substring('online:'.length),
          title: meta?['title'] ?? '',
          author: meta?['author'] ?? '',
          thumbnailUrl: meta?['thumbnailUrl'] ?? '',
          album: meta?['album'],
          releaseYear: meta?['year'],
        );
        library.cachingTracks.add(path);
        added = true;
        unawaited(_checkOrQueueRewarm(path, video));
      }
    }
    if (added) requestRebuild();
  }

  Future<void> _checkOrQueueRewarm(String path, YtSearchResult video) async {
    final youtubeId = video.id.startsWith('spotify:') ? null : video.id;
    if (youtubeId != null && await fullCacheFilePath(youtubeId).exists()) {
      library.cachingTracks.remove(path);
      requestRebuild();
      return;
    }
    _rewarmQueue.add(MapEntry(path, video));
    _rewarmQueuedPaths.add(path);
    while (_rewarmActiveWorkers < _rewarmMaxConcurrent && _rewarmQueue.isNotEmpty) {
      _rewarmActiveWorkers++;
      unawaited(_runRewarmWorker());
    }
  }

  void prioritizeRewarm(String path) {
    final index = _rewarmQueue.indexWhere((e) => e.key == path);
    if (index <= 0) return;
    final entry = _rewarmQueue.removeAt(index);
    _rewarmQueue.insert(0, entry);
  }

  Future<void> _runRewarmWorker() async {
    while (isMounted() && _rewarmQueue.isNotEmpty) {
      final entry = _rewarmQueue.removeAt(0);
      _rewarmQueuedPaths.remove(entry.key);
      final path = entry.key;
      final video = entry.value;
      try {
        final youtubeId = await resolveYoutubeVideoId(video);
        final cacheFile = fullCacheFilePath(youtubeId);
        if (!await cacheFile.exists()) {
          final file = await fullCacheFor(youtubeId);
          completeTrackMetadata(path, video, file);
        }
      } catch (e) {
        if (isPermanentlyUnavailableError(e)) {
          final updated = Map<String, String>.from(library.trackMetadata[path] ?? {});
          updated['unavailable'] = 'true';
          library.trackMetadata[path] = updated;
          unawaited(saveMedia());
        }
      } finally {
        library.cachingTracks.remove(path);
        requestRebuild();
      }
    }
    _rewarmActiveWorkers--;
  }

  final Map<String, Future<File>> fullCacheInFlight = {};

  Future<File> fullCacheFor(String youtubeId) {
    return fullCacheInFlight.putIfAbsent(youtubeId, () async {
      try {
        return await downloadForPlaybackCache(youtubeId);
      } finally {
        fullCacheInFlight.remove(youtubeId);
      }
    });
  }

  void prefetchFullPlaybackCache(YtSearchResult video) {
    final path = 'online:${video.id}';
    library.cachingTracks.add(path);
    requestRebuild();
    unawaited(() async {
      try {
        if (!await networkAllowsDownloads()) return;
        final youtubeId = await resolveYoutubeVideoId(video);
        final file = await fullCacheFor(youtubeId);
        completeTrackMetadata(path, video, file);
      } catch (e) {
        debugPrint('Pré-téléchargement de la piste échoué pour "${video.title}" : $e');
      } finally {
        library.cachingTracks.remove(path);
        requestRebuild();
      }
    }());
  }

  Future<bool> downloadSingleOnlineTrack(String onlinePath) async {
    final videoId = onlinePath.substring('online:'.length);
    final meta = library.trackMetadata[onlinePath];
    final video = YtSearchResult(
      id: videoId,
      title: meta?['title'] ?? '',
      author: meta?['author'] ?? '',
      thumbnailUrl: meta?['thumbnailUrl'] ?? '',
      album: meta?['album'],
      releaseYear: meta?['year'],
      durationMs: int.tryParse(meta?['durationMs'] ?? ''),
    );
    try {
      final path = await downloadTrackToLibrary(video);
      if (isMounted()) {
        if (!library.musicPaths.contains(path)) library.musicPaths.add(path);
        library.trackMetadata[path] = metadataMap(video);
        final originalAddedDate = library.trackAddedDates[onlinePath];
        if (originalAddedDate != null) library.trackAddedDates[path] = originalAddedDate;
        for (final playlist in library.musicPlaylists.values) {
          final playlistTracks = playlist['tracks'] as List<String>;
          for (var i = 0; i < playlistTracks.length; i++) {
            if (playlistTracks[i] == onlinePath) playlistTracks[i] = path;
          }
        }
        library.trackMetadata.remove(onlinePath);
        library.trackAddedDates.remove(onlinePath);
        if (playback.currentPlayingPath == onlinePath) playback.currentPlayingPath = path;
        completeTrackMetadata(path, video, File(path));
        await saveMedia();
      }
      return true;
    } catch (e) {
      debugPrint('Échec du téléchargement de "${video.title}" : $e');
      if (isPermanentlyUnavailableError(e)) {
        final updated = Map<String, String>.from(library.trackMetadata[onlinePath] ?? {});
        updated['unavailable'] = 'true';
        library.trackMetadata[onlinePath] = updated;
        if (isMounted()) await saveMedia();
      }
      return false;
    }
  }

  Future<void> downloadAllOnlineTracksInPlaylist(String playlistName) async {
    if (!await _checkNetworkForDownload()) return;
    final tracks = library.musicPlaylists[playlistName]?['tracks'] as List<String>?;
    final onlinePaths = tracks?.where(isOnlineTrack).toSet().toList() ?? const <String>[];
    if (onlinePaths.isEmpty) {
      showAppToast(
        l10n().allTracksAlreadyDownloadedToast,
        icon: Icons.check_circle,
        iconColor: themeState.accent,
      );
      return;
    }

    final total = onlinePaths.length;
    var completed = 0;
    var failed = 0;
    showAppToast(
      l10n().downloadingPlaylistProgressToast(0, total),
      icon: Icons.downloading,
      persistent: true,
    );

    for (final onlinePath in onlinePaths) {
      final meta = library.trackMetadata[onlinePath];
      if (meta?['unavailable'] == 'true') {
        failed++;
      } else if (await downloadSingleOnlineTrack(onlinePath)) {
        completed++;
      } else {
        failed++;
      }
      showAppToast(
        l10n().downloadingPlaylistProgressToast(completed + failed, total),
        icon: Icons.downloading,
        persistent: true,
      );
    }

    showAppToast(
      failed == 0
          ? l10n().playlistFullyDownloadedToast(completed)
          : l10n().tracksDownloadedWithFailuresToast(completed, failed),
      icon: failed == 0 ? Icons.check_circle : Icons.error_outline,
      iconColor: failed == 0 ? themeState.accent : Colors.orangeAccent,
    );
  }

  String? downloadingTrackPath;
  bool bulkDownloadInProgress = false;

  Future<void> downloadCurrentTrackToLibrary() async {
    if (downloadingTrackPath != null || bulkDownloadInProgress) return;
    if (selection.selectedTrackPaths.length > 1) {
      await downloadSelectedTracksToLibrary();
      return;
    }
    final path = playback.currentPlayingPath;
    if (path == null || !isOnlineTrack(path)) return;
    await downloadTrackFromMenu(path);
  }

  Future<void> downloadTrackFromMenu(String path) async {
    if (downloadingTrackPath != null || bulkDownloadInProgress) return;
    if (!isOnlineTrack(path)) return;
    if (!await _checkNetworkForDownload()) return;
    downloadingTrackPath = path;
    requestRebuild();
    final ok = await downloadSingleOnlineTrack(path);
    if (isMounted()) downloadingTrackPath = null;
    showAppToast(
      ok ? l10n().downloadedTrackToast : l10n().downloadFailedToast,
      icon: ok ? Icons.check_circle : Icons.error_outline,
      iconColor: ok ? themeState.accent : Colors.redAccent,
    );
  }

  Future<void> downloadSelectedTracksToLibrary() async {
    if (!await _checkNetworkForDownload()) return;
    final onlinePaths = selection.selectedTrackPaths.where(isOnlineTrack).toList();
    if (onlinePaths.isEmpty) {
      showAppToast(
        l10n().selectedTracksAlreadyDownloadedToast,
        icon: Icons.check_circle,
        iconColor: themeState.accent,
      );
      return;
    }
    bulkDownloadInProgress = true;
    final total = onlinePaths.length;
    var completed = 0;
    var failed = 0;
    showAppToast(
      l10n().downloadingTracksProgressToast(0, total),
      icon: Icons.downloading,
      persistent: true,
    );
    for (final path in onlinePaths) {
      final meta = library.trackMetadata[path];
      if (meta?['unavailable'] == 'true') {
        failed++;
      } else {
        downloadingTrackPath = path;
        requestRebuild();
        if (await downloadSingleOnlineTrack(path)) {
          completed++;
        } else {
          failed++;
        }
      }
      showAppToast(
        l10n().downloadingTracksProgressToast(completed + failed, total),
        icon: Icons.downloading,
        persistent: true,
      );
    }
    if (isMounted()) {
      downloadingTrackPath = null;
      bulkDownloadInProgress = false;
    }
    showAppToast(
      failed == 0
          ? l10n().tracksDownloadedToast(completed)
          : l10n().tracksDownloadedWithFailuresToast(completed, failed),
      icon: failed == 0 ? Icons.check_circle : Icons.error_outline,
      iconColor: failed == 0 ? themeState.accent : Colors.orangeAccent,
    );
  }
}
