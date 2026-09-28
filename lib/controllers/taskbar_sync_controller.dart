import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../state/playback_state.dart';
import '../presenters/track_presenter.dart';
import '../l10n/generated/app_localizations.dart';

class TaskbarSyncController {
  final PlaybackState playback;
  final TrackPresenter trackPresenter;
  final AppLocalizations Function() l10n;

  TaskbarSyncController(this.playback, this.trackPresenter, this.l10n);

  static const MethodChannel _channel = MethodChannel('yora/taskbar');

  String _iconPath(String asset) {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    return '$exeDir${Platform.pathSeparator}data${Platform.pathSeparator}flutter_assets${Platform.pathSeparator}$asset';
  }

  void update() {
    if (!Platform.isWindows) return;
    final hasCurrentTrack = playback.currentPlayingPath != null;
    unawaited(_channel.invokeMethod('setThumbnailToolbar', [
      {
        'icon': _iconPath(trackPresenter.isCurrentTrackLiked
            ? 'assets/taskbar_icons/heart_filled.ico'
            : 'assets/taskbar_icons/heart_outline.ico'),
        'tooltip': trackPresenter.isCurrentTrackLiked ? l10n().removeFromLikedTooltip : l10n().addToLikedTooltip,
        'enabled': hasCurrentTrack,
      },
      {
        'icon': _iconPath('assets/taskbar_icons/previous.ico'),
        'tooltip': l10n().previousTooltip,
        'enabled': true,
      },
      {
        'icon': _iconPath(playback.userPaused ? 'assets/taskbar_icons/play.ico' : 'assets/taskbar_icons/pause.ico'),
        'tooltip': playback.userPaused ? l10n().playTooltip : l10n().pauseTooltip,
        'enabled': hasCurrentTrack,
      },
      {
        'icon': _iconPath('assets/taskbar_icons/next.ico'),
        'tooltip': l10n().nextTooltip,
        'enabled': true,
      },
    ]).catchError((Object e) {
      debugPrint('setThumbnailToolbar ignoré (fenêtre pas encore prête) : $e');
    }));
  }
}
