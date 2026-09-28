import 'package:flutter/material.dart';
import '../presenters/track_presenter.dart';
import '../theme/app_theme.dart';

class ExpandedNowPlayingPanel extends StatelessWidget {
  final String? currentPlayingPath;
  final TrackPresenter trackPresenter;

  const ExpandedNowPlayingPanel({
    super.key,
    required this.currentPlayingPath,
    required this.trackPresenter,
  });

  @override
  Widget build(BuildContext context) {
    final currentPath = currentPlayingPath;
    final themeState = AppTheme.of(context);
    return currentPath != null
        ? trackPresenter.thumbnail(currentPath, size: 240)
        : Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              color: themeState.accent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.music_note, color: themeState.accentForeground, size: 48),
          );
  }
}
