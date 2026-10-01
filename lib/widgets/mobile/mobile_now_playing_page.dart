import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/repeat_mode.dart' as yora;
import '../../presenters/track_presenter.dart';
import '../../state/playback_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/artist_names.dart';
import '../../utils/track_formatting.dart';
import 'high_res_cover.dart';

class MobileNowPlayingPage extends StatelessWidget {
  final PlaybackState playback;
  final TrackPresenter trackPresenter;
  final VoidCallback onClose;
  final VoidCallback onOpenQueue;
  final VoidCallback onOpenTrackMenu;
  final VoidCallback onOpenAddToPlaylist;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onToggleShuffle;
  final VoidCallback onCycleRepeat;
  final VoidCallback onToggleLike;
  final void Function(Duration position) onSeek;
  final void Function(String artistName) onViewArtist;

  const MobileNowPlayingPage({
    super.key,
    required this.playback,
    required this.trackPresenter,
    required this.onClose,
    required this.onOpenQueue,
    required this.onOpenTrackMenu,
    required this.onOpenAddToPlaylist,
    required this.onTogglePlayPause,
    required this.onNext,
    required this.onPrevious,
    required this.onToggleShuffle,
    required this.onCycleRepeat,
    required this.onToggleLike,
    required this.onSeek,
    required this.onViewArtist,
  });

  @override
  Widget build(BuildContext context) {
    final path = playback.currentPlayingPath;
    if (path == null) return const SizedBox.shrink();
    final palette = AppTheme.paletteOf(context);
    final themeState = AppTheme.of(context);
    final l10n = AppLocalizations.of(context);
    final liked = trackPresenter.isCurrentTrackLiked;
    final totalMs = playback.duration.inMilliseconds.toDouble();
    final maxMs = totalMs > 0 ? totalMs : 1.0;
    final positionMs = playback.position.inMilliseconds.toDouble().clamp(0.0, maxMs);
    final author = trackPresenter.authorFor(path);
    final base = Color.alphaBlend(palette.background, Colors.black);

    return Material(
      color: base,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [themeState.accent.withValues(alpha: 0.35), base],
            stops: const [0.0, 0.7],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                SizedBox(
                  height: 56,
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.keyboard_arrow_down, color: palette.textPrimary, size: 30),
                        onPressed: onClose,
                      ),
                      Expanded(
                        child: Text(
                          l10n.nowPlayingTitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.more_horiz, color: palette.textPrimary),
                        onPressed: onOpenTrackMenu,
                      ),
                      IconButton(
                        icon: Icon(Icons.queue_music, color: palette.textPrimary),
                        tooltip: l10n.queuePanelTooltip,
                        onPressed: onOpenQueue,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final size = min(constraints.maxWidth, constraints.maxHeight);
                      final coverUrl = trackPresenter.thumbnailUrlFor(path);
                      return Center(
                        child: SizedBox(
                          width: size,
                          height: size,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: coverUrl == null
                                ? trackPresenter.thumbnailFallback(size)
                                : HighResCover(url: coverUrl, placeholder: trackPresenter.thumbnail(path, size: size)),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trackPresenter.title(path),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.bold, fontSize: 22),
                          ),
                          const SizedBox(height: 2),
                          GestureDetector(
                            onTap: author == null || author.isEmpty ? null : () => onViewArtist(splitArtistNames(author).first),
                            child: Text(
                              trackPresenter.subtitle(path),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: palette.textSecondary, fontSize: 15),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.add, color: palette.textPrimary, size: 28),
                      tooltip: l10n.addToPlaylistLabel,
                      onPressed: onOpenAddToPlaylist,
                    ),
                    IconButton(
                      icon: Icon(liked ? Icons.favorite : Icons.favorite_border, color: liked ? themeState.accent : palette.textPrimary, size: 28),
                      onPressed: onToggleLike,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _MobileSeekBar(
                  positionMs: positionMs,
                  maxMs: maxMs,
                  duration: playback.duration,
                  onSeek: onSeek,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(Icons.shuffle, size: 26, color: playback.shuffle ? themeState.accent : palette.textSecondary),
                      onPressed: onToggleShuffle,
                    ),
                    IconButton(
                      icon: Icon(Icons.skip_previous, size: 40, color: palette.textPrimary),
                      onPressed: onPrevious,
                    ),
                    Material(
                      color: palette.textPrimary,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onTogglePlayPause,
                        child: SizedBox(
                          width: 68,
                          height: 68,
                          child: Icon(
                            playback.userPaused ? Icons.play_arrow : Icons.pause,
                            color: base,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.skip_next, size: 40, color: palette.textPrimary),
                      onPressed: onNext,
                    ),
                    IconButton(
                      icon: Icon(
                        playback.repeatMode == yora.RepeatMode.one ? Icons.repeat_one : Icons.repeat,
                        size: 26,
                        color: playback.repeatMode == yora.RepeatMode.off ? palette.textSecondary : themeState.accent,
                      ),
                      onPressed: onCycleRepeat,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileSeekBar extends StatefulWidget {
  final double positionMs;
  final double maxMs;
  final Duration duration;
  final ValueChanged<Duration> onSeek;

  const _MobileSeekBar({
    required this.positionMs,
    required this.maxMs,
    required this.duration,
    required this.onSeek,
  });

  @override
  State<_MobileSeekBar> createState() => _MobileSeekBarState();
}

class _MobileSeekBarState extends State<_MobileSeekBar> {
  double? _dragMs;
  double? _pendingMs;
  Timer? _pendingTimer;

  @override
  void didUpdateWidget(_MobileSeekBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final pending = _pendingMs;
    if (pending != null && (widget.positionMs - pending).abs() < 1500) {
      _pendingTimer?.cancel();
      _pendingMs = null;
    }
  }

  @override
  void dispose() {
    _pendingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.paletteOf(context);
    final shownMs = (_dragMs ?? _pendingMs ?? widget.positionMs).clamp(0.0, widget.maxMs);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: SliderComponentShape.noOverlay,
            activeTrackColor: palette.textPrimary,
            inactiveTrackColor: palette.textPrimary.withValues(alpha: 0.25),
            thumbColor: palette.textPrimary,
          ),
          child: Slider(
            min: 0,
            max: widget.maxMs,
            value: shownMs,
            onChangeStart: (value) => setState(() => _dragMs = value),
            onChanged: (value) => setState(() => _dragMs = value),
            onChangeEnd: (value) {
              widget.onSeek(Duration(milliseconds: value.toInt()));
              _pendingTimer?.cancel();
              _pendingTimer = Timer(const Duration(seconds: 3), () {
                if (mounted) setState(() => _pendingMs = null);
              });
              setState(() {
                _pendingMs = value;
                _dragMs = null;
              });
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(formatDuration(Duration(milliseconds: shownMs.toInt())), style: TextStyle(color: palette.textSecondary, fontSize: 12)),
              Text(formatDuration(widget.duration), style: TextStyle(color: palette.textSecondary, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}
