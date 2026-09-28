import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/yt_dlp_service.dart';
import '../../theme/app_theme.dart';
import '../top_search_bar.dart';

class MobileSearchView extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final LayerLink layerLink;
  final String query;
  final bool isSearching;
  final List<YtSearchResult> results;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClear;
  final Widget Function(YtSearchResult video) resultRowBuilder;
  final Widget browseContent;

  const MobileSearchView({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.layerLink,
    required this.query,
    required this.isSearching,
    required this.results,
    required this.onQueryChanged,
    required this.onClear,
    required this.resultRowBuilder,
    required this.browseContent,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.paletteOf(context);
    final l10n = AppLocalizations.of(context);
    Widget body;
    if (query.trim().isEmpty) {
      body = browseContent;
    } else if (isSearching) {
      body = const Center(child: CircularProgressIndicator());
    } else if (results.isEmpty) {
      body = Center(child: Text(l10n.noResultsLabel, style: TextStyle(color: palette.textSecondary)));
    } else {
      body = ListView.builder(
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: results.length,
        itemBuilder: (context, index) => resultRowBuilder(results[index]),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
    );
  }
}
