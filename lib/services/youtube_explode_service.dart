import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:media_kit/media_kit.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'yt_dlp_service.dart';
import 'youtube_backend.dart';

class YoutubeExplodeService implements YoutubeBackend {
  final YoutubeExplode _yt = YoutubeExplode();

  @override
  String get audioExtension => 'm4a';

  static const _visionOs = YoutubeApiClient({
    'context': {
      'client': {
        'clientName': 'VISIONOS',
        'clientVersion': '1.02',
        'deviceMake': 'Apple',
        'deviceModel': 'RealityDevice17,1',
        'osName': 'visionOS',
        'osVersion': '26.5.23O471',
        'userAgent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 15_7_3) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15',
        'hl': 'en',
        'timeZone': 'UTC',
        'utcOffsetMinutes': 0,
      },
    },
  }, 'https://www.youtube.com/youtubei/v1/player?prettyPrint=false');

  static const _manifestTimeout = Duration(seconds: 20);

  static final List<List<YoutubeApiClient>> _clientAttempts = [
    [_visionOs],
    [YoutubeApiClient.androidVr],
    [YoutubeApiClient.ios],
    [YoutubeApiClient.android],
    [YoutubeApiClient.tv],
  ];

  YtSearchResult _toResult(Video video) {
    final id = video.id.value;
    return YtSearchResult(
      id: id,
      title: video.title,
      author: video.author,
      thumbnailUrl: 'https://img.youtube.com/vi/$id/mqdefault.jpg',
      durationMs: video.duration?.inMilliseconds,
    );
  }

  @override
  Future<List<YtSearchResult>> search(String query, {int count = 8}) async {
    final results = await _yt.search.search(query).timeout(const Duration(seconds: 30));
    final scored = <(YtSearchResult, double)>[];
    for (final video in results) {
      final result = _toResult(video);
      scored.add((result, scoreSearchCandidate(title: result.title, author: result.author, query: query)));
    }
    final top = scored.take(20).toList()..sort((a, b) => b.$2.compareTo(a.$2));
    return top.take(count).map((e) => e.$1).toList();
  }

  @override
  Future<List<YtSearchResult>> searchWithFallback(String primaryQuery, String fallbackQuery) async {
    final primary = await search(primaryQuery);
    if (primary.isNotEmpty) return primary;
    return search(fallbackQuery);
  }

  @override
  Future<(String title, List<YtSearchResult> tracks)> fetchPlaylist(String url) async {
    final playlist = await _yt.playlists.get(url).timeout(const Duration(seconds: 60));
    final tracks = <YtSearchResult>[];
    await for (final video in _yt.playlists.getVideos(playlist.id)) {
      tracks.add(_toResult(video));
    }
    if (tracks.isEmpty) {
      throw Exception('Playlist introuvable, vide, ou privée.');
    }
    return (playlist.title.isNotEmpty ? playlist.title : 'Playlist YouTube', tracks);
  }

  @override
  Future<YtSearchResult?> fetchVideoInfo(String videoId) async {
    try {
      final video = await _yt.videos.get(videoId).timeout(const Duration(seconds: 20));
      if (video.title.isEmpty) return null;
      return _toResult(video);
    } catch (_) {
      return null;
    }
  }

  static const _innertubeBrowseUrl = 'https://www.youtube.com/youtubei/v1/browse?prettyPrint=false';
  static const _innertubeContext = {
    'client': {'clientName': 'WEB', 'clientVersion': '2.20260901.00.00', 'hl': 'en', 'gl': 'US'},
  };
  static const _playlistsTabParams = 'EglwbGF5bGlzdHPyBgQKAkIA';
  static const _maxPlaylistPages = 40;

  @override
  Future<List<({String id, String title})>> listChannelPlaylists(String channelUrl) async {
    final channelId = RegExp(r'/channel/([\w-]+)').firstMatch(channelUrl)?.group(1);
    if (channelId == null) throw ArgumentError('URL de chaîne non reconnue : $channelUrl');
    final playlists = <({String id, String title})>[];
    Map<String, dynamic> body = {'context': _innertubeContext, 'browseId': channelId, 'params': _playlistsTabParams};
    for (var page = 0; page < _maxPlaylistPages; page++) {
      final response = await http
          .post(Uri.parse(_innertubeBrowseUrl), headers: {'Content-Type': 'application/json'}, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) throw Exception('Impossible de contacter YouTube.');
      final continuations = <String>[];
      _collectPlaylists(jsonDecode(response.body), '', playlists, continuations);
      if (continuations.isEmpty) break;
      body = {'context': _innertubeContext, 'continuation': continuations.first};
    }
    return playlists;
  }

  void _collectPlaylists(dynamic node, String path, List<({String id, String title})> out, List<String> continuations) {
    if (node is Map) {
      final lockup = node['lockupViewModel'];
      if (lockup is Map && lockup['contentType'] == 'LOCKUP_CONTENT_TYPE_PLAYLIST') {
        final id = lockup['contentId'];
        final title = lockup['metadata']?['lockupMetadataViewModel']?['title']?['content'];
        if (id is String && title is String) out.add((id: id, title: title));
      }
      final command = node['continuationCommand'];
      if (command is Map && command['token'] is String && !path.contains('/header')) {
        continuations.add(command['token'] as String);
      }
      node.forEach((key, value) => _collectPlaylists(value, '$path/$key', out, continuations));
    } else if (node is List) {
      for (final value in node) {
        _collectPlaylists(value, path, out, continuations);
      }
    }
  }

  Future<AudioOnlyStreamInfo> _pickStream(String videoId) async {
    Object lastError = Exception('Aucun flux audio disponible.');
    for (final clients in _clientAttempts) {
      try {
        final manifest = await _yt.videos.streamsClient.getManifest(videoId, ytClients: clients).timeout(_manifestTimeout);
        final audio = manifest.audioOnly.where((s) => s.container.name == 'mp4').toList()
          ..sort((a, b) => b.bitrate.compareTo(a.bitrate));
        if (audio.isEmpty) continue;
        return audio.first;
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError;
  }

  Future<void> _saveStream(
    AudioOnlyStreamInfo info,
    String outputTemplate,
    Duration idleTimeout,
    void Function(double progress)? onProgress,
  ) async {
    final target = File(outputTemplate.replaceAll('%(ext)s', audioExtension));
    final partial = File('${target.path}.part');
    if (await partial.exists()) await partial.delete();
    final sink = partial.openWrite();
    final total = info.size.totalBytes;
    var received = 0;
    try {
      await for (final chunk in _yt.videos.streamsClient.get(info).timeout(idleTimeout)) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress?.call((received / total).clamp(0.0, 0.99));
      }
      await sink.flush();
      await sink.close();
    } catch (_) {
      await sink.close();
      if (await partial.exists()) await partial.delete();
      rethrow;
    }
    await partial.rename(target.path);
    onProgress?.call(1.0);
  }

  @override
  Future<void> downloadAudio(
    String videoId,
    String outputTemplate, {
    required Duration perAttemptTimeout,
    void Function(double progress)? onProgress,
  }) async {
    final info = await _pickStream(videoId);
    await _saveStream(info, outputTemplate, perAttemptTimeout, onProgress);
  }

  @override
  Future<void> downloadAudioClip(
    String videoId,
    String outputTemplate, {
    required Duration maxDuration,
    required Duration perAttemptTimeout,
    Duration startOffset = Duration.zero,
  }) async {
    final info = await _pickStream(videoId);
    await _saveStream(info, outputTemplate, perAttemptTimeout, null);
  }

  @override
  Future<Duration?> probeDuration(String filePath) async {
    final player = Player();
    try {
      await player.open(Media(filePath), play: false);
      final duration = await player.stream.duration
          .firstWhere((d) => d > Duration.zero)
          .timeout(const Duration(seconds: 5));
      return duration;
    } catch (_) {
      return null;
    } finally {
      await player.dispose();
    }
  }

  @override
  Future<String?> resolveFfmpegPath() async => null;
}
