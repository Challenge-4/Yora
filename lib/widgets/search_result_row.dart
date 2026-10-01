import 'package:flutter/material.dart';
import '../presenters/track_presenter.dart';
import '../services/yt_dlp_service.dart';
import '../state/playback_state.dart';
import '../theme/app_theme.dart';
import '../utils/artist_names.dart';
import '../utils/platform_paths.dart';
import 'hover_underline_text.dart';

class SearchResultRow extends StatelessWidget {
  final YtSearchResult video;
  final PlaybackState playback;
  final TrackPresenter trackPresenter;
  final VoidCallback onTap;
  final VoidCallback onToggleLike;
  final void Function(String artistName)? onViewArtist;
  final void Function(BuildContext context, Offset position) onShowPlaylistPicker;
  final bool large;

  const SearchResultRow({
    super.key,
    required this.video,
    required this.playback,
    required this.trackPresenter,
    required this.onTap,
    required this.onToggleLike,
    required this.onViewArtist,
    required this.onShowPlaylistPicker,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final themeState = AppTheme.of(context);
    final palette = themeState.palette;
    final isCurrentTrack = playback.currentPlayingPath == 'preview:${video.id}';
    final isLoadingThis = playback.loadingPreviewId == video.id;
    final isSelected = isCurrentTrack || isLoadingThis;
    final onlinePath = 'online:${video.id}';
    final likedEntry = trackPresenter.likedPlaylistEntry;
    final isLiked = likedEntry != null && (likedEntry.value['tracks'] as List<String>).contains(onlinePath);
    final largeDesktop = large && !isMobile;
    final thumbSize = isMobile || largeDesktop ? 56.0 : 44.0;
    final iconSize = isMobile ? 26.0 : (largeDesktop ? 20.0 : 16.0);
    final iconPadding = isMobile ? const EdgeInsets.all(8) : EdgeInsets.zero;
    final iconConstraints = isMobile ? null : const BoxConstraints();
    final iconGap = isMobile ? 0.0 : (largeDesktop ? 16.0 : 10.0);
    final titleSize = isMobile ? 16.0 : (largeDesktop ? 15.0 : 13.0);
    final authorSize = isMobile ? 14.0 : (largeDesktop ? 13.0 : 12.0);
    return InkWell(
      onTap: onTap,
      mouseCursor: SystemMouseCursors.click,
      child: Padding(
        padding: isMobile ? const EdgeInsets.fromLTRB(16, 6, 5, 6) : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: thumbSize,
              height: thumbSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: video.thumbnailUrl.isEmpty
                        ? Container(
                            width: thumbSize,
                            height: thumbSize,
                            color: themeState.accent.withValues(alpha: 0.3),
                            child: Icon(Icons.music_note, color: palette.textSecondary),
                          )
                        : Image.network(
                            video.thumbnailUrl,
                            width: thumbSize,
                            height: thumbSize,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              width: thumbSize,
                              height: thumbSize,
                              color: themeState.accent.withValues(alpha: 0.3),
                              child: Icon(Icons.music_note, color: palette.textSecondary),
                            ),
                          ),
                  ),
                  if (isLoadingThis)
                    Container(
                      width: thumbSize,
                      height: thumbSize,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                      ),
                    )
                  else if (isCurrentTrack)
                    Container(
                      width: thumbSize,
                      height: thumbSize,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(
                        playback.isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(width: largeDesktop ? 16 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    video.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected ? themeState.accent : palette.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: titleSize,
                    ),
                  ),
                  SizedBox(height: largeDesktop ? 4 : 2),
                  onViewArtist == null
                      ? Text(
                          video.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: palette.textSecondary, fontSize: authorSize),
                        )
                      : HoverUnderlineText(
                          text: video.author,
                          style: TextStyle(color: palette.textSecondary, fontSize: authorSize),
                          onTap: onViewArtist!,
                        ),
                ],
              ),
            ),
            if (onViewArtist != null && !isMobile) ...[
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(Icons.person_outline, color: palette.textSecondary, size: iconSize),
                mouseCursor: SystemMouseCursors.click,
                onPressed: () => onViewArtist!(splitArtistNames(video.author).first),
              ),
              SizedBox(width: iconGap),
            ],
            IconButton(
              padding: iconPadding,
              constraints: iconConstraints,
              icon: Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                color: isLiked ? themeState.accent : palette.textSecondary,
                size: iconSize,
              ),
              mouseCursor: SystemMouseCursors.click,
              onPressed: onToggleLike,
            ),
            SizedBox(width: iconGap),
            Builder(
              builder: (buttonContext) => IconButton(
                padding: iconPadding,
                constraints: iconConstraints,
                icon: Icon(Icons.add, color: palette.textSecondary, size: iconSize),
                mouseCursor: SystemMouseCursors.click,
                onPressed: () {
                  final box = buttonContext.findRenderObject() as RenderBox;
                  final position = box.localToGlobal(box.size.center(Offset.zero));
                  onShowPlaylistPicker(buttonContext, position);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
