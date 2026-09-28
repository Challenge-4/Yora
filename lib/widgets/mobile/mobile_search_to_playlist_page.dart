import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/playlist_display_name.dart';
import '../../services/yt_dlp_service.dart';
import '../../theme/app_theme.dart';
import '../top_search_bar.dart';

class MobileSearchToPlaylistPage extends StatelessWidget {
  final String playlistName;
  final TextEditingController controller;
  final FocusNode focusNode;
  final LayerLink layerLink;
  final String query;
  final bool isSearching;
  final List<YtSearchResult> results;
  final Set<String> tracksInPlaylist;
  final Set<String> likedPaths;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClear;
  final VoidCallback onClose;
  final void Function(YtSearchResult video, bool isInPlaylist) onToggle;
  final void Function(YtSearchResult video) onToggleLike;

  const MobileSearchToPlaylistPage({
    super.key,
    required this.playlistName,
    required this.controller,
    required this.focusNode,
    required this.layerLink,
    required this.query,
    required this.isSearching,
    required this.results,
    required this.tracksInPlaylist,
    required this.likedPaths,
    required this.onQueryChanged,
    required this.onClear,
    required this.onClose,
    required this.onToggle,
    required this.onToggleLike,
  });

  Widget _row(BuildContext context, YtSearchResult video) {
    final palette = AppTheme.paletteOf(context);
    final themeState = AppTheme.of(context);
    final onlinePath = 'online:${video.id}';
    final isInPlaylist = tracksInPlaylist.contains(onlinePath);
    final isLiked = likedPaths.contains(onlinePath);
    Widget fallback() => Container(
          width: 56,
          height: 56,
          color: themeState.accent.withValues(alpha: 0.3),
          child: Icon(Icons.music_note, color: palette.textSecondary),
        );
    return InkWell(
      onTap: () => onToggle(video, isInPlaylist),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: video.thumbnailUrl.isEmpty
                  ? fallback()
                  : Image.network(video.thumbnailUrl, width: 56, height: 56, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback()),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    video.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w600, fontSize: 15),
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
            const SizedBox(width: 8),
            Icon(
              isInPlaylist ? Icons.check_circle : Icons.add_circle_outline,
              size: 24,
              color: isInPlaylist ? themeState.accent : palette.textPrimary.withValues(alpha: 0.6),
            ),
            IconButton(
              icon: Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                color: isLiked ? themeState.accent : palette.textPrimary.withValues(alpha: 0.6),
                size: 22,
              ),
              onPressed: () => onToggleLike(video),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.paletteOf(context);
    final l10n = AppLocalizations.of(context);
    final base = Color.alphaBlend(palette.background, Colors.black);

    Widget body;
    if (query.trim().isEmpty) {
      body = Center(child: Text(l10n.searchOnlineHint, style: TextStyle(color: palette.textSecondary)));
    } else if (isSearching) {
      body = const Center(child: CircularProgressIndicator());
    } else if (results.isEmpty) {
      body = Center(child: Text(l10n.noResultsLabel, style: TextStyle(color: palette.textSecondary)));
    } else {
      body = ListView.builder(
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: results.length,
        itemBuilder: (context, index) => _row(context, results[index]),
      );
    }

    return Material(
      color: base,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
              child: Row(
                children: [
                  IconButton(icon: Icon(Icons.arrow_back, color: palette.textPrimary), onPressed: onClose),
                  Expanded(
                    child: Text(
                      l10n.searchToAddPlaylistTitle(playlistDisplayName(playlistName, l10n)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.bold, fontSize: 17),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TopSearchBar(
                layerLink: layerLink,
                controller: controller,
                focusNode: focusNode,
                query: query,
                onQueryChanged: onQueryChanged,
                onClear: onClear,
              ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}
