import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../api_keys.dart';
import 'yt_dlp_service.dart';
import 'youtube_backend.dart';

class YtMusicGenre {
  final String name;
  final String params;
  const YtMusicGenre({required this.name, required this.params});
}

class YtMusicCountryChart {
  final String countryName;
  final String playlistId;
  const YtMusicCountryChart({required this.countryName, required this.playlistId});
}

class NewRelease {
  final String title;
  final String artist;
  final String releaseType;
  final String? coverUrl;
  final String playlistId;
  final String? releaseYear;
  const NewRelease({
    required this.title,
    required this.artist,
    required this.releaseType,
    this.coverUrl,
    required this.playlistId,
    this.releaseYear,
  });
}

class YtMusicArtist {
  final String name;
  final String browseId;
  final String? thumbnailUrl;
  const YtMusicArtist({required this.name, required this.browseId, this.thumbnailUrl});
}

class ArtistPage {
  final String name;
  final String? thumbnailUrl;
  final List<YtSearchResult> topSongs;
  final List<NewRelease> albums;
  final List<NewRelease> singles;
  const ArtistPage({
    required this.name,
    this.thumbnailUrl,
    required this.topSongs,
    required this.albums,
    required this.singles,
  });
}

class ChartsService {
  final YoutubeBackend ytDlpService;
  const ChartsService({required this.ytDlpService});

  static const _browseKey = youtubeMusicApiKey;
  static const _browseUrl = 'https://music.youtube.com/youtubei/v1/browse?key=$_browseKey';
  static const _searchUrl = 'https://music.youtube.com/youtubei/v1/search?key=$_browseKey';

  Map<String, dynamic> _clientContext({bool forceEnglish = false}) {
    if (forceEnglish) {
      return {'clientName': 'WEB_REMIX', 'clientVersion': '1.20260101.01.00', 'hl': 'en', 'gl': 'US'};
    }
    final locale = Platform.localeName.split(RegExp('[_-]'));
    final language = locale.isNotEmpty ? locale.first : 'en';
    final region = locale.length > 1 ? locale.last : 'US';
    return {'clientName': 'WEB_REMIX', 'clientVersion': '1.20260101.01.00', 'hl': language, 'gl': region};
  }

  Map<String, dynamic> _requestBody(String browseId, {String? params, bool forceEnglish = false}) {
    return {
      'context': {'client': _clientContext(forceEnglish: forceEnglish)},
      'browseId': browseId,
      'params': ?params,
    };
  }

  Future<Map<String, dynamic>> _browse(String browseId, {String? params, bool forceEnglish = false}) async {
    final response = await http
        .post(Uri.parse(_browseUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(_requestBody(browseId, params: params, forceEnglish: forceEnglish)))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Impossible de contacter YouTube Music.');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _search(String query, {String? params}) async {
    final body = {
      'context': {'client': _clientContext(forceEnglish: true)},
      'query': query,
      'params': ?params,
    };
    final response = await http
        .post(Uri.parse(_searchUrl), headers: {'Content-Type': 'application/json'}, body: jsonEncode(body))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Impossible de contacter YouTube Music.');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  List<dynamic>? _searchSectionListContents(Map<String, dynamic> json) {
    final tabbed = json['contents']?['tabbedSearchResultsRenderer'] as Map<String, dynamic>?;
    final tabs = tabbed?['tabs'] as List?;
    final tab = tabs?.isNotEmpty == true ? (tabs!.first as Map<String, dynamic>)['tabRenderer'] : null;
    final sectionList = (tab as Map<String, dynamic>?)?['content']?['sectionListRenderer'] as Map<String, dynamic>?;
    return sectionList?['contents'] as List?;
  }

  static const _songsFilterParams = 'EgWKAQIIAWoMEAQQAxAFEAkQChAV';

  Future<List<YtSearchResult>> searchWithMusicPriority(String query, {int count = 8}) async {
    try {
      final musicResults = await searchSongs(query);
      if (musicResults.isNotEmpty) return musicResults.take(count).toList();
    } catch (_) {}
    return ytDlpService.search(query, count: count);
  }

  Future<List<YtSearchResult>> searchSongs(String query) async {
    final json = await _search(query, params: _songsFilterParams);
    final sections = _searchSectionListContents(json);
    if (sections == null) return [];
    for (final section in sections) {
      final shelf = (section as Map<String, dynamic>)['musicShelfRenderer'] as Map<String, dynamic>?;
      if (shelf == null) continue;
      final items = shelf['contents'] as List? ?? [];
      final tracks = <YtSearchResult>[];
      for (final item in items) {
        final track = _parseSongItem(item as Map<String, dynamic>);
        if (track != null) tracks.add(track);
      }
      return tracks;
    }
    return [];
  }

  Future<YtMusicArtist?> searchArtist(String artistName) async {
    final json = await _search(artistName);
    final sections = _searchSectionListContents(json);
    if (sections == null) return null;
    for (final section in sections) {
      final card = (section as Map<String, dynamic>)['musicCardShelfRenderer'] as Map<String, dynamic>?;
      if (card == null) continue;
      final subtitleRuns = (card['subtitle'] as Map<String, dynamic>?)?['runs'] as List?;
      final subtitleText =
          subtitleRuns != null && subtitleRuns.isNotEmpty ? (subtitleRuns.first as Map<String, dynamic>)['text'] as String? : null;
      if (subtitleText != 'Artist') continue;
      final titleRuns = (card['title'] as Map<String, dynamic>?)?['runs'] as List?;
      final titleRun = titleRuns != null && titleRuns.isNotEmpty ? titleRuns.first as Map<String, dynamic> : null;
      final name = titleRun?['text'] as String?;
      final browseId = titleRun?['navigationEndpoint']?['browseEndpoint']?['browseId'] as String?;
      if (name == null || browseId == null) continue;
      final thumbnails = card['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'] as List?;
      final thumbnailUrl =
          thumbnails != null && thumbnails.isNotEmpty ? (thumbnails.last as Map<String, dynamic>)['url'] as String? : null;
      return YtMusicArtist(name: name, browseId: browseId, thumbnailUrl: thumbnailUrl);
    }
    return null;
  }

  Future<List<YtSearchResult>> fetchArtistPopularSongs(String artistName) async {
    final artist = await searchArtist(artistName);
    if (artist == null) return [];
    final json = await _browse(artist.browseId, forceEnglish: true);
    final sections = _sectionListContents(json);
    if (sections == null) return [];
    for (final section in sections) {
      final shelf = (section as Map<String, dynamic>)['musicShelfRenderer'] as Map<String, dynamic>?;
      if (shelf == null) continue;
      final tracks = <YtSearchResult>[];
      for (final item in shelf['contents'] as List? ?? []) {
        final track = _parseSongItem(item as Map<String, dynamic>);
        if (track != null) tracks.add(track);
      }
      return tracks;
    }
    return [];
  }

  List<dynamic>? _sectionListContents(Map<String, dynamic> json) {
    final single = json['contents']?['singleColumnBrowseResultsRenderer'] as Map<String, dynamic>?;
    final tabs = single?['tabs'] as List?;
    final tab = tabs?.isNotEmpty == true ? (tabs!.first as Map<String, dynamic>)['tabRenderer'] : null;
    final sectionList = (tab as Map<String, dynamic>?)?['content']?['sectionListRenderer'] as Map<String, dynamic>?;
    return sectionList?['contents'] as List?;
  }

  Future<List<YtMusicGenre>> fetchGenres() async {
    final json = await _browse('FEmusic_moods_and_genres');
    final sections = _sectionListContents(json);
    if (sections == null || sections.length < 2) return [];
    final grid = (sections[1] as Map<String, dynamic>)['gridRenderer'] as Map<String, dynamic>?;
    final items = grid?['items'] as List? ?? [];
    final genres = <YtMusicGenre>[];
    for (final item in items) {
      try {
        final btn = (item as Map<String, dynamic>)['musicNavigationButtonRenderer'] as Map<String, dynamic>;
        final name = ((btn['buttonText'] as Map<String, dynamic>)['runs'] as List).first['text'] as String;
        final browseEndpoint = (btn['clickCommand'] as Map<String, dynamic>)['browseEndpoint'] as Map<String, dynamic>;
        final params = browseEndpoint['params'] as String?;
        if (params == null) continue;
        genres.add(YtMusicGenre(name: name, params: params));
      } catch (_) {}
    }
    return genres;
  }

  Future<List<YtSearchResult>> fetchGenreSongs(String params) async {
    final json = await _browse('FEmusic_moods_and_genres_category', params: params);
    final sections = _sectionListContents(json);
    if (sections == null || sections.isEmpty) return [];
    final shelf = (sections.first as Map<String, dynamic>)['musicCarouselShelfRenderer'] as Map<String, dynamic>?;
    final items = shelf?['contents'] as List? ?? [];
    final tracks = <YtSearchResult>[];
    for (final item in items) {
      final track = _parseSongItem(item as Map<String, dynamic>);
      if (track != null) tracks.add(track);
    }
    return tracks;
  }

  YtSearchResult? _parseSongItem(Map<String, dynamic> item) {
    try {
      final renderer = item['musicResponsiveListItemRenderer'] as Map<String, dynamic>;
      final flexColumns = renderer['flexColumns'] as List;
      final titleRuns =
          ((flexColumns[0] as Map<String, dynamic>)['musicResponsiveListItemFlexColumnRenderer']['text']['runs']
              as List);
      final titleRun = titleRuns.first as Map<String, dynamic>;
      final title = titleRun['text'] as String;
      final videoId = titleRun['navigationEndpoint']?['watchEndpoint']?['videoId'] as String?;
      if (videoId == null) return null;

      final artistRuns =
          ((flexColumns[1] as Map<String, dynamic>)['musicResponsiveListItemFlexColumnRenderer']['text']['runs']
              as List?) ??
              const [];
      final artistParts = <String>[];
      for (final run in artistRuns) {
        final text = (run as Map<String, dynamic>)['text'] as String? ?? '';
        if (text.contains('•')) break;
        artistParts.add(text);
      }

      final thumbnails = renderer['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'] as List?;
      final thumbnailUrl =
          thumbnails != null && thumbnails.isNotEmpty ? (thumbnails.last as Map<String, dynamic>)['url'] as String : '';

      return YtSearchResult(
        id: videoId,
        title: title,
        author: artistParts.join().trim(),
        thumbnailUrl: thumbnailUrl,
      );
    } catch (_) {
      return null;
    }
  }

  static const _chartsChannelUrl = 'https://www.youtube.com/channel/UCrKZcyOJVWnJ60zM1XWllNw/playlists';
  static final _countryTitleRegex = RegExp(r'^Top 100 Music Videos (.+)$');

  Future<List<YtMusicCountryChart>> fetchCountryCharts() async {
    final playlists = await ytDlpService.listChannelPlaylists(_chartsChannelUrl);
    final charts = <YtMusicCountryChart>[];
    for (final playlist in playlists) {
      final match = _countryTitleRegex.firstMatch(playlist.title);
      if (match == null) continue;
      charts.add(YtMusicCountryChart(countryName: match.group(1)!, playlistId: playlist.id));
    }
    charts.sort((a, b) => a.countryName.compareTo(b.countryName));
    return charts;
  }

  Future<List<YtSearchResult>> fetchCountryChartTracks(String playlistId) async {
    final (_, tracks) = await ytDlpService.fetchPlaylist('https://www.youtube.com/playlist?list=$playlistId');
    return tracks;
  }

  Future<List<NewRelease>> fetchNewReleases() async {
    final json = await _browse('FEmusic_new_releases_albums');
    final sections = _sectionListContents(json);
    if (sections == null || sections.isEmpty) return [];
    final grid = (sections.first as Map<String, dynamic>)['gridRenderer'] as Map<String, dynamic>?;
    final items = grid?['items'] as List? ?? [];
    final releases = <NewRelease>[];
    for (final item in items) {
      final release = _parseNewReleaseItem(item as Map<String, dynamic>);
      if (release != null) releases.add(release);
    }
    return releases;
  }

  NewRelease? _parseNewReleaseItem(Map<String, dynamic> item) {
    try {
      final renderer = item['musicTwoRowItemRenderer'] as Map<String, dynamic>;
      final title = ((renderer['title'] as Map<String, dynamic>)['runs'] as List).first['text'] as String;

      final subtitleRuns = (renderer['subtitle'] as Map<String, dynamic>?)?['runs'] as List? ?? const [];
      final releaseType = subtitleRuns.isNotEmpty ? (subtitleRuns.first as Map<String, dynamic>)['text'] as String : '';
      final artistParts = <String>[];
      for (final run in subtitleRuns.skip(1)) {
        final text = (run as Map<String, dynamic>)['text'] as String? ?? '';
        if (text.trim() == '•') continue;
        artistParts.add(text);
      }

      final thumbnails =
          renderer['thumbnailRenderer']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'] as List?;
      final coverUrl =
          thumbnails != null && thumbnails.isNotEmpty ? (thumbnails.last as Map<String, dynamic>)['url'] as String? : null;

      final menuItems = (renderer['menu'] as Map<String, dynamic>?)?['menuRenderer']?['items'] as List? ?? [];
      String? playlistId;
      for (final menuItem in menuItems) {
        final nav = (menuItem as Map<String, dynamic>)['menuNavigationItemRenderer'] as Map<String, dynamic>?;
        final id = nav?['navigationEndpoint']?['watchPlaylistEndpoint']?['playlistId'] as String?;
        if (id == null) continue;
        final label = ((nav!['text'] as Map<String, dynamic>)['runs'] as List).first['text'] as String?;
        if (label != null && label.toLowerCase().contains('shuffle')) {
          playlistId = id;
          break;
        }
        playlistId ??= id;
      }
      if (playlistId == null) return null;

      return NewRelease(
        title: title,
        artist: artistParts.join().trim(),
        releaseType: releaseType,
        coverUrl: coverUrl,
        playlistId: playlistId,
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<YtSearchResult>> fetchNewReleaseTracks(String playlistId) async {
    final (_, tracks) = await ytDlpService.fetchPlaylist('https://www.youtube.com/playlist?list=$playlistId');
    return tracks;
  }

  Future<ArtistPage> fetchArtist(YtMusicArtist artist) async {
    final json = await _browse(artist.browseId, forceEnglish: true);
    final sections = _sectionListContents(json);
    var topSongs = <YtSearchResult>[];
    final albums = <NewRelease>[];
    final singles = <NewRelease>[];
    if (sections != null) {
      for (final section in sections) {
        final map = section as Map<String, dynamic>;
        final shelf = map['musicShelfRenderer'] as Map<String, dynamic>?;
        if (shelf != null) {
          topSongs = await _fetchArtistTopSongs(shelf);
          continue;
        }
        final carousel = map['musicCarouselShelfRenderer'] as Map<String, dynamic>?;
        if (carousel == null) continue;
        final headerTitle = _carouselHeaderTitle(carousel);
        if (headerTitle == 'Albums') {
          albums.addAll(await _fetchArtistReleases(carousel, artistName: artist.name, fallbackType: 'Album'));
        } else if (headerTitle == 'Singles & EPs') {
          singles.addAll(await _fetchArtistReleases(carousel, artistName: artist.name, fallbackType: 'Single'));
        }
      }
    }
    return ArtistPage(name: artist.name, thumbnailUrl: artist.thumbnailUrl, topSongs: topSongs, albums: albums, singles: singles);
  }

  String? _carouselHeaderTitle(Map<String, dynamic> carousel) {
    final run = _carouselHeaderTitleRun(carousel);
    return run?['text'] as String?;
  }

  Map<String, dynamic>? _carouselHeaderTitleRun(Map<String, dynamic> carousel) {
    final header = carousel['header']?['musicCarouselShelfBasicHeaderRenderer'] as Map<String, dynamic>?;
    final runs = (header?['title'] as Map<String, dynamic>?)?['runs'] as List?;
    return runs != null && runs.isNotEmpty ? runs.first as Map<String, dynamic> : null;
  }

  Future<List<NewRelease>> _fetchArtistReleases(
    Map<String, dynamic> carousel, {
    required String artistName,
    required String fallbackType,
  }) async {
    final nav = _carouselHeaderTitleRun(carousel)?['navigationEndpoint']?['browseEndpoint'] as Map<String, dynamic>?;
    final browseId = nav?['browseId'] as String?;
    if (browseId != null) {
      try {
        final full = await _browse(browseId, params: nav?['params'] as String?, forceEnglish: true);
        final sections = _sectionListContents(full);
        final grid = sections != null && sections.isNotEmpty ? (sections.first as Map<String, dynamic>)['gridRenderer'] as Map<String, dynamic>? : null;
        final items = grid?['items'] as List?;
        if (items != null && items.isNotEmpty) {
          final releases = <NewRelease>[];
          for (final item in items) {
            final release = _parseArtistReleaseItem(item as Map<String, dynamic>, artistName: artistName, fallbackType: fallbackType);
            if (release != null) releases.add(release);
          }
          if (releases.isNotEmpty) return releases;
        }
      } catch (_) {}
    }
    return _parseArtistReleases(carousel, artistName: artistName, fallbackType: fallbackType);
  }

  Future<List<YtSearchResult>> _fetchArtistTopSongs(Map<String, dynamic> shelf) async {
    final bottomBrowseId = shelf['bottomEndpoint']?['browseEndpoint']?['browseId'] as String?;
    if (bottomBrowseId != null && bottomBrowseId.startsWith('VL')) {
      try {
        final (_, tracks) =
            await ytDlpService.fetchPlaylist('https://www.youtube.com/playlist?list=${bottomBrowseId.substring(2)}');
        if (tracks.isNotEmpty) return tracks.take(10).toList();
      } catch (_) {}
    }
    final items = shelf['contents'] as List? ?? [];
    final tracks = <YtSearchResult>[];
    for (final item in items) {
      final track = _parseSongItem(item as Map<String, dynamic>);
      if (track != null) tracks.add(track);
    }
    return tracks.take(10).toList();
  }

  List<NewRelease> _parseArtistReleases(Map<String, dynamic> carousel, {required String artistName, required String fallbackType}) {
    final items = carousel['contents'] as List? ?? [];
    final releases = <NewRelease>[];
    for (final item in items) {
      final release = _parseArtistReleaseItem(item as Map<String, dynamic>, artistName: artistName, fallbackType: fallbackType);
      if (release != null) releases.add(release);
    }
    return releases;
  }

  NewRelease? _parseArtistReleaseItem(Map<String, dynamic> item, {required String artistName, required String fallbackType}) {
    try {
      final renderer = item['musicTwoRowItemRenderer'] as Map<String, dynamic>;
      final title = ((renderer['title'] as Map<String, dynamic>)['runs'] as List).first['text'] as String;

      final subtitleRuns = (renderer['subtitle'] as Map<String, dynamic>?)?['runs'] as List? ?? const [];
      final subtitleTexts = subtitleRuns
          .map((r) => (r as Map<String, dynamic>)['text'] as String? ?? '')
          .where((t) => t.trim() != '•')
          .toList();
      final releaseType = subtitleTexts.length >= 2 ? subtitleTexts[0] : fallbackType;
      final releaseYear = subtitleTexts.isEmpty ? null : subtitleTexts.last;

      final thumbnails =
          renderer['thumbnailRenderer']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'] as List?;
      final coverUrl =
          thumbnails != null && thumbnails.isNotEmpty ? (thumbnails.last as Map<String, dynamic>)['url'] as String? : null;

      final menuItems = (renderer['menu'] as Map<String, dynamic>?)?['menuRenderer']?['items'] as List? ?? [];
      String? playlistId;
      for (final menuItem in menuItems) {
        final nav = (menuItem as Map<String, dynamic>)['menuNavigationItemRenderer'] as Map<String, dynamic>?;
        final id = nav?['navigationEndpoint']?['watchPlaylistEndpoint']?['playlistId'] as String?;
        if (id == null) continue;
        final label = ((nav!['text'] as Map<String, dynamic>)['runs'] as List).first['text'] as String?;
        if (label != null && label.toLowerCase().contains('shuffle')) {
          playlistId = id;
          break;
        }
        playlistId ??= id;
      }
      if (playlistId == null) return null;

      return NewRelease(
        title: title,
        artist: artistName,
        releaseType: releaseType,
        coverUrl: coverUrl,
        playlistId: playlistId,
        releaseYear: releaseYear,
      );
    } catch (_) {
      return null;
    }
  }
}
