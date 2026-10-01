import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

String? _mobileDownloadsPath;
String? _mobileCachePath;
String? _legacyAndroidDownloadsPath;

Future<void> initMobilePaths() async {
  if (!(Platform.isAndroid || Platform.isIOS)) return;
  final documents = await getApplicationDocumentsDirectory();
  if (Platform.isIOS) {
    _mobileDownloadsPath = joinPath([documents.path, 'Downloads']);
    _mobileCachePath = joinPath([(await getApplicationCacheDirectory()).path, 'Yora']);
    _iosContainerPath = documents.parent.path;
    await relocateIosContainerPaths();
    return;
  }
  final support = await getApplicationSupportDirectory();
  final legacyDownloads = joinPath([documents.path, 'Yora']);
  final legacyCache = joinPath([support.path, 'Yora']);
  final external = Platform.isAndroid ? await getExternalStorageDirectory() : null;
  if (external == null) {
    _mobileDownloadsPath = legacyDownloads;
    _mobileCachePath = legacyCache;
    return;
  }
  _mobileDownloadsPath = joinPath([external.path, 'Downloads']);
  _mobileCachePath = joinPath([external.path, 'Cache']);
  _legacyAndroidDownloadsPath = legacyDownloads;
  await _migrateLegacyAndroidStorage(legacyDownloads, legacyCache);
}

String? _iosContainerPath;
final RegExp _iosContainerPattern = RegExp(r'(?:/private)?/var/mobile/Containers/Data/Application/[0-9A-Fa-f-]{36}');

String relocateIosContainerPath(String value, String currentContainer) =>
    value.replaceAll(_iosContainerPattern, currentContainer);

Future<void> relocateIosContainerPaths() async {
  final current = _iosContainerPath;
  if (current == null) return;
  final prefs = await SharedPreferences.getInstance();
  for (final key in prefs.getKeys()) {
    final value = prefs.get(key);
    if (value is String) {
      final updated = relocateIosContainerPath(value, current);
      if (updated != value) await prefs.setString(key, updated);
    } else if (value is List) {
      final list = value.cast<String>();
      final updated = [for (final s in list) relocateIosContainerPath(s, current)];
      if (updated.join('\u0000') != list.join('\u0000')) await prefs.setStringList(key, updated);
    }
  }
}

Future<void> rewriteLegacyAndroidDownloadPaths() async {
  final legacy = _legacyAndroidDownloadsPath;
  final current = _mobileDownloadsPath;
  if (legacy == null || current == null) return;
  await _replacePathPrefixInPrefs(legacy, current);
}

Future<void> _replacePathPrefixInPrefs(String from, String to) async {
  final prefs = await SharedPreferences.getInstance();
  for (final key in prefs.getKeys()) {
    final value = prefs.get(key);
    if (value is String && value.contains(from)) {
      await prefs.setString(key, value.replaceAll(from, to));
    } else if (value is List) {
      final list = value.cast<String>();
      if (list.any((s) => s.contains(from))) {
        await prefs.setStringList(key, [for (final s in list) s.replaceAll(from, to)]);
      }
    }
  }
}

Future<void> _migrateLegacyAndroidStorage(String legacyDownloads, String legacyCache) async {
  final oldCache = Directory(legacyCache);
  if (await oldCache.exists()) {
    unawaited(oldCache.delete(recursive: true).then((_) {}, onError: (_) {}));
  }
  final oldDownloads = Directory(legacyDownloads);
  if (!await oldDownloads.exists()) return;
  final newDownloadsPath = _mobileDownloadsPath!;
  await Directory(newDownloadsPath).create(recursive: true);
  await for (final entry in oldDownloads.list()) {
    if (entry is! File) continue;
    await entry.copy(joinPath([newDownloadsPath, entry.path.split(Platform.pathSeparator).last]));
    await entry.delete();
  }
  await _replacePathPrefixInPrefs(legacyDownloads, newDownloadsPath);
  await oldDownloads.delete(recursive: true);
}

String? get homeDirectory =>
    Platform.isWindows ? Platform.environment['USERPROFILE'] : Platform.environment['HOME'];

String joinPath(Iterable<String> parts) => parts.join(Platform.pathSeparator);

String defaultDownloadsPath() {
  final mobile = _mobileDownloadsPath;
  if (mobile != null) return mobile;
  final home = homeDirectory;
  return home != null
      ? joinPath([home, 'Music', 'Yora'])
      : joinPath([Directory.systemTemp.path, 'Yora']);
}

String defaultCacheBasePath() {
  final mobile = _mobileCachePath;
  if (mobile != null) return mobile;
  final home = homeDirectory;
  if (Platform.isWindows) {
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData != null && localAppData.isNotEmpty) return joinPath([localAppData, 'Yora']);
    if (home != null && home.isNotEmpty) return joinPath([home, 'AppData', 'Local', 'Yora']);
  } else if (Platform.isMacOS) {
    if (home != null && home.isNotEmpty) return joinPath([home, 'Library', 'Caches', 'Yora']);
  } else {
    final xdgCache = Platform.environment['XDG_CACHE_HOME'];
    if (xdgCache != null && xdgCache.isNotEmpty) return joinPath([xdgCache, 'Yora']);
    if (home != null && home.isNotEmpty) return joinPath([home, '.cache', 'Yora']);
  }
  return Directory.systemTemp.path;
}

String? defaultDocumentsPath() {
  final home = homeDirectory;
  return home == null ? null : joinPath([home, 'Documents']);
}

String executableName(String base) => Platform.isWindows ? '$base.exe' : base;

bool get isDesktopMac => Platform.isMacOS;

bool get isDesktop => Platform.isWindows || Platform.isMacOS || Platform.isLinux;

bool get isMobile => Platform.isAndroid || Platform.isIOS;
