import 'dart:io';
import 'package:flutter/material.dart';
import '../presenters/track_presenter.dart';
import '../state/library_state.dart';
import '../theme/app_theme.dart';
import '../utils/platform_paths.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/playlist_display_name.dart';
import 'horizontal_card_row.dart';
import 'hover_underline_text.dart';

sealed class RecentAddition {}

class RecentTrackAddition extends RecentAddition {
  final String path;
  RecentTrackAddition(this.path);
}

class RecentPlaylistAddition extends RecentAddition {
  final String name;
  RecentPlaylistAddition(this.name);
}

class HomeView extends StatelessWidget {
  final LibraryState library;
  final TrackPresenter trackPresenter;
  final void Function(String path) onPlayTrack;
  final void Function(String playlistName) onOpenPlaylist;
  final void Function(String artistName) onViewArtist;

  const HomeView({
    super.key,
    required this.library,
    required this.trackPresenter,
    required this.onPlayTrack,
    required this.onOpenPlaylist,
    required this.onViewArtist,
  });

  Set<String> get _referencedPaths {
    final referenced = <String>{...library.musicPaths};
    for (final playlist in library.musicPlaylists.values) {
      referenced.addAll(playlist['tracks'] as List<String>);
    }
    return referenced;
  }

  List<String> _recentlyPlayed() {
    final referenced = _referencedPaths;
    final entries = library.trackLastPlayedDates.entries.where((e) => referenced.contains(e.key)).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(30).map((e) => e.key).toList();
  }

  List<RecentAddition> _recentAdditions() {
    final referenced = _referencedPaths;
    final dated = <(String date, RecentAddition item)>[
      for (final e in library.trackAddedDates.entries)
        if (referenced.contains(e.key)) (e.value, RecentTrackAddition(e.key)),
      for (final e in library.playlistCreatedDates.entries)
        if (library.musicPlaylists.containsKey(e.key)) (e.value, RecentPlaylistAddition(e.key)),
    ]..sort((a, b) => b.$1.compareTo(a.$1));
    return dated.take(30).map((e) => e.$2).toList();
  }

  static const _maxPlaylists = 8;
  List<String> _topPlaylists() {
    final names = library.musicPlaylists.entries
        .where((e) => e.value['isLiked'] != true && e.value['isLocalFiles'] != true)
        .map((e) => e.key)
        .toList()
      ..sort((a, b) => (library.playlistPlayCounts[b] ?? 0).compareTo(library.playlistPlayCounts[a] ?? 0));
    final liked = library.musicPlaylists.entries.where((e) => e.value['isLiked'] == true).map((e) => e.key);
    return [if (isMobile) ...liked, ...names].take(_maxPlaylists).toList();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.paletteOf(context);
    final recentlyPlayed = _recentlyPlayed();
    final recentAdditions = _recentAdditions();
    final topPlaylists = _topPlaylists();
    final titleSize = isMobile ? 22.0 : 20.0;
    final sectionGap = isMobile ? 32.0 : 56.0;
    if (recentlyPlayed.isEmpty && recentAdditions.isEmpty && topPlaylists.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context).emptyHomeMessage,
          style: TextStyle(color: palette.textSecondary),
        ),
      );
    }
    return SizedBox.expand(
      child: SingleChildScrollView(
        padding: isMobile ? const EdgeInsets.fromLTRB(0, 16, 0, 24) : const EdgeInsets.fromLTRB(0, 24, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (topPlaylists.isNotEmpty) ...[
              if (!isMobile) ...[
                Text(AppLocalizations.of(context).playlistsSectionTitle, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.bold, fontSize: titleSize)),
                const SizedBox(height: 16),
              ],
              _buildPlaylistGrid(topPlaylists),
              SizedBox(height: sectionGap),
            ],
            if (recentAdditions.isNotEmpty) ...[
              Text(AppLocalizations.of(context).recentAdditionsSectionTitle, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.bold, fontSize: titleSize)),
              const SizedBox(height: 16),
              HorizontalCardRow<RecentAddition>(
                items: recentAdditions,
                cardWidth: _cardWidth,
                cardHeight: _cardHeight,
                cardBuilder: (addition) => _buildAdditionCard(context, addition),
              ),
              SizedBox(height: sectionGap),
            ],
            if (recentlyPlayed.isNotEmpty) ...[
              Text(AppLocalizations.of(context).recentlyPlayedSectionTitle, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.bold, fontSize: titleSize)),
              const SizedBox(height: 16),
              HorizontalCardRow<String>(
                items: recentlyPlayed,
                cardWidth: _cardWidth,
                cardHeight: _cardHeight,
                cardBuilder: (path) => _buildTrackCard(context, path),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static final _cardWidth = isMobile ? 160.0 : 150.0;
  static final _cardHeight = isMobile ? 236.0 : 220.0;
  static const _playlistTileMaxWidth = 340.0;
  static final _playlistTileHeight = isMobile ? 60.0 : 64.0;
  static const _playlistGridSpacing = 12.0;

  Widget _buildPlaylistGrid(List<String> names) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = isMobile ? 2 : (constraints.maxWidth / (_playlistTileMaxWidth + _playlistGridSpacing)).ceil().clamp(1, 100);
        final rows = <Widget>[];
        for (var i = 0; i < names.length; i += columns) {
          final rowNames = names.sublist(i, (i + columns).clamp(0, names.length));
          rows.add(SizedBox(
            height: _playlistTileHeight,
            child: Row(
              children: [
                for (var j = 0; j < rowNames.length; j++) ...[
                  if (j > 0) const SizedBox(width: _playlistGridSpacing),
                  Expanded(child: _buildPlaylistTile(context, rowNames[j])),
                ],
              ],
            ),
          ));
          if (i + columns < names.length) rows.add(const SizedBox(height: _playlistGridSpacing));
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
      },
    );
  }

  Widget _buildPlaylistTile(BuildContext context, String name) {
    final palette = AppTheme.paletteOf(context);
    final playlist = library.musicPlaylists[name];
    final image = playlist?['image'] as String?;
    return InkWell(
      onTap: () => onOpenPlaylist(name),
      mouseCursor: SystemMouseCursors.click,
      hoverColor: Colors.transparent,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: ColoredBox(
          color: palette.card,
          child: Row(
            children: [
              SizedBox(
                width: _playlistTileHeight,
                height: _playlistTileHeight,
                child: image == null
                    ? (playlist?['isLiked'] == true ? _likedArt(context) : _fallbackArt(context, icon: Icons.queue_music))
                    : Image.file(
                        File(image),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _fallbackArt(context, icon: Icons.queue_music),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  playlistDisplayName(name, AppLocalizations.of(context)),
                  maxLines: isMobile ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w600, fontSize: isMobile ? 15 : 13),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdditionCard(BuildContext context, RecentAddition addition) => switch (addition) {
        RecentTrackAddition(:final path) => _buildTrackCard(context, path),
        RecentPlaylistAddition(:final name) => _buildPlaylistCard(context, name),
      };

  Widget _buildTrackCard(BuildContext context, String path) {
    final palette = AppTheme.paletteOf(context);
    final thumbnailUrl = library.trackMetadata[path]?['thumbnailUrl'];
    return InkWell(
      onTap: () => onPlayTrack(path),
      mouseCursor: SystemMouseCursors.click,
      hoverColor: Colors.transparent,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: thumbnailUrl == null || thumbnailUrl.isEmpty
                  ? _fallbackArt(context)
                  : Image.network(
                      thumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _fallbackArt(context),
                    ),
            ),
            const SizedBox(height: 6),
            Text(
              trackPresenter.title(path),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w600, fontSize: isMobile ? 15 : 13),
            ),
            Builder(builder: (context) {
              final subtitleStyle = TextStyle(color: palette.textSecondary, fontSize: isMobile ? 13 : 11);
              final author = library.trackMetadata[path]?['author'];
              if (author == null || author.isEmpty) {
                return Text(trackPresenter.subtitle(path), maxLines: 1, overflow: TextOverflow.ellipsis, style: subtitleStyle);
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
    );
  }

  Widget _buildPlaylistCard(BuildContext context, String name) {
    final palette = AppTheme.paletteOf(context);
    final playlist = library.musicPlaylists[name];
    final image = playlist?['image'] as String?;
    final trackCount = (playlist?['tracks'] as List<String>?)?.length ?? 0;
    return InkWell(
      onTap: () => onOpenPlaylist(name),
      mouseCursor: SystemMouseCursors.click,
      hoverColor: Colors.transparent,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: image == null
                  ? _fallbackArt(context, icon: Icons.queue_music)
                  : Image.file(
                      File(image),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _fallbackArt(context, icon: Icons.queue_music),
                    ),
            ),
            const SizedBox(height: 6),
            Text(
              playlistDisplayName(name, AppLocalizations.of(context)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w600, fontSize: isMobile ? 15 : 13),
            ),
            Text(
              'Playlist · ${AppLocalizations.of(context).trackCount(trackCount)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: palette.textSecondary, fontSize: isMobile ? 13 : 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _likedArt(BuildContext context) {
    final themeState = AppTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [themeState.accentDeep, themeState.accentBright],
        ),
      ),
      child: Icon(Icons.favorite, color: themeState.accentForeground),
    );
  }

  Widget _fallbackArt(BuildContext context, {IconData icon = Icons.music_note}) {
    final palette = AppTheme.paletteOf(context);
    return Container(
      color: palette.card,
      child: Icon(icon, color: palette.textSecondary),
    );
  }
}
