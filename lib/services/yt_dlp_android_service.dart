import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'yt_dlp_service.dart';

class YtDlpAndroidService extends YtDlpService {
  static const _channel = MethodChannel('yora/ytdlp');

  final Map<String, void Function(String line)> _lineListeners = {};
  Future<void>? _initFuture;
  int _nextId = 0;

  YtDlpAndroidService() {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'line') return;
      final args = Map<String, dynamic>.from(call.arguments as Map);
      _lineListeners[args['id'] as String]?.call(args['line'] as String);
    });
  }

  Future<void> _ensureInit() => _initFuture ??= _init().catchError((Object e, StackTrace st) {
        _initFuture = null;
        Error.throwWithStackTrace(e, st);
      });

  static const _lastUpdateKey = 'ytdlp_last_update_ms';
  static const _updateInterval = Duration(hours: 12);

  Future<void> _init() async {
    await _channel.invokeMethod('init');
    try {
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getInt(_lastUpdateKey) ?? 0;
      final age = DateTime.now().millisecondsSinceEpoch - last;
      if (age > _updateInterval.inMilliseconds) {
        await _channel.invokeMethod('update').timeout(const Duration(seconds: 60));
        await prefs.setInt(_lastUpdateKey, DateTime.now().millisecondsSinceEpoch);
      }
    } catch (_) {}
  }

  List<String> _withoutFfmpegLocation(List<String> args) {
    final cleaned = <String>[];
    for (var i = 0; i < args.length; i++) {
      if (args[i] == '--ffmpeg-location') {
        i++;
        continue;
      }
      cleaned.add(args[i]);
    }
    return cleaned;
  }

  Future<ProcessResult> _execute(
    List<String> args,
    Duration timeout, {
    void Function(String line)? onStdoutLine,
  }) async {
    await _ensureInit();
    final id = 'y${_nextId++}';
    if (onStdoutLine != null) _lineListeners[id] = onStdoutLine;
    try {
      final result = await _channel
          .invokeMapMethod<String, dynamic>('execute', {'args': _withoutFfmpegLocation(args), 'id': id}).timeout(timeout);
      return ProcessResult(0, result!['exitCode'] as int, result['stdout'] as String, result['stderr'] as String);
    } on TimeoutException {
      await _channel.invokeMethod('cancel', {'id': id});
      rethrow;
    } finally {
      _lineListeners.remove(id);
    }
  }

  @override
  Future<ProcessResult> runYtDlp(List<String> args, Duration timeout, {String? timeoutMessage}) async {
    try {
      return await _execute(args, timeout);
    } on TimeoutException {
      throw TimeoutException(timeoutMessage ?? 'yt-dlp ne répond plus après ${timeout.inSeconds}s.');
    }
  }

  @override
  Future<ProcessResult> runYtDlpKillable(
    List<String> args,
    Duration timeout, {
    void Function(String line)? onStdoutLine,
  }) async {
    try {
      return await _execute(args, timeout, onStdoutLine: onStdoutLine);
    } on TimeoutException {
      throw TimeoutException('Le téléchargement ne répond plus après ${timeout.inSeconds}s.');
    }
  }

  @override
  Future<List<String>> ffmpegLocationArgs() async => const [];

  @override
  Future<String?> resolveFfmpegPath() async => null;

  @override
  Future<Duration?> probeDuration(String filePath) async {
    final player = Player();
    try {
      await player.open(Media(filePath), play: false);
      return await player.stream.duration
          .firstWhere((d) => d > Duration.zero)
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      return null;
    } finally {
      await player.dispose();
    }
  }
}
