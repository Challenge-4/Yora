import 'package:flutter/material.dart';
import '../../presenters/track_presenter.dart';
import '../../state/playback_state.dart';
import '../../theme/app_theme.dart';

class MobileMiniPlayer extends StatelessWidget {
  final PlaybackState playback;
  final TrackPresenter trackPresenter;
  final VoidCallback onOpen;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onToggleLike;
  final void Function(BuildContext context) onOpenAddToPlaylist;

  const MobileMiniPlayer({
    super.key,
    required this.playback,
    required this.trackPresenter,
    required this.onOpen,
    required this.onTogglePlayPause,
    required this.onToggleLike,
    required this.onOpenAddToPlaylist,
  });

  @override
  Widget build(BuildContext context) {
    final path = playback.currentPlayingPath;
    if (path == null) return const SizedBox.shrink();
    final palette = AppTheme.paletteOf(context);
    final themeState = AppTheme.of(context);
    final liked = trackPresenter.isCurrentTrackLiked;
    final total = playback.duration.inMilliseconds;
    final progress = total > 0 ? (playback.position.inMilliseconds / total).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Material(
        color: Color.alphaBlend(themeState.accent.withValues(alpha: 0.18), palette.cardHover),
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 4, 6),
                child: Row(
                  children: [
                    ClipRRect(borderRadius: BorderRadius.circular(6), child: trackPresenter.thumbnail(path, size: 48)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            trackPresenter.title(path),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            trackPresenter.subtitle(path),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: palette.textPrimary.withValues(alpha: 0.7), fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Builder(
                      builder: (buttonContext) => IconButton(
                        iconSize: 26,
                        icon: Icon(Icons.add, color: palette.textPrimary),
                        onPressed: () => onOpenAddToPlaylist(buttonContext),
                      ),
                    ),
                    IconButton(
                      iconSize: 28,
                      icon: Icon(
                        liked ? Icons.favorite : Icons.favorite_border,
                        color: liked ? themeState.accent : palette.textPrimary,
                      ),
                      onPressed: onToggleLike,
                    ),
                    IconButton(
                      iconSize: 34,
                      icon: Icon(playback.userPaused ? Icons.play_arrow : Icons.pause, color: palette.textPrimary),
                      onPressed: onTogglePlayPause,
                    ),
                  ],
                ),
              ),
              LinearProgressIndicator(
                value: progress,
                minHeight: 2.5,
                backgroundColor: palette.textPrimary.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation(palette.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
