import 'dart:convert';
import 'package:http/http.dart' as http;
import 'youtube_backend.dart';

class ImportedTrack {
  final String title;
  final String artist;
  final String? album;
  final String? youtubeId;
  final String? thumbnailUrl;
  const ImportedTrack({
    required this.title,
    required this.artist,
    this.album,
    this.youtubeId,
    this.thumbnailUrl,
  });
}

class ImportedPlaylist {
  final String name;
  final String sourceLabel;
  final List<ImportedTrack> tracks;
  const ImportedPlaylist({required this.name, required this.sourceLabel, required this.tracks});
}

class PlaylistImportService {
  final YoutubeBackend _ytDlpService;
  const PlaylistImportService(this._ytDlpService);

  Future<ImportedPlaylist> importFromUrl(String url) async {
    final trimmed = url.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.host.isEmpty) {
      throw Exception('Lien invalide.');
    }
    final host = uri.host.toLowerCase();
    if (host.contains('youtube.com') || host.contains('youtu.be')) {
      final (title, ytTracks) = await _ytDlpService.fetchPlaylist(trimmed);
      return ImportedPlaylist(
        name: title,
        sourceLabel: 'YouTube',
        tracks: ytTracks
            .map((t) => ImportedTrack(
                  title: t.title,
                  artist: t.author,
                  youtubeId: t.id,
                  thumbnailUrl: t.thumbnailUrl,
                ))
            .toList(),
      );
    }
    if (host.contains('deezer.com') || host.contains('deezer.page.link')) {
      return _importFromDeezer(trimmed);
    }
    if (host.contains('spotify.com') || host.contains('spotify.link')) {
      return _importFromSpotify(trimmed);
    }
    throw Exception('Lien non reconnu : seuls les liens YouTube, Deezer et Spotify sont supportés.');
  }

  static final _playlistIdPattern = RegExp(r'playlist[/:](\d+)');
  static final _spotifyPlaylistIdPattern = RegExp(r'playlist[/:]([A-Za-z0-9]+)');

  static final _canonicalUrlPattern = RegExp(r'<link rel="canonical" href="([^"]+)"');
  static final _ogUrlPattern = RegExp(r'<meta property="og:url" content="([^"]+)"');
  static String? _finalUrlFromHtml(String html) {
    return _canonicalUrlPattern.firstMatch(html)?.group(1) ?? _ogUrlPattern.firstMatch(html)?.group(1);
  }

  Future<String> _resolveDeezerPlaylistId(String url) async {
    final direct = _playlistIdPattern.firstMatch(url);
    if (direct != null) return direct.group(1)!;
    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
    final finalUrl = _finalUrlFromHtml(response.body);
    final resolved = finalUrl != null ? _playlistIdPattern.firstMatch(finalUrl) : null;
    if (resolved != null) return resolved.group(1)!;
    throw Exception('Identifiant de playlist Deezer introuvable dans ce lien.');
  }

  Future<ImportedPlaylist> _importFromDeezer(String url) async {
    final playlistId = await _resolveDeezerPlaylistId(url);
    final tracks = <ImportedTrack>[];
    String? playlistName;
    String? nextUrl = 'https://api.deezer.com/playlist/$playlistId';
    while (nextUrl != null) {
      final response = await http.get(Uri.parse(nextUrl)).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw Exception('Playlist Deezer introuvable ou privée.');
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['error'] != null) {
        throw Exception('Playlist Deezer introuvable ou privée.');
      }
      playlistName ??= json['title'] as String?;
      final data = (json['tracks'] as Map<String, dynamic>?)?['data'] as List<dynamic>?;
      if (data != null) {
        for (final item in data) {
          final track = item as Map<String, dynamic>;
          final title = track['title'] as String? ?? '';
          final artist = (track['artist'] as Map<String, dynamic>?)?['name'] as String? ?? '';
          final album = (track['album'] as Map<String, dynamic>?)?['title'] as String?;
          if (title.isEmpty) continue;
          tracks.add(ImportedTrack(title: title, artist: artist, album: album));
        }
      }
      nextUrl = (json['tracks'] as Map<String, dynamic>?)?['next'] as String?;
    }
    if (tracks.isEmpty) {
      throw Exception('Playlist Deezer vide, introuvable ou privée.');
    }
    return ImportedPlaylist(
      name: (playlistName != null && playlistName.isNotEmpty) ? playlistName : 'Playlist Deezer',
      sourceLabel: 'Deezer',
      tracks: tracks,
    );
  }

  Future<String> _resolveSpotifyPlaylistId(String url) async {
    final direct = _spotifyPlaylistIdPattern.firstMatch(url);
    if (direct != null) return direct.group(1)!;
    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
    final finalUrl = _finalUrlFromHtml(response.body);
    final resolved = finalUrl != null ? _spotifyPlaylistIdPattern.firstMatch(finalUrl) : null;
    if (resolved != null) return resolved.group(1)!;
    throw Exception('Identifiant de playlist Spotify introuvable dans ce lien.');
  }

  static const _nextDataOpenTag = '<script id="__NEXT_DATA__" type="application/json">';

  Future<ImportedPlaylist> _importFromSpotify(String url) async {
    final playlistId = await _resolveSpotifyPlaylistId(url);
    final response = await http
        .get(Uri.parse('https://open.spotify.com/embed/playlist/$playlistId'))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Playlist Spotify introuvable ou privée.');
    }
    final html = response.body;
    final start = html.indexOf(_nextDataOpenTag);
    final end = start == -1 ? -1 : html.indexOf('</script>', start);
    if (start == -1 || end == -1) {
      throw Exception('Impossible de lire cette playlist Spotify (page inattendue).');
    }
    final json = jsonDecode(html.substring(start + _nextDataOpenTag.length, end)) as Map<String, dynamic>;
    final entity = json['props']?['pageProps']?['state']?['data']?['entity'] as Map<String, dynamic>?;
    final trackList = entity?['trackList'] as List<dynamic>?;
    if (entity == null || trackList == null) {
      throw Exception('Playlist Spotify introuvable ou privée.');
    }
    final tracks = <ImportedTrack>[];
    for (final item in trackList) {
      final track = item as Map<String, dynamic>;
      final title = track['title'] as String? ?? '';
      final artist = track['subtitle'] as String? ?? '';
      if (title.isEmpty) continue;
      tracks.add(ImportedTrack(title: title, artist: artist));
    }
    if (tracks.isEmpty) {
      throw Exception('Playlist Spotify vide, introuvable ou privée.');
    }
    final name = entity['name'] as String? ?? entity['title'] as String?;
    return ImportedPlaylist(
      name: (name != null && name.isNotEmpty) ? name : 'Playlist Spotify',
      sourceLabel: 'Spotify',
      tracks: tracks,
    );
  }
}
