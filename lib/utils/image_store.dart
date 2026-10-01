import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'platform_paths.dart';

const String profileImageKey = 'profileImagePath';
const String playlistsDataKey = 'playlistsData';

String imageFileName(String path) => path.split(RegExp(r'[\\/]')).last;

Future<Directory> _imagesDirectory() async {
  final base = await getApplicationSupportDirectory();
  final dir = Directory(joinPath([base.path, 'images']));
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir;
}

Future<String> storeImageBytes(List<int> bytes, String originalName) async {
  final dir = await _imagesDirectory();
  final safeName = originalName.replaceAll(RegExp(r'[^\w.\-]'), '_');
  final file = File(joinPath([dir.path, '${DateTime.now().microsecondsSinceEpoch}_$safeName']));
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

Future<String> keepPermanentImageCopy(String path) async {
  final dir = await _imagesDirectory();
  if (path.startsWith(dir.path)) return path;
  return storeImageBytes(await File(path).readAsBytes(), imageFileName(path));
}

List<String> referencedImagePaths(Map<String, Object?> preferences) {
  final paths = <String>[];
  final profile = preferences[profileImageKey];
  if (profile is String && profile.isNotEmpty) paths.add(profile);
  final playlists = preferences[playlistsDataKey];
  if (playlists is String) {
    try {
      final decoded = jsonDecode(playlists);
      if (decoded is Map) {
        for (final value in decoded.values) {
          final image = value is Map ? value['image'] : null;
          if (image is String && image.isNotEmpty) paths.add(image);
        }
      }
    } catch (_) {}
  }
  return paths.toSet().toList();
}

Future<Map<String, Map<String, String>>> encodeImagesForBackup(Map<String, Object?> preferences) async {
  final images = <String, Map<String, String>>{};
  for (final path in referencedImagePaths(preferences)) {
    try {
      final file = File(path);
      if (!await file.exists()) continue;
      images[path] = {'name': imageFileName(path), 'data': base64Encode(await file.readAsBytes())};
    } catch (_) {}
  }
  return images;
}

Future<void> restoreMissingImages(Map<dynamic, dynamic> backupImages) async {
  final prefs = await SharedPreferences.getInstance();
  final current = <String, Object?>{
    profileImageKey: prefs.getString(profileImageKey),
    playlistsDataKey: prefs.getString(playlistsDataKey),
  };
  final replacements = <String, String>{};
  for (final path in referencedImagePaths(current)) {
    if (await File(path).exists()) continue;
    var entry = backupImages[path];
    if (entry is! Map) {
      final name = imageFileName(path);
      for (final candidate in backupImages.values) {
        if (candidate is Map && candidate['name'] == name) {
          entry = candidate;
          break;
        }
      }
    }
    if (entry is! Map || entry['data'] is! String) continue;
    try {
      final name = entry['name'] is String ? entry['name'] as String : imageFileName(path);
      replacements[path] = await storeImageBytes(base64Decode(entry['data'] as String), name);
    } catch (_) {}
  }
  if (replacements.isEmpty) return;
  final profile = prefs.getString(profileImageKey);
  if (profile != null && replacements.containsKey(profile)) {
    await prefs.setString(profileImageKey, replacements[profile]!);
  }
  final playlists = prefs.getString(playlistsDataKey);
  if (playlists == null) return;
  try {
    final decoded = jsonDecode(playlists);
    if (decoded is! Map) return;
    var changed = false;
    for (final value in decoded.values) {
      final image = value is Map ? value['image'] : null;
      if (image is String && replacements.containsKey(image)) {
        value['image'] = replacements[image];
        changed = true;
      }
    }
    if (changed) await prefs.setString(playlistsDataKey, jsonEncode(decoded));
  } catch (_) {}
}
