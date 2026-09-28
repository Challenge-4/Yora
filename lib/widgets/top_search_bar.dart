import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../l10n/generated/app_localizations.dart';
import '../utils/platform_paths.dart';

class TopSearchBar extends StatelessWidget {
  final LayerLink layerLink;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClear;

  const TopSearchBar({
    super.key,
    required this.layerLink,
    required this.controller,
    required this.focusNode,
    required this.query,
    required this.onQueryChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.paletteOf(context);
    return CompositedTransformTarget(
      link: layerLink,
      child: Container(
        height: isMobile ? 48 : 42,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(isMobile ? 24 : 21),
        ),
        child: Row(
          children: [
            Icon(Icons.search, color: palette.textSecondary, size: isMobile ? 24 : 18),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                style: TextStyle(color: palette.textPrimary, fontSize: isMobile ? 17 : 14),
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context).searchOnlineHint,
                  hintStyle: TextStyle(color: palette.textSecondary, fontSize: isMobile ? 17 : null),
                  border: InputBorder.none,
                  isDense: true,
                ),
                onChanged: onQueryChanged,
              ),
            ),
            if (query.isNotEmpty)
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(Icons.close, color: palette.textSecondary, size: 18),
                mouseCursor: SystemMouseCursors.click,
                onPressed: onClear,
              ),
          ],
        ),
      ),
    );
  }
}
