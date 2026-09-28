import 'package:flutter/material.dart';
import '../services/yt_dlp_service.dart';
import '../theme/app_theme.dart';
import '../l10n/generated/app_localizations.dart';

class SearchResultsDropdown extends StatelessWidget {
  final LayerLink layerLink;
  final bool isSearching;
  final List<YtSearchResult> results;
  final VoidCallback onDismiss;
  final Widget Function(YtSearchResult video) resultRowBuilder;

  const SearchResultsDropdown({
    super.key,
    required this.layerLink,
    required this.isSearching,
    required this.results,
    required this.onDismiss,
    required this.resultRowBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: onDismiss,
          ),
        ),
        CompositedTransformFollower(
          link: layerLink,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 8),
          child: Align(
            alignment: Alignment.topLeft,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 420,
                constraints: const BoxConstraints(maxHeight: 420),
                decoration: BoxDecoration(
                  color: Color.alphaBlend(AppTheme.paletteOf(context).cardHover, Colors.black),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 14, offset: Offset(0, 6))],
                ),
                child: isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                      )
                    : results.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(AppLocalizations.of(context).noResultsLabel, style: TextStyle(color: AppTheme.paletteOf(context).textSecondary)),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            itemCount: results.length,
                            itemBuilder: (context, index) => resultRowBuilder(results[index]),
                          ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
