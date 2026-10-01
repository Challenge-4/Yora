import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/yt_dlp_service.dart';
import '../../theme/app_theme.dart';
import '../top_search_bar.dart';
import 'mobile_insets.dart';

class MobileSearchToPlaylistPage extends StatelessWidget {
  final String playlistName;
  final TextEditingController controller;
  final FocusNode focusNode;
  final LayerLink layerLink;
  final String query;
  final bool isSearching;
  final List<YtSearchResult> results;
  final List<YtSearchResult>? suggestions;
  final bool suggestionsLoading;
  final Set<String> tracksInPlaylist;
  final String? playingPreviewId;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClear;
  final VoidCallback onClose;
  final void Function(YtSearchResult video, bool isInPlaylist) onToggle;
  final void Function(YtSearchResult video) onPreview;

  const MobileSearchToPlaylistPage({
    super.key,
    required this.playlistName,
    required this.controller,
    required this.focusNode,
    required this.layerLink,
    required this.query,
    required this.isSearching,
    required this.results,
    required this.suggestions,
    required this.suggestionsLoading,
    required this.tracksInPlaylist,
    required this.playingPreviewId,
    required this.onQueryChanged,
    required this.onClear,
    required this.onClose,
    required this.onToggle,
    required this.onPreview,
  });

  Widget _row(BuildContext context, YtSearchResult video) {
    final palette = AppTheme.paletteOf(context);
    final themeState = AppTheme.of(context);
    final onlinePath = 'online:${video.id}';
    final isInPlaylist = tracksInPlaylist.contains(onlinePath);
    final isPlaying = playingPreviewId == video.id;
    Widget fallback() => Container(
          width: 56,
          height: 56,
          color: themeState.accent.withValues(alpha: 0.3),
          child: Icon(Icons.music_note, color: palette.textSecondary),
        );
    return InkWell(
      onTap: () => onPreview(video),
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
            IconButton(
              icon: Icon(
                isInPlaylist ? Icons.check_circle : Icons.add_circle_outline,
                size: 28,
                color: isInPlaylist ? themeState.accent : palette.textPrimary.withValues(alpha: 0.8),
              ),
              onPressed: () => onToggle(video, isInPlaylist),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(BuildContext context, List<YtSearchResult> items, {String? header}) {
    final palette = AppTheme.paletteOf(context);
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: items.length + (header == null ? 0 : 1),
      itemBuilder: (context, index) {
        if (header != null && index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(header, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
          );
        }
        return _row(context, items[header == null ? index : index - 1]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.paletteOf(context);
    final l10n = AppLocalizations.of(context);
    final base = Color.alphaBlend(palette.background, Colors.black);

    Widget centered(Widget child) => Center(child: Padding(padding: const EdgeInsets.all(24), child: child));
    Widget message(String text) => centered(Text(text, textAlign: TextAlign.center, style: TextStyle(color: palette.textSecondary)));

    Widget body;
    if (query.trim().isEmpty) {
      final items = suggestions;
      if (items == null || (suggestionsLoading && items.isEmpty)) {
        body = centered(const CircularProgressIndicator());
      } else if (items.isEmpty) {
        body = message(l10n.searchOnlineHint);
      } else {
        body = _list(context, items, header: l10n.suggestionsForYouLabel);
      }
    } else if (isSearching) {
      body = centered(const CircularProgressIndicator());
    } else if (results.isEmpty) {
      body = message(l10n.noResultsLabel);
    } else {
      body = _list(context, results);
    }

    return Material(
      color: base,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
              child: Row(
                children: [
                  IconButton(icon: Icon(Icons.close, color: palette.textPrimary), onPressed: onClose),
                  Expanded(
                    child: Text(
                      l10n.addToPlaylistLabel,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(child: body),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 12 + mobileBottomInset(context)),
              child: TopSearchBar(
                layerLink: layerLink,
                controller: controller,
                focusNode: focusNode,
                query: query,
                onQueryChanged: onQueryChanged,
                onClear: onClear,
                hintText: l10n.addTracksSearchHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
