import 'dart:io';
import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/playlist_display_name.dart';
import '../../presenters/track_presenter.dart';
import '../../state/library_state.dart';
import '../../state/playback_state.dart';
import '../../state/playlist_view_state.dart';
import '../../theme/app_theme.dart';
import '../playing_equalizer_icon.dart';

class MobilePlaylistView extends StatelessWidget {
  final String playlistName;
  final List<String> tracks;
  final List<String> displayTracks;
  final String? playlistImage;
  final String description;
  final bool isLiked;
  final bool isLocalFiles;
  final bool isActivePlaylist;
  final bool showDownloadButton;
  final LibraryState library;
  final PlaybackState playback;
  final PlaylistViewState playlistView;
  final TrackPresenter trackPresenter;
  final VoidCallback onBack;
  final VoidCallback onPlay;
  final VoidCallback onEdit;
  final VoidCallback onSearchToAdd;
  final VoidCallback onSort;
  final VoidCallback onAddLocalFiles;
  final void Function(BuildContext context) onDownloadAll;
  final void Function(int index) onTrackTap;
  final void Function(BuildContext context, Offset position, String path) onTrackMenu;
  final bool canReorder;
  final void Function(int oldIndex, int newIndex) onReorder;

  const MobilePlaylistView({
    super.key,
    required this.playlistName,
    required this.tracks,
    required this.displayTracks,
    required this.playlistImage,
    required this.description,
    required this.isLiked,
    required this.isLocalFiles,
    required this.isActivePlaylist,
    required this.showDownloadButton,
    required this.library,
    required this.playback,
    required this.playlistView,
    required this.trackPresenter,
    required this.onBack,
    required this.onPlay,
    required this.onEdit,
    required this.onSearchToAdd,
    required this.onSort,
    required this.onAddLocalFiles,
    required this.onDownloadAll,
    required this.onTrackTap,
    required this.onTrackMenu,
    required this.canReorder,
    required this.onReorder,
  });

  Widget _header(BuildContext context) {
    final palette = AppTheme.paletteOf(context);
    final themeState = AppTheme.of(context);
    final l10n = AppLocalizations.of(context);
    Widget cover;
    if (playlistImage != null) {
      cover = Image.file(
        File(playlistImage!),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(color: palette.card, child: Icon(Icons.queue_music, size: 64, color: palette.textSecondary)),
      );
    } else if (isLiked) {
      cover = Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [themeState.accentDeep, themeState.accentBright],
          ),
        ),
        child: Icon(Icons.favorite, size: 72, color: themeState.accentForeground),
      );
    } else if (isLocalFiles) {
      cover = Container(color: palette.cardHover, child: Icon(Icons.folder, size: 72, color: palette.textSecondary));
    } else {
      cover = Container(color: themeState.accent.withValues(alpha: 0.3), child: Icon(Icons.queue_music, size: 72, color: palette.textSecondary));
    }
    final playing = isActivePlaylist && !playback.userPaused;
    final summary = tracks.isEmpty
        ? l10n.trackCount(0)
        : '${l10n.trackCount(tracks.length)} • ${trackPresenter.playlistTotalDurationLabel(tracks)}';
    return Column(
      children: [
        Row(
          children: [
            IconButton(icon: Icon(Icons.arrow_back, color: palette.textPrimary), onPressed: onBack),
            const Spacer(),
          ],
        ),
        Container(
          width: 240,
          height: 240,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, 8))],
          ),
          child: ClipRRect(borderRadius: BorderRadius.circular(6), child: cover),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            playlistDisplayName(playlistName, l10n),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 28),
          ),
        ),
        if (description.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
            child: Text(description, textAlign: TextAlign.center, style: TextStyle(color: palette.textSecondary, fontSize: 14)),
          ),
        const SizedBox(height: 6),
        Text(summary, style: TextStyle(color: palette.textSecondary, fontSize: 14)),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
          child: Row(
            children: [
              IconButton(icon: Icon(Icons.edit_outlined, color: palette.textSecondary), onPressed: onEdit),
              IconButton(
                icon: Icon(Icons.search, color: palette.textSecondary),
                tooltip: l10n.searchInPlaylistTooltip,
                onPressed: () => playlistView.toggleSearch(playlistName),
              ),
              if (!isLiked)
                IconButton(
                  icon: Icon(Icons.add, color: palette.textSecondary),
                  onPressed: isLocalFiles ? onAddLocalFiles : onSearchToAdd,
                ),
              if (showDownloadButton)
                IconButton(
                  icon: Icon(Icons.download_for_offline_outlined, color: palette.textSecondary),
                  tooltip: l10n.downloadPlaylistTooltip,
                  onPressed: () => onDownloadAll(context),
                ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  Icons.sort,
                  color: playlistView.sortCriterionFor(playlistName) == null ? palette.textSecondary : themeState.accent,
                ),
                tooltip: l10n.sortByMenuTitle,
                onPressed: onSort,
              ),
              const SizedBox(width: 8),
              Material(
                color: themeState.accent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: displayTracks.isEmpty ? null : onPlay,
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: Icon(
                      playing ? Icons.pause : Icons.play_arrow,
                      color: themeState.accentForeground,
                      size: 34,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (playlistView.isSearchActiveFor(playlistName))
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              autofocus: true,
              style: TextStyle(color: palette.textPrimary, fontSize: 15),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: palette.card,
                prefixIcon: Icon(Icons.search, color: palette.textSecondary, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(Icons.close, size: 18, color: palette.textSecondary),
                  onPressed: () => playlistView.closeSearch(playlistName),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                hintText: l10n.searchTitleOrArtistHint,
                hintStyle: TextStyle(color: palette.textSecondary),
              ),
              onChanged: (v) => playlistView.setSearchQuery(playlistName, v),
            ),
          ),
      ],
    );
  }

  Widget _row(BuildContext context, int index) {
    final palette = AppTheme.paletteOf(context);
    final themeState = AppTheme.of(context);
    final path = displayTracks[index];
    final isCurrent = playback.currentPlayingPath == path;
    final isLoading = playback.loadingQueuePath == path || library.cachingTracks.contains(path);
    final isUnavailable = library.trackMetadata[path]?['unavailable'] == 'true';
    return Builder(
      builder: (rowContext) => InkWell(
        onTap: () => onTrackTap(index),
        child: Opacity(
          opacity: isUnavailable ? 0.4 : 1.0,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
            child: Row(
              children: [
                trackPresenter.thumbnail(path, size: 56),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trackPresenter.title(path),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isCurrent ? themeState.accent : palette.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        trackPresenter.subtitle(path),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: palette.textSecondary, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else if (isCurrent && !playback.userPaused)
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: PlayingEqualizerIcon()),
                IconButton(
                  icon: Icon(Icons.more_vert, color: palette.textSecondary, size: 26),
                  onPressed: () {
                    final box = rowContext.findRenderObject() as RenderBox;
                    final position = box.localToGlobal(Offset(box.size.width - 24, box.size.height / 2));
                    onTrackMenu(rowContext, position, path);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.paletteOf(context);
    final l10n = AppLocalizations.of(context);
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _header(context)),
        if (tracks.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  l10n.emptyPlaylistMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: palette.textSecondary),
                ),
              ),
            ),
          )
        else if (canReorder)
          SliverReorderableList(
            itemCount: displayTracks.length,
            onReorderItem: onReorder,
            proxyDecorator: (child, index, animation) => Material(
              color: Color.alphaBlend(palette.cardHover, Colors.black),
              elevation: 8,
              borderRadius: BorderRadius.circular(8),
              child: child,
            ),
            itemBuilder: (context, index) => ReorderableDelayedDragStartListener(
              key: ValueKey('track:$index:${displayTracks[index]}'),
              index: index,
              child: _row(context, index),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _row(context, index),
              childCount: displayTracks.length,
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }
}
