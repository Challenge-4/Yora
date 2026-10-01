import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/yt_dlp_service.dart';
import '../../theme/app_theme.dart';
import '../top_search_bar.dart';
import 'mobile_insets.dart';

class MobileAddTracksSearchPage extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final LayerLink layerLink;
  final String query;
  final bool isSearching;
  final List<YtSearchResult> results;
  final Widget Function(YtSearchResult video) rowBuilder;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClear;
  final VoidCallback onBack;

  const MobileAddTracksSearchPage({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.layerLink,
    required this.query,
    required this.isSearching,
    required this.results,
    required this.rowBuilder,
    required this.onQueryChanged,
    required this.onClear,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.paletteOf(context);
    final l10n = AppLocalizations.of(context);
    final base = Color.alphaBlend(palette.background, Colors.black);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    Widget message(String text) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textSecondary, fontSize: 16),
            ),
          ),
        );

    Widget body;
    if (query.trim().isEmpty) {
      body = message(l10n.searchSongOrArtistPrompt);
    } else if (isSearching) {
      body = const Center(child: CircularProgressIndicator());
    } else if (results.isEmpty) {
      body = message(l10n.noResultsLabel);
    } else {
      body = ListView.builder(
        padding: const EdgeInsets.only(bottom: 8),
        itemCount: results.length,
        itemBuilder: (context, index) => rowBuilder(results[index]),
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
                  IconButton(icon: Icon(Icons.arrow_back, color: palette.textPrimary), onPressed: onBack),
                  Expanded(
                    child: Text(
                      l10n.searchTabLabel,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(child: body),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 12 + (keyboard > 0 ? keyboard : mobileBottomInset(context))),
              child: TopSearchBar(
                layerLink: layerLink,
                controller: controller,
                focusNode: focusNode,
                query: query,
                onQueryChanged: onQueryChanged,
                onClear: onClear,
                hintText: l10n.searchTabLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
