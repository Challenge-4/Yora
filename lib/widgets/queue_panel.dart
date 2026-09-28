import 'package:flutter/material.dart';
import '../presenters/track_presenter.dart';
import '../state/library_state.dart';
import '../state/playback_state.dart';
import '../theme/app_palette.dart';
import '../theme/app_theme.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/playlist_display_name.dart';
import '../utils/platform_paths.dart';
import 'hover_underline_text.dart';

class QueuePanel extends StatefulWidget {
  final PlaybackState playback;
  final LibraryState library;
  final TrackPresenter trackPresenter;
  final VoidCallback onClose;
  final void Function(int queueIndex) onJumpToQueueIndex;
  final void Function(String path) onPlayRecentTrack;
  final VoidCallback onClearCustomQueue;
  final void Function(int index) onRemoveFromCustomQueue;
  final void Function(int index) onRemoveFromAutomaticQueue;
  final void Function(int oldIndex, int newIndex) onReorderCustomQueue;
  final void Function(int oldPos, int newPos) onReorderUpcoming;
  final void Function(String artistName) onViewArtist;
  final double width;
  final double maxHeight;

  const QueuePanel({
    super.key,
    this.width = 300,
    this.maxHeight = 480,
    required this.playback,
    required this.library,
    required this.trackPresenter,
    required this.onClose,
    required this.onJumpToQueueIndex,
    required this.onPlayRecentTrack,
    required this.onClearCustomQueue,
    required this.onRemoveFromCustomQueue,
    required this.onRemoveFromAutomaticQueue,
    required this.onReorderCustomQueue,
    required this.onReorderUpcoming,
    required this.onViewArtist,
  });

  @override
  State<QueuePanel> createState() => _QueuePanelState();
}

class _QueuePanelState extends State<QueuePanel> {
  bool _showingRecentlyPlayed = false;

  List<String> _recentlyPlayedPaths() {
    final referenced = <String>{...widget.library.musicPaths};
    for (final playlist in widget.library.musicPlaylists.values) {
      referenced.addAll(playlist['tracks'] as List<String>);
    }
    final entries = widget.library.trackLastPlayedDates.entries.where((e) => referenced.contains(e.key)).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(30).map((e) => e.key).toList();
  }

  static const _maxUpcoming = 40;

  List<int> _upcomingAutomaticQueueIndices() {
    final playback = widget.playback;
    if (playback.queueIndex < 0 || playback.queueIndex >= playback.queue.length) return [];
    if (playback.shuffle && playback.shuffleIndices.isNotEmpty) {
      final pos = playback.shuffleIndices.indexOf(playback.queueIndex);
      if (pos == -1) return [];
      return playback.shuffleIndices.sublist(pos + 1).take(_maxUpcoming).toList();
    }
    return [
      for (var i = playback.queueIndex + 1; i < playback.queue.length && i <= playback.queueIndex + _maxUpcoming; i++) i,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.paletteOf(context);
    final playback = widget.playback;
    final currentPath = playback.currentPlayingPath;
    final upcomingAutomatic = _upcomingAutomaticQueueIndices();
    final recentlyPlayed = _recentlyPlayedPaths();

    return Material(
      color: Colors.transparent,
      child: Container(
        width: widget.width,
        constraints: BoxConstraints(maxHeight: widget.maxHeight),
        decoration: BoxDecoration(
          color: Color.alphaBlend(palette.cardHover, Colors.black),
          borderRadius: isMobile ? const BorderRadius.vertical(top: Radius.circular(16)) : BorderRadius.circular(8),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 18, offset: Offset(0, 8))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isMobile) ...[_buildDragHandle(palette), _buildMobileHeader(palette)] else
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 8, 0),
              child: Row(
                children: [
                  _buildTab(AppLocalizations.of(context).queueTabLabel, isRecentTab: false, selected: !_showingRecentlyPlayed, palette: palette),
                  _buildTab(AppLocalizations.of(context).recentlyPlayedTabLabel, isRecentTab: true, selected: _showingRecentlyPlayed, palette: palette),
                  const Spacer(),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(minWidth: isMobile ? 44 : 28, minHeight: isMobile ? 44 : 28),
                    icon: Icon(Icons.close, color: palette.textSecondary, size: 20),
                    mouseCursor: SystemMouseCursors.click,
                    onPressed: widget.onClose,
                  ),
                ],
              ),
            ),
            Divider(color: palette.border, height: 1),
            Flexible(
              child: CustomScrollView(
                slivers: _showingRecentlyPlayed
                    ? _buildRecentlyPlayedSlivers(recentlyPlayed, palette)
                    : _buildQueueSlivers(
                        currentPath: currentPath,
                        upcomingAutomatic: upcomingAutomatic,
                        palette: palette,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDragHandle(AppPalette palette) => Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 6),
        child: Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(color: palette.border, borderRadius: BorderRadius.circular(2)),
          ),
        ),
      );

  Widget _buildMobileHeader(AppPalette palette) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          const SizedBox(width: 12),
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTab(AppLocalizations.of(context).queueTabLabel, isRecentTab: false, selected: !_showingRecentlyPlayed, palette: palette),
                    const SizedBox(width: 8),
                    _buildTab(AppLocalizations.of(context).recentlyPlayedTabLabel, isRecentTab: true, selected: _showingRecentlyPlayed, palette: palette),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.close, color: palette.textSecondary, size: 26),
            onPressed: widget.onClose,
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildTab(String label, {required bool isRecentTab, required bool selected, required AppPalette palette}) {
    return InkWell(
      onTap: () => setState(() => _showingRecentlyPlayed = isRecentTab),
      borderRadius: BorderRadius.circular(6),
      mouseCursor: SystemMouseCursors.click,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 10, vertical: isMobile ? 8 : 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? palette.textPrimary : palette.textSecondary,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                fontSize: isMobile ? 17 : 13,
              ),
            ),
            SizedBox(height: isMobile ? 6 : 4),
            Container(
              height: isMobile ? 3 : 2,
              width: isMobile ? 28 : 20,
              decoration: BoxDecoration(
                color: selected ? AppTheme.of(context).accent : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildQueueSlivers({
    required String? currentPath,
    required List<int> upcomingAutomatic,
    required AppPalette palette,
  }) {
    final customQueue = widget.playback.customQueue;
    if (currentPath == null && customQueue.isEmpty && upcomingAutomatic.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(AppLocalizations.of(context).nothingPlayingMessage, style: TextStyle(color: palette.textSecondary)),
          ),
        ),
      ];
    }
    final sourcePlaylist = widget.playback.currentQueueSourcePlaylist;
    return [
      const SliverToBoxAdapter(child: SizedBox(height: 8)),
      if (currentPath != null)
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel(AppLocalizations.of(context).currentlyPlayingSectionLabel, palette),
              _trackRow(currentPath, palette, highlighted: true, onTap: null),
            ],
          ),
        ),
      if (customQueue.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: _sectionLabel(AppLocalizations.of(context).upNextInCustomQueueLabel, palette, trailing: _clearQueueButton(palette)),
        ),
        SliverReorderableList(
          itemCount: customQueue.length,
          onReorderItem: widget.onReorderCustomQueue,
          proxyDecorator: (child, index, animation) => _dragProxy(child, palette),
          itemBuilder: (context, i) => _reorderableRow(
            key: ValueKey('custom:$i:${customQueue[i]}'),
            index: i,
            child: _trackRow(
              customQueue[i],
              palette,
              onTap: null,
              onRemove: () => widget.onRemoveFromCustomQueue(i),
              reorderable: true,
            ),
          ),
        ),
      ],
      if (upcomingAutomatic.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: _sectionLabel(
            sourcePlaylist != null
                ? AppLocalizations.of(context).upNextInPlaylistLabel(playlistDisplayName(sourcePlaylist, AppLocalizations.of(context)))
                : AppLocalizations.of(context).upNextLabel,
            palette,
          ),
        ),
        SliverReorderableList(
          itemCount: upcomingAutomatic.length,
          onReorderItem: widget.onReorderUpcoming,
          proxyDecorator: (child, index, animation) => _dragProxy(child, palette),
          itemBuilder: (context, i) {
            final index = upcomingAutomatic[i];
            return _reorderableRow(
              key: ValueKey('auto:$index:${widget.playback.queue[index]}'),
              index: i,
              child: _trackRow(
                widget.playback.queue[index],
                palette,
                onTap: () => widget.onJumpToQueueIndex(index),
                onRemove: () => widget.onRemoveFromAutomaticQueue(index),
                reorderable: true,
              ),
            );
          },
        ),
      ],
      const SliverToBoxAdapter(child: SizedBox(height: 8)),
    ];
  }

  Widget _reorderableRow({required Key key, required int index, required Widget child}) {
    return isMobile
        ? ReorderableDelayedDragStartListener(key: key, index: index, child: child)
        : ReorderableDragStartListener(key: key, index: index, child: child);
  }

  Widget _dragProxy(Widget child, AppPalette palette) {
    return Material(
      color: Color.alphaBlend(palette.cardHover, Colors.black),
      elevation: 8,
      borderRadius: BorderRadius.circular(8),
      child: child,
    );
  }

  Widget _clearQueueButton(AppPalette palette) {
    return InkWell(
      onTap: widget.onClearCustomQueue,
      borderRadius: BorderRadius.circular(4),
      mouseCursor: SystemMouseCursors.click,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(
          AppLocalizations.of(context).clearQueueButtonLabel,
          style: TextStyle(color: palette.textSecondary, fontSize: isMobile ? 13 : 11, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  List<Widget> _buildRecentlyPlayedSlivers(List<String> paths, AppPalette palette) {
    if (paths.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(AppLocalizations.of(context).nothingRecentlyPlayedMessage, style: TextStyle(color: palette.textSecondary)),
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        sliver: SliverList.builder(
          itemCount: paths.length,
          itemBuilder: (context, i) => _trackRow(paths[i], palette, onTap: () => widget.onPlayRecentTrack(paths[i])),
        ),
      ),
    ];
  }

  Widget _sectionLabel(String text, AppPalette palette, {Widget? trailing}) {
    return Padding(
      padding: isMobile ? const EdgeInsets.fromLTRB(20, 14, 20, 6) : const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: palette.textSecondary, fontSize: isMobile ? 13 : 11, fontWeight: FontWeight.bold),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  Widget _trackRow(
    String path,
    AppPalette palette, {
    bool highlighted = false,
    required VoidCallback? onTap,
    VoidCallback? onRemove,
    bool reorderable = false,
  }) {
    return InkWell(
      onTap: onTap,
      hoverColor: Colors.transparent,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      mouseCursor: onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: Padding(
        padding: isMobile ? const EdgeInsets.symmetric(horizontal: 20, vertical: 8) : const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            if (reorderable) ...[
              Icon(Icons.drag_handle, size: isMobile ? 22 : 16, color: palette.textSecondary),
              SizedBox(width: isMobile ? 10 : 8),
            ],
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: widget.trackPresenter.thumbnail(path, size: isMobile ? 54 : 40),
            ),
            SizedBox(width: isMobile ? 14 : 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.trackPresenter.title(path),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: highlighted ? AppTheme.of(context).accent : palette.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: isMobile ? 16 : 13,
                    ),
                  ),
                  Builder(builder: (context) {
                    final subtitleStyle = TextStyle(color: palette.textSecondary, fontSize: isMobile ? 14 : 11);
                    final author = widget.library.trackMetadata[path]?['author'];
                    if (author == null || author.isEmpty) {
                      return Text(
                        widget.trackPresenter.subtitle(path),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: subtitleStyle,
                      );
                    }
                    return HoverUnderlineText(
                      text: widget.trackPresenter.subtitle(path),
                      style: subtitleStyle,
                      onTap: widget.onViewArtist,
                    );
                  }),
                ],
              ),
            ),
            if (onRemove != null)
              IconButton(
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(minWidth: isMobile ? 44 : 28, minHeight: isMobile ? 44 : 28),
                icon: Icon(Icons.close, size: isMobile ? 22 : 16, color: palette.textSecondary),
                tooltip: AppLocalizations.of(context).removeFromQueueTooltip,
                mouseCursor: SystemMouseCursors.click,
                onPressed: onRemove,
              ),
          ],
        ),
      ),
    );
  }
}
