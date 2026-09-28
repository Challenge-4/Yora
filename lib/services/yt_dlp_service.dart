import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../utils/platform_paths.dart';
import 'youtube_backend.dart';

class YtSearchResult {
  final String id;
  final String title;
  final String author;
  final String thumbnailUrl;
  final String? album;
  final String? releaseYear;
  final int? durationMs;

  const YtSearchResult({
    required this.id,
    required this.title,
    required this.author,
    required this.thumbnailUrl,
    this.album,
    this.releaseYear,
    this.durationMs,
  });
}

class _ScoredCandidate {
  final YtSearchResult result;
  final double score;
  _ScoredCandidate(this.result, this.score);
}

class YtDlpService implements YoutubeBackend {
  @override
  String get audioExtension => 'mp3';

  String? _bundledBinaryPath(String name) {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final candidate = File(joinPath([exeDir, executableName(name)]));
    return candidate.existsSync() ? candidate.path : null;
  }

  static const List<String> _ytClientFallbackOrder = ['android', 'android_vr', 'mweb', 'tv'];

  String? _ffmpegPathCache;
  String? _ytDlpPathCache;
  String? _ffprobePathCache;

  Future<String?> _locateBinary(String name, {String? wingetPackageHint}) async {
    try {
      final result = await Process.run(Platform.isWindows ? 'where' : 'which', [name]);
      if (result.exitCode == 0) {
        final path = (result.stdout as String)
            .split('\n')
            .map((line) => line.trim())
            .firstWhere((line) => line.isNotEmpty, orElse: () => '');
        if (path.isNotEmpty) return path;
      }
    } catch (_) {}
    final bundled = _bundledBinaryPath(name);
    if (bundled != null) return bundled;
    final home = homeDirectory;
    if (Platform.isWindows) {
      if (home == null) return null;
      final exe = executableName(name);
      final link = File(joinPath([home, 'AppData', 'Local', 'Microsoft', 'WinGet', 'Links', exe]));
      if (await link.exists()) return link.path;
      final wingetPackages = Directory(joinPath([home, 'AppData', 'Local', 'Microsoft', 'WinGet', 'Packages']));
      if (await wingetPackages.exists()) {
        await for (final entry in wingetPackages.list()) {
          if (entry is Directory && entry.path.toLowerCase().contains(wingetPackageHint ?? name)) {
            await for (final sub in entry.list(recursive: true)) {
              if (sub is File && sub.path.toLowerCase().endsWith(exe)) return sub.path;
            }
          }
        }
      }
      return null;
    }
    final searchDirs = <String>[
      '/opt/homebrew/bin',
      '/usr/local/bin',
      '/usr/bin',
      '/snap/bin',
      if (home != null) joinPath([home, '.local', 'bin']),
    ];
    for (final dir in searchDirs) {
      final candidate = File(joinPath([dir, name]));
      if (await candidate.exists()) return candidate.path;
    }
    return null;
  }

  @override
  Future<String?> resolveFfmpegPath() async {
    final cached = _ffmpegPathCache;
    if (cached != null) return cached;
    return _ffmpegPathCache = await _locateBinary('ffmpeg');
  }

  Future<String> resolveYtDlpPath() async {
    final cached = _ytDlpPathCache;
    if (cached != null) return cached;
    try {
      final result = await Process.run('yt-dlp', ['--version']);
      if (result.exitCode == 0) {
        _ytDlpPathCache = 'yt-dlp';
        return 'yt-dlp';
      }
    } catch (_) {}
    final located = await _locateBinary('yt-dlp', wingetPackageHint: 'yt-dlp.yt-dlp');
    if (located != null) return _ytDlpPathCache = located;
    throw Exception('yt-dlp introuvable. Installez-le (${_installHint('yt-dlp')}) puis relancez l\'application.');
  }

  static String _installHint(String package) {
    if (Platform.isWindows) return 'winget install $package';
    if (Platform.isMacOS) return 'brew install $package';
    return 'sudo apt install $package';
  }

  Future<String?> resolveFfprobePath() async {
    final cached = _ffprobePathCache;
    if (cached != null) return cached;
    return _ffprobePathCache = await _locateBinary('ffprobe', wingetPackageHint: 'ffmpeg');
  }

  @override
  Future<Duration?> probeDuration(String filePath) async {
    final ffprobePath = await resolveFfprobePath();
    if (ffprobePath == null) return null;
    try {
      final result = await Process.run(ffprobePath, [
        '-v', 'error',
        '-show_entries', 'format=duration',
        '-of', 'default=noprint_wrappers=1:nokey=1',
        filePath,
      ]).timeout(const Duration(seconds: 10));
      if (result.exitCode != 0) return null;
      final seconds = double.tryParse((result.stdout as String).trim());
      if (seconds == null) return null;
      return Duration(milliseconds: (seconds * 1000).round());
    } catch (_) {
      return null;
    }
  }

  Future<ProcessResult> runYtDlp(List<String> args, Duration timeout, {String? timeoutMessage}) async {
    final ytDlpPath = await resolveYtDlpPath();
    return Process.run(ytDlpPath, args).timeout(
      timeout,
      onTimeout: timeoutMessage == null ? null : () => throw TimeoutException(timeoutMessage),
    );
  }

  Future<ProcessResult> runYtDlpKillable(
    List<String> args,
    Duration timeout, {
    void Function(String line)? onStdoutLine,
  }) async {
    final ytDlpPath = await resolveYtDlpPath();
    return _runKillable(ytDlpPath, args, timeout, onStdoutLine: onStdoutLine);
  }

  Future<List<String>> ffmpegLocationArgs() async {
    final ffmpegPath = await resolveFfmpegPath();
    if (ffmpegPath == null) {
      throw Exception(
        'ffmpeg introuvable : impossible de convertir en MP3. Installez-le (${_installHint('ffmpeg')}) puis relancez l\'application.',
      );
    }
    return ['--ffmpeg-location', ffmpegPath];
  }

  Future<ProcessResult> _runKillable(
    String executable,
    List<String> arguments,
    Duration timeout, {
    void Function(String line)? onStdoutLine,
  }) async {
    final process = await Process.start(executable, arguments);
    final stdoutLines = <String>[];
    final stderrLines = <String>[];
    final stdoutSub = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      stdoutLines.add(line);
      onStdoutLine?.call(line);
    });
    final stderrSub = process.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen(stderrLines.add);
    int exitCode;
    try {
      exitCode = await process.exitCode.timeout(timeout);
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
      await stdoutSub.cancel();
      await stderrSub.cancel();
      throw TimeoutException('Le processus ($executable) ne répond plus après ${timeout.inSeconds}s.');
    }
    await stdoutSub.cancel();
    await stderrSub.cancel();
    return ProcessResult(process.pid, exitCode, stdoutLines.join('\n'), stderrLines.join('\n'));
  }

  static final RegExp _progressPattern = RegExp(r'\[download\]\s+(\d{1,3}(?:\.\d+)?)%');

  Future<void> _runYtDlpAudioDownload(
    String videoUrl,
    String outputTemplate, {
    required Duration perAttemptTimeout,
    void Function(double progress)? onProgress,
    List<String> extraArgs = const [],
  }) async {
    final ffmpegArgs = await ffmpegLocationArgs();
    Object lastError = Exception('Échec du téléchargement.');
    for (final client in _ytClientFallbackOrder) {
      try {
        final result = await runYtDlpKillable(
          [
            '-x',
            '--audio-format', 'mp3',
            '--audio-quality', '0',
            '--no-playlist',
            '--newline',
            ...ffmpegArgs,
            '--extractor-args', 'youtube:player_client=$client',
            ...extraArgs,
            '-o', outputTemplate,
            videoUrl,
          ],
          perAttemptTimeout,
          onStdoutLine: (line) {
            final match = _progressPattern.firstMatch(line);
            if (match != null) {
              final pct = double.tryParse(match.group(1)!);
              if (pct != null) onProgress?.call((pct / 100).clamp(0.0, 0.99));
            }
          },
        );
        if (result.exitCode == 0) {
          onProgress?.call(1.0);
          return;
        }
        lastError = Exception(result.stderr.toString());
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError;
  }

  @override
  Future<void> downloadAudio(
    String videoId,
    String outputTemplate, {
    required Duration perAttemptTimeout,
    void Function(double progress)? onProgress,
  }) async {
    await _runYtDlpAudioDownload(
      'https://www.youtube.com/watch?v=$videoId',
      outputTemplate,
      perAttemptTimeout: perAttemptTimeout,
      onProgress: onProgress,
    );
  }

  @override
  Future<void> downloadAudioClip(
    String videoId,
    String outputTemplate, {
    required Duration maxDuration,
    required Duration perAttemptTimeout,
    Duration startOffset = Duration.zero,
  }) async {
    final start = startOffset.inSeconds;
    final end = start + maxDuration.inSeconds;
    await _runYtDlpAudioDownload(
      'https://www.youtube.com/watch?v=$videoId',
      outputTemplate,
      perAttemptTimeout: perAttemptTimeout,
      extraArgs: ['--download-sections', '*$start-$end', '--force-keyframes-at-cuts'],
    );
  }

  @override
  Future<List<YtSearchResult>> search(String query, {int count = 8}) async {
    final result = await runYtDlp(
      [
        'ytsearch$count:$query',
        '--dump-json',
        '--flat-playlist',
        '--no-warnings',
        '--skip-download',
      ],
      const Duration(seconds: 30),
      timeoutMessage: 'La recherche ne répond plus.',
    );
    if (result.exitCode != 0) {
      throw Exception(result.stderr.toString());
    }
    final videoIdPattern = RegExp(r'^[A-Za-z0-9_-]{11}$');
    final candidates = <_ScoredCandidate>[];
    for (final line in (result.stdout as String).split('\n')) {
      if (line.trim().isEmpty) continue;
      try {
        final json = jsonDecode(line) as Map<String, dynamic>;
        final id = json['id'] as String?;
        if (id == null || !videoIdPattern.hasMatch(id)) continue;
        final title = json['title'] as String? ?? 'Titre inconnu';
        final author = (json['uploader'] ?? json['channel'] ?? '') as String;
        final durationSeconds = (json['duration'] as num?)?.toDouble();
        candidates.add(_ScoredCandidate(
          YtSearchResult(
            id: id,
            title: title,
            author: author,
            thumbnailUrl: 'https://img.youtube.com/vi/$id/mqdefault.jpg',
            durationMs: durationSeconds != null ? (durationSeconds * 1000).round() : null,
          ),
          scoreSearchCandidate(title: title, author: author, query: query),
        ));
      } catch (_) {}
    }
    candidates.sort((a, b) => b.score.compareTo(a.score));
    return candidates.map((c) => c.result).toList();
  }

  @override
  Future<List<YtSearchResult>> searchWithFallback(
    String primaryQuery,
    String fallbackQuery,
  ) async {
    final primary = await search(primaryQuery);
    if (primary.isNotEmpty) return primary;
    return search(fallbackQuery);
  }

  static const _fetchPlaylistMaxAttempts = 3;
  static const _fetchPlaylistIncompleteThreshold = 0.5;

  @override
  Future<(String title, List<YtSearchResult> tracks)> fetchPlaylist(String url) async {
    var best = ('Playlist YouTube', <YtSearchResult>[]);
    for (var attempt = 1; attempt <= _fetchPlaylistMaxAttempts; attempt++) {
      final (title, tracks, declaredCount) = await _fetchPlaylistOnce(url);
      if (tracks.length > best.$2.length) best = (title, tracks);
      final complete = declaredCount == null ||
          declaredCount <= 0 ||
          tracks.length >= declaredCount * _fetchPlaylistIncompleteThreshold;
      if (complete || attempt == _fetchPlaylistMaxAttempts) break;
    }
    if (best.$2.isEmpty) {
      throw Exception('Playlist introuvable, vide, ou privée.');
    }
    return best;
  }

  Future<(String title, List<YtSearchResult> tracks, int? declaredCount)> _fetchPlaylistOnce(String url) async {
    final result = await runYtDlp(
      [
        url,
        '--dump-json',
        '--flat-playlist',
        '--no-warnings',
        '--skip-download',
      ],
      const Duration(seconds: 60),
      timeoutMessage: 'L\'import de la playlist ne répond plus.',
    );
    if (result.exitCode != 0) {
      throw Exception(result.stderr.toString());
    }
    final videoIdPattern = RegExp(r'^[A-Za-z0-9_-]{11}$');
    final tracks = <YtSearchResult>[];
    String? playlistTitle;
    int? declaredCount;
    for (final line in (result.stdout as String).split('\n')) {
      if (line.trim().isEmpty) continue;
      try {
        final json = jsonDecode(line) as Map<String, dynamic>;
        playlistTitle ??= json['playlist_title'] as String?;
        declaredCount ??= (json['playlist_count'] as num?)?.toInt();
        final id = json['id'] as String?;
        if (id == null || !videoIdPattern.hasMatch(id)) continue;
        final title = json['title'] as String? ?? 'Titre inconnu';
        final author = (json['uploader'] ?? json['channel'] ?? '') as String;
        final durationSeconds = (json['duration'] as num?)?.toDouble();
        tracks.add(YtSearchResult(
          id: id,
          title: title,
          author: author,
          thumbnailUrl: 'https://img.youtube.com/vi/$id/mqdefault.jpg',
          durationMs: durationSeconds != null ? (durationSeconds * 1000).round() : null,
        ));
      } catch (_) {}
    }
    return (playlistTitle ?? 'Playlist YouTube', tracks, declaredCount);
  }

  @override
  Future<YtSearchResult?> fetchVideoInfo(String videoId) async {
    final result = await runYtDlp(
      [
        'https://www.youtube.com/watch?v=$videoId',
        '--dump-json',
        '--no-warnings',
        '--skip-download',
      ],
      const Duration(seconds: 20),
    );
    if (result.exitCode != 0) return null;
    try {
      final json = jsonDecode((result.stdout as String).trim().split('\n').first) as Map<String, dynamic>;
      final title = json['title'] as String?;
      if (title == null || title.isEmpty) return null;
      final author = (json['uploader'] ?? json['channel'] ?? '') as String;
      final durationSeconds = (json['duration'] as num?)?.toDouble();
      return YtSearchResult(
        id: videoId,
        title: title,
        author: author,
        thumbnailUrl: 'https://img.youtube.com/vi/$videoId/mqdefault.jpg',
        durationMs: durationSeconds != null ? (durationSeconds * 1000).round() : null,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<({String id, String title})>> listChannelPlaylists(String channelUrl) async {
    final result = await runYtDlp(
      [
        channelUrl,
        '--dump-single-json',
        '--flat-playlist',
        '--no-warnings',
        '--skip-download',
      ],
      const Duration(seconds: 30),
    );
    if (result.exitCode != 0) {
      throw Exception(result.stderr.toString());
    }
    final json = jsonDecode(result.stdout as String) as Map<String, dynamic>;
    final entries = json['entries'] as List? ?? [];
    final playlists = <({String id, String title})>[];
    for (final entry in entries) {
      final map = entry as Map<String, dynamic>;
      final title = map['title'] as String?;
      final id = map['id'] as String?;
      if (title == null || id == null) continue;
      playlists.add((id: id, title: title));
    }
    return playlists;
  }
}
