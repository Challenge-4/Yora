import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class MediaHotkeyService {
  static const _channel = MethodChannel('dev.leanflutter.plugins/hotkey_manager');
  static const _eventChannel = EventChannel('dev.leanflutter.plugins/hotkey_manager_event');

  static const _vkMediaNextTrack = 0xB0;
  static const _vkMediaPrevTrack = 0xB1;
  static const _vkMediaPlayPause = 0xB3;

  static const _idPlayPause = 'yora_media_play_pause';
  static const _idNext = 'yora_media_next_track';
  static const _idPrevious = 'yora_media_prev_track';

  StreamSubscription<dynamic>? _eventSubscription;
  bool _registered = false;

  Future<void> register({
    required VoidCallback onPlayPause,
    required VoidCallback onNext,
    required VoidCallback onPrevious,
  }) async {
    if (!Platform.isWindows) return;
    if (_registered) return;
    _registered = true;
    try {
      await _registerKey(_idPlayPause, _vkMediaPlayPause);
      await _registerKey(_idNext, _vkMediaNextTrack);
      await _registerKey(_idPrevious, _vkMediaPrevTrack);
    } catch (e) {
      debugPrint('Touches multimédia : enregistrement impossible ($e)');
      return;
    }
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen((event) {
      final map = event as Map<Object?, Object?>?;
      if (map == null || map['type'] != 'onKeyDown') return;
      final identifier = (map['data'] as Map<Object?, Object?>?)?['identifier'] as String?;
      switch (identifier) {
        case _idPlayPause:
          onPlayPause();
        case _idNext:
          onNext();
        case _idPrevious:
          onPrevious();
      }
    });
  }

  Future<void> _registerKey(String identifier, int keyCode) {
    return _channel.invokeMethod('register', {
      'identifier': identifier,
      'keyCode': keyCode,
      'modifiers': <String>[],
    });
  }

  Future<void> unregisterAll() async {
    if (!_registered) return;
    _registered = false;
    await _eventSubscription?.cancel();
    _eventSubscription = null;
    try {
      await _channel.invokeMethod('unregisterAll');
    } catch (_) {}
  }
}
