import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../theme/app_theme.dart';

class MobileBottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;

  const MobileBottomNav({super.key, required this.index, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.paletteOf(context);
    final l10n = AppLocalizations.of(context);
    Widget item(int i, IconData icon, IconData selectedIcon, String label) {
      final selected = index == i;
      final color = selected ? palette.textPrimary : palette.textSecondary;
      return Expanded(
        child: InkWell(
          onTap: () => onSelect(i),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: SizedBox(
            height: 64,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(selected ? selectedIcon : icon, color: color, size: 30),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color, fontSize: 12, fontWeight: selected ? FontWeight.bold : FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      color: Color.alphaBlend(palette.background, Colors.black),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            item(0, Icons.home_outlined, Icons.home_filled, l10n.homeNavLabel),
            item(1, Icons.search, Icons.search, l10n.searchTabLabel),
            item(2, Icons.library_music_outlined, Icons.library_music, l10n.libraryTabLabel),
            item(3, Icons.person_outline, Icons.person, l10n.profileTabLabel),
          ],
        ),
      ),
    );
  }
}
