import 'package:flutter/material.dart';
import '../../services/yt_dlp_service.dart';
import '../../theme/app_theme.dart';

class MobileAddTrackRow extends StatelessWidget {
  final YtSearchResult video;
  final bool isInPlaylist;
  final bool isLiked;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onToggleLike;
  final VoidCallback onToggleAdd;

  const MobileAddTrackRow({
    super.key,
    required this.video,
    required this.isInPlaylist,
    required this.isLiked,
    required this.isPlaying,
    required this.onTap,
    required this.onLongPress,
    required this.onToggleLike,
    required this.onToggleAdd,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.paletteOf(context);
    final themeState = AppTheme.of(context);
    Widget fallback() => Container(
          color: themeState.accent.withValues(alpha: 0.3),
          child: Icon(Icons.music_note, color: palette.textSecondary),
        );
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: 56,
                height: 56,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    video.thumbnailUrl.isEmpty
                        ? fallback()
                        : Image.network(video.thumbnailUrl, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback()),
                    Container(color: Colors.black.withValues(alpha: 0.25)),
                    Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 30),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isPlaying ? themeState.accent : palette.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    video.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: palette.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                size: 26,
                color: isLiked ? themeState.accent : palette.textPrimary.withValues(alpha: 0.8),
              ),
              onPressed: onToggleLike,
            ),
            IconButton(
              icon: Icon(
                isInPlaylist ? Icons.check_circle : Icons.add_circle_outline,
                size: 28,
                color: isInPlaylist ? themeState.accent : palette.textPrimary.withValues(alpha: 0.8),
              ),
              onPressed: onToggleAdd,
            ),
          ],
        ),
      ),
    );
  }
}
