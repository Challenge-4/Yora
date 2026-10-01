import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/yt_dlp_service.dart';
import '../../theme/app_theme.dart';
import 'mobile_insets.dart';

class MobileSearchToPlaylistPage extends StatelessWidget {
  final List<YtSearchResult>? suggestions;
  final bool suggestionsLoading;
  final Widget Function(YtSearchResult video) rowBuilder;
  final VoidCallback onOpenSearch;
  final VoidCallback onClose;

  const MobileSearchToPlaylistPage({
    super.key,
    required this.suggestions,
    required this.suggestionsLoading,
    required this.rowBuilder,
    required this.onOpenSearch,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.paletteOf(context);
    final l10n = AppLocalizations.of(context);
    final base = Color.alphaBlend(palette.background, Colors.black);

    Widget body;
    final items = suggestions;
    if (items == null || (suggestionsLoading && items.isEmpty)) {
      body = const Center(child: CircularProgressIndicator());
    } else if (items.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(l10n.searchSongOrArtistPrompt, textAlign: TextAlign.center, style: TextStyle(color: palette.textSecondary)),
        ),
      );
    } else {
      body = ListView.builder(
        padding: const EdgeInsets.only(bottom: 8),
        itemCount: items.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                l10n.suggestionsForYouLabel,
                style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            );
          }
          return rowBuilder(items[index - 1]);
        },
      );
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
              child: Material(
                color: palette.card,
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: onOpenSearch,
                  child: SizedBox(
                    height: 48,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: [
                          Icon(Icons.search, color: palette.textSecondary, size: 24),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              l10n.addTracksSearchHint,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: palette.textSecondary, fontSize: 17),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
