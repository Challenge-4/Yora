import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/sort_criterion_labels.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/playlist_display_name.dart';
import '../presenters/track_presenter.dart';
import '../state/library_state.dart';
import '../state/playback_state.dart';
import '../state/playlist_view_state.dart';
import '../state/selection_state.dart';
import '../theme/app_theme.dart';
import 'hover_underline_text.dart';
import 'mouse_region_with_hover_overlay.dart';
import 'playing_equalizer_icon.dart';

class PlaylistDetailView extends StatelessWidget {
  final String playlistName;
  final List<String> tracks;
  final List<String> displayTracks;
  final String? playlistImage;
  final String description;
  final bool isLiked;
  final bool isLocalFiles;
  final bool isActivePlaylist;
  final bool canReorderTracks;
  final LibraryState library;
  final PlaybackState playback;
  final SelectionState selection;
  final PlaylistViewState playlistView;
  final TrackPresenter trackPresenter;
  final LayerLink sortControlLayerLink;
  final String Function(String path) trackDurationLabel;
  final void Function(String path) onToggleTrackSelection;
  final void Function(String path) onSelectSingleTrack;
  final VoidCallback onClearSelection;
  final Future<void> Function(List<String> queue, int index, {String? sourcePlaylist}) onTrackTap;
  final Future<void> Function(BuildContext context, Offset position, Set<String> paths, {List<String>? removeFromTracks}) onShowAddToPlaylistMenu;
  final void Function(String path) onReorderStart;
  final VoidCallback onReorderEnd;
  final void Function(int oldIndex, int newIndex) onReorder;
  final void Function({bool autoPickImage}) onEditPlaylist;
  final VoidCallback onTogglePlayPause;
  final void Function(List<String> tracks, int startIndex, {String? sourcePlaylist, bool shuffleFromStart}) onStartQueue;
  final VoidCallback onAddFilesToPlaylist;
  final void Function(BuildContext context) onDownloadAllOnlineTracks;
  final bool showDownloadButton;
  final void Function(String artistName) onViewArtist;
  final ValueChanged<bool> onPlaylistSearchFocusChange;
  final VoidCallback onToggleSortMenu;

  const PlaylistDetailView({
    super.key,
    required this.playlistName,
    required this.tracks,
    required this.displayTracks,
    required this.playlistImage,
    required this.description,
    required this.isLiked,
    required this.isLocalFiles,
    required this.isActivePlaylist,
    required this.canReorderTracks,
    required this.library,
    required this.playback,
    required this.selection,
    required this.playlistView,
    required this.trackPresenter,
    required this.sortControlLayerLink,
    required this.trackDurationLabel,
    required this.onToggleTrackSelection,
    required this.onSelectSingleTrack,
    required this.onClearSelection,
    required this.onTrackTap,
    required this.onShowAddToPlaylistMenu,
    required this.onReorderStart,
    required this.onReorderEnd,
    required this.onReorder,
    required this.onEditPlaylist,
    required this.onTogglePlayPause,
    required this.onStartQueue,
    required this.onAddFilesToPlaylist,
    required this.onDownloadAllOnlineTracks,
    required this.showDownloadButton,
    required this.onViewArtist,
    required this.onPlaylistSearchFocusChange,
    required this.onToggleSortMenu,
  });

  Widget _selectionCountBadge(BuildContext context, int count) {
    final themeState = AppTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: themeState.accent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        AppLocalizations.of(context).trackCount(count),
        style: TextStyle(color: themeState.accentForeground, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _sortableColumnHeader(
    BuildContext context,
    String label,
    String? criterion, {
    bool alignRight = false,
  }) {
    final palette = AppTheme.paletteOf(context);
    final isActive = playlistView.sortCriterionFor(playlistName) == criterion;
    final ascending = playlistView.sortAscendingFor(playlistName);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => playlistView.handleColumnSortTap(playlistName, criterion),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (alignRight && isActive) ...[
            Icon(ascending ? Icons.arrow_drop_up : Icons.arrow_drop_down, size: 16, color: palette.textPrimary),
            const SizedBox(width: 2),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: TextStyle(
                color: isActive ? palette.textPrimary : palette.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (!alignRight && isActive) ...[
            const SizedBox(width: 4),
            Icon(ascending ? Icons.arrow_drop_up : Icons.arrow_drop_down, size: 16, color: palette.textPrimary),
          ],
        ],
      ),
      ),
    );
  }

  Widget _trackRow(BuildContext context, int index) {
    final palette = AppTheme.paletteOf(context);
    final path = displayTracks[index];
    final fileName = trackPresenter.title(path);
    final isCurrentTrack = playback.currentPlayingPath == path;
    final isLoadingThis = playback.loadingQueuePath == path || library.cachingTracks.contains(path);
    final isSelected = selection.selectedTrackPaths.contains(path);
    final isUnavailable = library.trackMetadata[path]?['unavailable'] == 'true';

    final row = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (HardwareKeyboard.instance.isControlPressed) {
          onToggleTrackSelection(path);
          return;
        }
        if (selection.selectedTrackPaths.length == 1 && selection.selectedTrackPaths.contains(path)) {
          onTrackTap(displayTracks, index, sourcePlaylist: playlistName);
        } else {
          onSelectSingleTrack(path);
        }
      },
      onSecondaryTapUp: (details) async {
        if (!selection.selectedTrackPaths.contains(path)) {
          onSelectSingleTrack(path);
        }
        await onShowAddToPlaylistMenu(
          context,
          details.globalPosition,
          Set<String>.from(selection.selectedTrackPaths),
          removeFromTracks: tracks,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? palette.textPrimary.withValues(alpha: 0.14)
              : isCurrentTrack
                  ? palette.textPrimary.withValues(alpha: 0.08)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Opacity(
        opacity: isUnavailable ? 0.4 : 1.0,
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: Center(
                child: isLoadingThis
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : isCurrentTrack
                        ? (playback.userPaused
                            ? Icon(Icons.pause, color: palette.textPrimary, size: 16)
                            : const PlayingEqualizerIcon())
                        : Text('${index + 1}', style: TextStyle(color: palette.textSecondary, fontSize: 13)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 5,
              child: Row(
                children: [
                  trackPresenter.thumbnail(path),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          fileName,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: isCurrentTrack ? AppTheme.of(context).accent : palette.textPrimary,
                            fontWeight: isCurrentTrack ? FontWeight.bold : FontWeight.normal,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Builder(builder: (context) {
                          final subtitleStyle = TextStyle(fontFamily: 'Poppins', color: palette.textSecondary, fontSize: 11);
                          final author = library.trackMetadata[path]?['author'];
                          if (author == null || author.isEmpty) {
                            return Text(trackPresenter.subtitle(path), style: subtitleStyle, overflow: TextOverflow.ellipsis);
                          }
                          return HoverUnderlineText(
                            text: trackPresenter.subtitle(path),
                            style: subtitleStyle,
                            onTap: onViewArtist,
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Text(
                trackPresenter.album(path),
                style: TextStyle(color: palette.textSecondary, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Text(
                trackPresenter.addedDateLabel(path),
                style: TextStyle(color: palette.textSecondary, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 70,
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(trackDurationLabel(path), style: TextStyle(color: palette.textSecondary, fontSize: 13)),
              ),
            ),
          ],
        ),
        ),
      ),
      ),
    );

    final isFirstSelected = selection.selectedTrackPaths.length > 1 && selection.selectedTrackPaths.first == path;
    final suppressForActiveDrag = selection.reorderDraggedPath != null && selection.reorderDraggedPath != path;
    final rowWithBadge = (isFirstSelected && !suppressForActiveDrag)
        ? Stack(
            clipBehavior: Clip.none,
            children: [
              row,
              Positioned(
                right: 8,
                top: -8,
                child: _selectionCountBadge(context, selection.selectedTrackPaths.length),
              ),
            ],
          )
        : row;

    if (!canReorderTracks) {
      return KeyedSubtree(key: ValueKey(path), child: rowWithBadge);
    }
    return ReorderableDragStartListener(
      key: ValueKey(path),
      index: index,
      child: rowWithBadge,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.paletteOf(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onClearSelection,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            MouseRegionWithHoverOverlay(
              playlistName: playlistName,
              playlistImage: playlistImage,
              isLiked: isLiked,
              isLocalFiles: isLocalFiles,
              onEdit: () => onEditPlaylist(autoPickImage: true),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppLocalizations.of(context).publicPlaylistLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: palette.textSecondary)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => onEditPlaylist(),
                    hoverColor: Colors.transparent,
                    mouseCursor: SystemMouseCursors.click,
                    child: Tooltip(
                      message: AppLocalizations.of(context).editPlaylistTitle,
                      child: Text(
                        playlistDisplayName(playlistName, AppLocalizations.of(context)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: palette.textPrimary),
                      ),
                    ),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(description, style: TextStyle(color: palette.textSecondary, fontSize: 14)),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    tracks.isEmpty
                        ? AppLocalizations.of(context).trackCount(tracks.length)
                        : '${AppLocalizations.of(context).trackCount(tracks.length)} • ${trackPresenter.playlistTotalDurationLabel(tracks)}',
                    style: TextStyle(color: palette.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 30),
        LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        return Row(
          children: [
            IconButton(
              tooltip: isActivePlaylist && !playback.userPaused ? AppLocalizations.of(context).pauseTooltip : AppLocalizations.of(context).playTooltip,
              mouseCursor: SystemMouseCursors.click,
              icon: Icon(
                isActivePlaylist && !playback.userPaused ? Icons.pause_circle_filled : Icons.play_circle_fill,
                color: palette.textPrimary,
                size: 44,
              ),
              onPressed: displayTracks.isEmpty
                  ? null
                  : () {
                      if (isActivePlaylist) {
                        onTogglePlayPause();
                      } else {
                        onStartQueue(displayTracks, 0, sourcePlaylist: playlistName, shuffleFromStart: true);
                      }
                    },
            ),
            const SizedBox(width: 4),
            if (compact)
              IconButton(
                tooltip: AppLocalizations.of(context).addButtonLabel,
                icon: Icon(Icons.add, color: palette.textPrimary, size: 22),
                mouseCursor: SystemMouseCursors.click,
                onPressed: onAddFilesToPlaylist,
              )
            else
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.inputBackground,
                  foregroundColor: palette.textPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: onAddFilesToPlaylist,
                icon: const Icon(Icons.add, size: 18),
                label: Text(AppLocalizations.of(context).addButtonLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            SizedBox(width: compact ? 4 : 12),
            if (compact)
              IconButton(
                tooltip: AppLocalizations.of(context).editInfoButtonLabel,
                icon: Icon(Icons.edit_outlined, color: palette.textPrimary, size: 22),
                mouseCursor: SystemMouseCursors.click,
                onPressed: () => onEditPlaylist(),
              )
            else
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: palette.textPrimary,
                  side: BorderSide(color: palette.border),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: () => onEditPlaylist(),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(AppLocalizations.of(context).editInfoButtonLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            if (showDownloadButton) ...[
              const SizedBox(width: 4),
              IconButton(
                tooltip: AppLocalizations.of(context).downloadPlaylistTooltip,
                icon: Icon(Icons.download_for_offline_outlined, color: palette.textSecondary, size: 30),
                mouseCursor: SystemMouseCursors.click,
                onPressed: () => onDownloadAllOnlineTracks(context),
              ),
            ],
            if (playlistView.isSearchActiveFor(playlistName))
              Expanded(
                child: Align(
                alignment: Alignment.centerRight,
                child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: Focus(
                  onFocusChange: (hasFocus) {
                    onPlaylistSearchFocusChange(hasFocus);
                    if (!hasFocus && playlistView.searchQueryFor(playlistName).isEmpty) {
                      playlistView.closeSearch(playlistName);
                    }
                  },
                  child: TextField(
                    autofocus: true,
                    style: TextStyle(color: palette.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: Icon(Icons.search, color: palette.textSecondary, size: 18),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.close, size: 16, color: palette.textSecondary),
                        onPressed: () => playlistView.closeSearch(playlistName),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                      hintText: AppLocalizations.of(context).searchTitleOrArtistHint,
                      hintStyle: TextStyle(color: palette.textSecondary),
                    ),
                    onChanged: (v) => playlistView.setSearchQuery(playlistName, v),
                  ),
                ),
                ),
                ),
              )
            else ...[
              const Spacer(),
              IconButton(
                tooltip: AppLocalizations.of(context).searchInPlaylistTooltip,
                icon: Icon(Icons.search, color: palette.textSecondary, size: 22),
                mouseCursor: SystemMouseCursors.click,
                onPressed: () => playlistView.openSearch(playlistName),
              ),
            ],
            const SizedBox(width: 12),
            CompositedTransformTarget(
              link: sortControlLayerLink,
              child: GestureDetector(
                onTap: onToggleSortMenu,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!compact) ...[
                        Text(
                          playlistView.sortCriterionFor(playlistName) == null
                              ? AppLocalizations.of(context).sortByCustomOption
                              : sortCriterionLabelsFor(AppLocalizations.of(context))[playlistView.sortCriterionFor(playlistName)]!,
                          style: TextStyle(color: palette.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Icon(Icons.sort, color: palette.textSecondary, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
        }),
        const SizedBox(height: 20),

        Divider(color: palette.border),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Builder(builder: (context) {
            final activeCriterion = playlistView.sortCriterionFor(playlistName);
            final titleSlotShowsAlt = activeCriterion == 'artist' || activeCriterion == 'releaseDate';
            return Row(
              children: [
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => playlistView.handleColumnSortTap(playlistName, null),
                    child: SizedBox(
                      width: 30,
                      child: Center(
                        child: Text('#', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 5,
                  child: _sortableColumnHeader(
                    context,
                    titleSlotShowsAlt ? sortCriterionLabelsFor(AppLocalizations.of(context))[activeCriterion]! : AppLocalizations.of(context).sortByTitleOption,
                    titleSlotShowsAlt ? activeCriterion : 'title',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(flex: 3, child: _sortableColumnHeader(context, AppLocalizations.of(context).sortByAlbumOption, 'album')),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: _sortableColumnHeader(context, AppLocalizations.of(context).sortByRecentlyAddedOption, 'recentlyAdded')),
                const SizedBox(width: 12),
                SizedBox(
                  width: 70,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => playlistView.handleColumnSortTap(playlistName, 'duration'),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 16,
                              color: playlistView.sortCriterionFor(playlistName) == 'duration' ? palette.textPrimary : palette.textSecondary,
                            ),
                            Opacity(
                              opacity: playlistView.sortCriterionFor(playlistName) == 'duration' ? 1 : 0,
                              child: Icon(
                                playlistView.sortAscendingFor(playlistName) ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                                size: 12,
                                color: palette.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),
        ),
        Divider(color: palette.border),
        if (tracks.isEmpty)
          Padding(
            padding: const EdgeInsets.all(40.0),
            child: Center(
              child: Text(
                AppLocalizations.of(context).emptyPlaylistMessage,
                style: TextStyle(color: palette.textSecondary),
              ),
            ),
          )
        else if (displayTracks.isEmpty)
          Padding(
            padding: const EdgeInsets.all(40.0),
            child: Center(
              child: Text(
                AppLocalizations.of(context).noSearchResultsInPlaylistMessage,
                style: TextStyle(color: palette.textSecondary),
              ),
            ),
          ),
                ],
              ),
            ),
          ),
          if (tracks.isNotEmpty && displayTracks.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(8, 0, 16, 8),
              sliver: canReorderTracks
                  ? SliverReorderableList(
                      itemBuilder: _trackRow,
                      itemCount: displayTracks.length,
                      onReorderItem: (oldIndex, newIndex) => onReorder(oldIndex, newIndex),
                      onReorderStart: (index) => onReorderStart(displayTracks[index]),
                      onReorderEnd: (index) => onReorderEnd(),
                      proxyDecorator: (child, index, animation) {
                        final draggedPath = displayTracks[index];
                        final count = selection.selectedTrackPaths.length;
                        if (count <= 1 ||
                            !selection.selectedTrackPaths.contains(draggedPath) ||
                            selection.selectedTrackPaths.first == draggedPath) {
                          return Material(color: Colors.transparent, child: child);
                        }
                        return Material(
                          color: Colors.transparent,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              child,
                              Positioned(
                                right: 8,
                                top: -8,
                                child: _selectionCountBadge(context, count),
                              ),
                            ],
                          ),
                        );
                      },
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        _trackRow,
                        childCount: displayTracks.length,
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}
