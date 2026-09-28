import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';

class _YoraAudioHandler extends BaseAudioHandler with SeekHandler {
  final VoidCallback onPlayRequested;
  final VoidCallback onPauseRequested;
  final VoidCallback onNextRequested;
  final VoidCallback onPreviousRequested;
  final void Function(Duration position) onSeekRequested;

  _YoraAudioHandler({
    required this.onPlayRequested,
    required this.onPauseRequested,
    required this.onNextRequested,
    required this.onPreviousRequested,
    required this.onSeekRequested,
  });

  @override
  Future<void> play() async => onPlayRequested();

  @override
  Future<void> pause() async => onPauseRequested();

  @override
  Future<void> skipToNext() async => onNextRequested();

  @override
  Future<void> skipToPrevious() async => onPreviousRequested();

  @override
  Future<void> seek(Duration position) async => onSeekRequested(position);
}

class MediaSessionService {
  static bool get isSupported => Platform.isMacOS || Platform.isLinux || Platform.isAndroid || Platform.isIOS;

  _YoraAudioHandler? _handler;
  bool _initializing = false;

  Future<void> init({
    required VoidCallback onPlay,
    required VoidCallback onPause,
    required VoidCallback onNext,
    required VoidCallback onPrevious,
    required void Function(Duration position) onSeek,
  }) async {
    if (!isSupported || _handler != null || _initializing) return;
    _initializing = true;
    try {
      if (Platform.isIOS) {
        final session = await AudioSession.instance;
        await session.configure(const AudioSessionConfiguration.music());
        await session.setActive(true);
      }
      _handler = await AudioService.init(
        builder: () => _YoraAudioHandler(
          onPlayRequested: onPlay,
          onPauseRequested: onPause,
          onNextRequested: onNext,
          onPreviousRequested: onPrevious,
          onSeekRequested: onSeek,
        ),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.yora.app.playback',
          androidNotificationChannelName: 'Yora',
          androidNotificationIcon: 'drawable/ic_stat_yora',
        ),
      );
    } catch (e) {
      debugPrint('Session multimédia indisponible ($e)');
    } finally {
      _initializing = false;
    }
  }

  void update({
    required String? id,
    required String title,
    required String artist,
    required String? thumbnailUrl,
    required Duration position,
    required Duration duration,
    required bool isPlaying,
  }) {
    final handler = _handler;
    if (handler == null) return;
    if (id == null) {
      handler.mediaItem.add(null);
      handler.playbackState.add(PlaybackState(processingState: AudioProcessingState.idle, playing: false));
      return;
    }
    handler.mediaItem.add(MediaItem(
      id: id,
      title: title,
      artist: artist,
      artUri: thumbnailUrl != null && thumbnailUrl.isNotEmpty ? Uri.tryParse(thumbnailUrl) : null,
      duration: duration > Duration.zero ? duration : null,
    ));
    handler.playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        isPlaying ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {MediaAction.seek, MediaAction.play, MediaAction.pause, MediaAction.skipToNext, MediaAction.skipToPrevious},
      processingState: AudioProcessingState.ready,
      playing: isPlaying,
      updatePosition: position,
    ));
  }
}
