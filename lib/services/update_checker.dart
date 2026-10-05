import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AvailableUpdate {
  final String version;
  final String url;

  const AvailableUpdate(this.version, this.url);
}

const _latestReleaseApi = 'https://api.github.com/repos/Challenge-4/Yora/releases/latest';
const _checkedAtKey = 'updateCheckedAt';
const _latestTagKey = 'latestReleaseTag';
const _latestUrlKey = 'latestReleaseUrl';
const _checkInterval = Duration(hours: 24);

List<int> _versionParts(String version) {
  final core = version.trim().replaceFirst(RegExp(r'^[vV]'), '').split(RegExp(r'[+-]')).first;
  final parts = core.split('.').map((part) => int.tryParse(part) ?? 0).toList();
  while (parts.length < 3) {
    parts.add(0);
  }
  return parts;
}

bool isNewerVersion(String candidate, String current) {
  final a = _versionParts(candidate);
  final b = _versionParts(current);
  for (var i = 0; i < 3; i++) {
    if (a[i] != b[i]) return a[i] > b[i];
  }
  return false;
}

Future<AvailableUpdate?> checkForUpdate(String currentVersion) async {
  final prefs = await SharedPreferences.getInstance();
  var tag = prefs.getString(_latestTagKey);
  var url = prefs.getString(_latestUrlKey);
  final checkedAt = DateTime.tryParse(prefs.getString(_checkedAtKey) ?? '');
  if (tag == null || url == null || checkedAt == null || DateTime.now().difference(checkedAt) > _checkInterval) {
    try {
      final response = await http.get(
        Uri.parse(_latestReleaseApi),
        headers: {'Accept': 'application/vnd.github+json', 'User-Agent': 'Yora'},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newTag = data is Map ? data['tag_name'] : null;
        final newUrl = data is Map ? data['html_url'] : null;
        if (newTag is String && newUrl is String) {
          tag = newTag;
          url = newUrl;
          await prefs.setString(_latestTagKey, newTag);
          await prefs.setString(_latestUrlKey, newUrl);
          await prefs.setString(_checkedAtKey, DateTime.now().toIso8601String());
        }
      }
    } catch (_) {}
  }
  if (tag == null || url == null || !isNewerVersion(tag, currentVersion)) return null;
  return AvailableUpdate(tag.replaceFirst(RegExp(r'^[vV]'), ''), url);
}
