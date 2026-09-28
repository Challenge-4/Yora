import 'package:flutter/material.dart' hide RepeatMode;
import 'package:media_kit/media_kit.dart';
import '../models/repeat_mode.dart';
import '../presenters/track_presenter.dart';
import '../state/playback_state.dart';
import '../state/selection_state.dart';
import '../state/theme_state.dart';
import '../theme/app_theme.dart';
import '../utils/artist_names.dart';
import '../utils/track_formatting.dart';
import '../l10n/generated/app_localizations.dart';

class NowPlayingBar extends StatelessWidget {
  final PlaybackState playback;
  final SelectionState selection;
  final TrackPresenter trackPresenter;
  final Player audioPlayer;
  final GlobalKey audioBarKey;
  final double audioBarHeight;
  final bool nowPlayingExpanded;
  final bool queuePanelOpen;
  final String? downloadingTrackPath;
  final bool bulkDownloadInProgress;
  final bool showDownloadButton;
  final ValueChanged<double> onHeightMeasured;
  final VoidCallback onToggleExpanded;
  final VoidCallback onToggleQueuePanel;
  final Future<void> Function(BuildContext buttonContext, String currentPath) onShowAddCurrentToPlaylistMenu;
  final void Function(String artistName) onViewArtist;
  final VoidCallback onToggleLikeCurrentTrack;
  final VoidCallback onToggleShuffle;
  final VoidCallback onPlayPrevious;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onPlayNext;
  final VoidCallback onCycleRepeatMode;
  final VoidCallback onDownloadCurrentTrack;
  final VoidCallback onToggleMute;
  final ValueChanged<double> onSetVolume;

  const NowPlayingBar({
    super.key,
    required this.playback,
    required this.selection,
    required this.trackPresenter,
    required this.audioPlayer,
    required this.audioBarKey,
    required this.audioBarHeight,
    required this.nowPlayingExpanded,
    required this.queuePanelOpen,
    required this.downloadingTrackPath,
    required this.bulkDownloadInProgress,
    required this.showDownloadButton,
    required this.onHeightMeasured,
    required this.onToggleExpanded,
    required this.onToggleQueuePanel,
    required this.onShowAddCurrentToPlaylistMenu,
    required this.onViewArtist,
    required this.onToggleLikeCurrentTrack,
    required this.onToggleShuffle,
    required this.onPlayPrevious,
    required this.onTogglePlayPause,
    required this.onPlayNext,
    required this.onCycleRepeatMode,
    required this.onDownloadCurrentTrack,
    required this.onToggleMute,
    required this.onSetVolume,
  });

  SliderThemeData _compactSliderTheme(BuildContext context) {
    return SliderTheme.of(context).copyWith(
      trackHeight: 3,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
      overlayShape: SliderComponentShape.noOverlay,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeState = AppTheme.of(context);
    final palette = themeState.palette;
    final currentPath = playback.currentPlayingPath;
    final fileName = currentPath != null ? trackPresenter.title(currentPath) : '';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final height = audioBarKey.currentContext?.size?.height;
      if (height != null && height != audioBarHeight) {
        onHeightMeasured(height);
      }
    });

    return Container(
      key: audioBarKey,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 248,
            child: Row(
              children: [
                _ExpandThumbnailButton(
                  currentPath: currentPath,
                  trackPresenter: trackPresenter,
                  themeState: themeState,
                  nowPlayingExpanded: nowPlayingExpanded,
                  onToggleExpanded: onToggleExpanded,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(fileName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 13)),
                      Builder(builder: (context) {
                        final subtitleStyle = TextStyle(fontFamily: 'Poppins', color: palette.textSecondary, fontSize: 11);
                        final author = currentPath == null ? null : trackPresenter.authorFor(currentPath);
                        if (author == null || author.isEmpty) {
                          return Text(currentPath != null ? trackPresenter.subtitle(currentPath) : '', style: subtitleStyle);
                        }
                        return _EllipsisHoverText(
                          text: splitArtistNames(author).first,
                          style: subtitleStyle,
                          onTap: () => onViewArtist(splitArtistNames(author).first),
                        );
                      }),
                    ],
                  ),
                ),
                if (currentPath != null) const SizedBox(width: 6),
                if (currentPath != null)
                  Builder(
                    builder: (btnContext) => IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      mouseCursor: SystemMouseCursors.click,
                      icon: Icon(Icons.add, color: palette.textSecondary, size: 18),
                      onPressed: () => onShowAddCurrentToPlaylistMenu(btnContext, currentPath),
                    ),
                  ),
                if (currentPath != null) const SizedBox(width: 10),
                if (currentPath != null)
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      trackPresenter.isCurrentTrackLiked ? Icons.favorite : Icons.favorite_border,
                      size: 18,
                      color: trackPresenter.isCurrentTrackLiked ? themeState.accent : palette.textSecondary,
                    ),
                    mouseCursor: SystemMouseCursors.click,
                    onPressed: onToggleLikeCurrentTrack,
                  ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(Icons.shuffle, size: 18, color: playback.shuffle ? themeState.accent : palette.textSecondary),
                      mouseCursor: SystemMouseCursors.click,
                      onPressed: onToggleShuffle,
                    ),
                    const SizedBox(width: 15),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.skip_previous, size: 22),
                      mouseCursor: SystemMouseCursors.click,
                      onPressed: onPlayPrevious,
                    ),
                    const SizedBox(width: 15),
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: palette.textPrimary,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(playback.userPaused ? Icons.play_arrow : Icons.pause, color: palette.background, size: 18),
                        mouseCursor: SystemMouseCursors.click,
                        onPressed: onTogglePlayPause,
                      ),
                    ),
                    const SizedBox(width: 15),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.skip_next, size: 22),
                      mouseCursor: SystemMouseCursors.click,
                      onPressed: onPlayNext,
                    ),
                    const SizedBox(width: 15),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        playback.repeatMode == RepeatMode.one ? Icons.repeat_one : Icons.repeat,
                        size: 18,
                        color: playback.repeatMode == RepeatMode.off ? palette.textSecondary : themeState.accent,
                      ),
                      mouseCursor: SystemMouseCursors.click,
                      onPressed: onCycleRepeatMode,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Row(
                      children: [
                        Text(formatDuration(playback.position), style: TextStyle(fontSize: 10, color: palette.textSecondary)),
                        Expanded(
                          child: SizedBox(
                            height: 20,
                            child: SliderTheme(
                              data: _compactSliderTheme(context),
                              child: Slider(
                                min: 0.0,
                                max: playback.duration.inMilliseconds.toDouble() > 0 ? playback.duration.inMilliseconds.toDouble() : 1.0,
                                value: playback.position.inMilliseconds.toDouble().clamp(0.0, playback.duration.inMilliseconds.toDouble() > 0 ? playback.duration.inMilliseconds.toDouble() : 1.0),
                                onChanged: (value) {
                                  final target = Duration(milliseconds: value.toInt());
                                  audioPlayer.seek(target);
                                },
                              ),
                            ),
                          ),
                        ),
                        Text(formatDuration(playback.duration), style: TextStyle(fontSize: 10, color: palette.textSecondary)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 248,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (showDownloadButton &&
                    ((selection.selectedTrackPaths.length > 1 && selection.selectedTrackPaths.any(isOnlineTrack)) ||
                        (currentPath != null && isOnlineTrack(currentPath)))) ...[
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: (downloadingTrackPath != null || bulkDownloadInProgress)
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: palette.textSecondary),
                          )
                        : Icon(Icons.download_for_offline_outlined, size: 20, color: palette.textSecondary),
                    tooltip: selection.selectedTrackPaths.length > 1
                      ? AppLocalizations.of(context).downloadSelectionTooltip
                      : AppLocalizations.of(context).downloadTrackTooltip,
                    mouseCursor: SystemMouseCursors.click,
                    onPressed: (downloadingTrackPath != null || bulkDownloadInProgress)
                        ? null
                        : onDownloadCurrentTrack,
                  ),
                  const SizedBox(width: 10),
                ],
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(Icons.queue_music, size: 20, color: queuePanelOpen ? themeState.accent : palette.textSecondary),
                  tooltip: AppLocalizations.of(context).queuePanelTooltip,
                  mouseCursor: SystemMouseCursors.click,
                  onPressed: onToggleQueuePanel,
                ),
                const SizedBox(width: 10),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    playback.volume <= 0
                        ? Icons.volume_off
                        : playback.volume < 50
                            ? Icons.volume_down
                            : Icons.volume_up,
                    size: 20,
                    color: palette.textSecondary,
                  ),
                  mouseCursor: SystemMouseCursors.click,
                  onPressed: onToggleMute,
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 110,
                  height: 20,
                  child: SliderTheme(
                    data: _compactSliderTheme(context),
                    child: Slider(
                      min: 0.0,
                      max: 100.0,
                      value: playback.volume.clamp(0.0, 100.0),
                      onChanged: onSetVolume,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpandThumbnailButton extends StatefulWidget {
  final String? currentPath;
  final TrackPresenter trackPresenter;
  final ThemeState themeState;
  final bool nowPlayingExpanded;
  final VoidCallback onToggleExpanded;

  const _ExpandThumbnailButton({
    required this.currentPath,
    required this.trackPresenter,
    required this.themeState,
    required this.nowPlayingExpanded,
    required this.onToggleExpanded,
  });

  @override
  State<_ExpandThumbnailButton> createState() => _ExpandThumbnailButtonState();
}

class _ExpandThumbnailButtonState extends State<_ExpandThumbnailButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        mouseCursor: SystemMouseCursors.click,
        onTap: widget.onToggleExpanded,
        child: Stack(
          alignment: Alignment.center,
          children: [
            widget.currentPath != null
                ? widget.trackPresenter.thumbnail(widget.currentPath!, size: 44)
                : Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: widget.themeState.accent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(Icons.music_note, color: widget.themeState.accentForeground),
                  ),
            if (_hovered)
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  widget.nowPlayingExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                  color: Colors.white,
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EllipsisHoverText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final VoidCallback onTap;

  const _EllipsisHoverText({required this.text, required this.style, required this.onTap});

  @override
  State<_EllipsisHoverText> createState() => _EllipsisHoverTextState();
}

class _EllipsisHoverTextState extends State<_EllipsisHoverText> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Text(
          widget.text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: widget.style.copyWith(decoration: _hovered ? TextDecoration.underline : TextDecoration.none),
        ),
      ),
    );
  }
}
