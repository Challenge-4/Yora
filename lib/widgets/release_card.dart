import 'package:flutter/material.dart';
import '../services/charts_service.dart';
import '../theme/app_theme.dart';

class ReleaseCard extends StatelessWidget {
  final NewRelease release;
  final VoidCallback onTap;

  const ReleaseCard({super.key, required this.release, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.paletteOf(context);
    return InkWell(
      onTap: onTap,
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
              child: release.coverUrl == null
                  ? Container(color: palette.card)
                  : Image.network(
                      release.coverUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(color: palette.card),
                    ),
            ),
            const SizedBox(height: 6),
            Text(
              release.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
            ),
            Text(
              release.releaseYear != null ? '${release.releaseYear} · ${release.releaseType}' : '${release.releaseType} · ${release.artist}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: palette.textSecondary, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
