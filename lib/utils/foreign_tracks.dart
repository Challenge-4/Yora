import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'platform_paths.dart';

const _onlineSchemes = ['online:', 'preview:', 'spotify:', 'youtube:'];
final RegExp _windowsPath = RegExp(r'^[A-Za-z]:[\\/]|\\');

bool _isLocalTrack(String path) => !_onlineSchemes.any(path.startsWith);

bool _isRestorableAndroidDownload(String path) =>
    Platform.isAndroid && path.startsWith(defaultDownloadsPath() + Platform.pathSeparator);

bool isMissingLocalTrack(String path) =>
    _isLocalTrack(path) && !File(path).existsSync() && !_isRestorableAndroidDownload(path);

bool isOtherSystemLocalTrack(String path) => _isLocalTrack(path) && isMobile && _windowsPath.hasMatch(path);

Future<void> dropCustomFoldersFromOtherDevices() async {
  final prefs = await SharedPreferences.getInstance();
  for (final key in ['customDownloadDir', 'customCacheDir']) {
    final value = prefs.getString(key);
    if (value == null) continue;
    if (isMobile || !Directory(value).existsSync()) await prefs.remove(key);
  }
}

Future<void> removeForeignLocalTracks(bool Function(String path) isForeign) async {
  final prefs = await SharedPreferences.getInstance();
  Map<String, dynamic>? readMap(String key) {
    final raw = prefs.getString(key);
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  for (final key in ['musicPaths', 'pendingOrphanCleanupPaths']) {
    final paths = prefs.getStringList(key);
    if (paths != null && paths.any(isForeign)) {
      await prefs.setStringList(key, paths.where((path) => !isForeign(path)).toList());
    }
  }

  final playlists = readMap('playlistsData');
  if (playlists != null) {
    var changed = false;
    for (final entry in playlists.entries) {
      final value = entry.value;
      if (value is! Map || value['tracks'] is! List) continue;
      final tracks = List<String>.from(value['tracks'] as List);
      if (!tracks.any(isForeign)) continue;
      playlists[entry.key] = {...value, 'tracks': tracks.where((path) => !isForeign(path)).toList()};
      changed = true;
    }
    if (changed) await prefs.setString('playlistsData', jsonEncode(playlists));
  }

  for (final key in ['trackMetadata', 'trackAddedDates', 'trackLastPlayedDates', 'trackDurationsMs']) {
    final map = readMap(key);
    if (map == null || !map.keys.any(isForeign)) continue;
    map.removeWhere((path, _) => isForeign(path));
    await prefs.setString(key, jsonEncode(map));
  }

  List<String>? queue;
  try {
    final rawQueue = prefs.getString('lastSessionQueue');
    if (rawQueue != null) queue = List<String>.from(jsonDecode(rawQueue) as List);
  } catch (_) {}
  if (queue != null && queue.any(isForeign)) {
    final index = prefs.getInt('lastSessionQueueIndex') ?? -1;
    final current = index >= 0 && index < queue.length && !isForeign(queue[index]) ? queue[index] : null;
    final kept = queue.where((path) => !isForeign(path)).toList();
    await prefs.setString('lastSessionQueue', jsonEncode(kept));
    await prefs.setInt('lastSessionQueueIndex', current == null ? -1 : kept.indexOf(current));
  }

  final lastPath = prefs.getString('lastSessionPath');
  if (lastPath != null && isForeign(lastPath)) await prefs.remove('lastSessionPath');
}
