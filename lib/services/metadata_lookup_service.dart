import 'dart:convert';
import 'package:http/http.dart' as http;

class AlbumLookupResult {
  final String? album;
  final String? releaseYear;
  const AlbumLookupResult({this.album, this.releaseYear});
}

class MetadataLookupService {
  DateTime? _lastMusicBrainzRequest;

  Future<AlbumLookupResult?> lookupAlbum(String title, String artist) async {
    final fromItunes = await _lookupItunes(title, artist);
    if (fromItunes != null) return fromItunes;
    return _lookupMusicBrainz(title, artist);
  }

  Future<AlbumLookupResult?> _lookupItunes(String title, String artist) async {
    final term = artist.isNotEmpty ? '$artist $title' : title;
    final uri = Uri.https('itunes.apple.com', '/search', {
      'term': term,
      'media': 'music',
      'entity': 'song',
      'limit': '1',
    });
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final results = json['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) return null;
      final first = results.first as Map<String, dynamic>;
      final album = first['collectionName'] as String?;
      final releaseDate = first['releaseDate'] as String?;
      final year = (releaseDate != null && releaseDate.length >= 4) ? releaseDate.substring(0, 4) : null;
      if ((album == null || album.isEmpty) && year == null) return null;
      return AlbumLookupResult(
        album: (album != null && album.isNotEmpty) ? album : null,
        releaseYear: year,
      );
    } catch (_) {
      return null;
    }
  }

  static const _musicBrainzUserAgent = 'Yora/1.0 (yora desktop app)';

  Future<void> _respectMusicBrainzRateLimit() async {
    final last = _lastMusicBrainzRequest;
    if (last == null) return;
    final remaining = const Duration(seconds: 1) - DateTime.now().difference(last);
    if (remaining > Duration.zero) await Future.delayed(remaining);
  }

  String _escapeLucene(String value) => value.replaceAll('\\', '\\\\').replaceAll('"', '\\"');

  Future<AlbumLookupResult?> _lookupMusicBrainz(String title, String artist) async {
    await _respectMusicBrainzRateLimit();
    final query = artist.isNotEmpty
        ? 'recording:"${_escapeLucene(title)}" AND artist:"${_escapeLucene(artist)}"'
        : 'recording:"${_escapeLucene(title)}"';
    final uri = Uri.https('musicbrainz.org', '/ws/2/recording/', {
      'query': query,
      'fmt': 'json',
      'limit': '1',
    });
    try {
      final response = await http
          .get(uri, headers: {'User-Agent': _musicBrainzUserAgent})
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final recordings = json['recordings'] as List<dynamic>?;
      if (recordings == null || recordings.isEmpty) return null;
      final releases = (recordings.first as Map<String, dynamic>)['releases'] as List<dynamic>?;
      if (releases == null || releases.isEmpty) return null;
      final release = releases.first as Map<String, dynamic>;
      final album = release['title'] as String?;
      final date = release['date'] as String?;
      final year = (date != null && date.length >= 4) ? date.substring(0, 4) : null;
      if ((album == null || album.isEmpty) && year == null) return null;
      return AlbumLookupResult(
        album: (album != null && album.isNotEmpty) ? album : null,
        releaseYear: year,
      );
    } catch (_) {
      return null;
    } finally {
      _lastMusicBrainzRequest = DateTime.now();
    }
  }
}
