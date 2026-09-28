import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../l10n/generated/app_localizations.dart';

class MouseRegionWithHoverOverlay extends StatefulWidget {
  final String playlistName;
  final String? playlistImage;
  final bool isLiked;
  final bool isLocalFiles;
  final VoidCallback onEdit;

  const MouseRegionWithHoverOverlay({
    super.key,
    required this.playlistName,
    required this.playlistImage,
    required this.isLiked,
    required this.isLocalFiles,
    required this.onEdit,
  });

  @override
  State<MouseRegionWithHoverOverlay> createState() => _MouseRegionWithHoverOverlayState();
}

class _MouseRegionWithHoverOverlayState extends State<MouseRegionWithHoverOverlay> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final themeState = AppTheme.of(context);
    final palette = themeState.palette;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onEdit,
        child: Container(
          width: 232,
          height: 232,
          decoration: BoxDecoration(
            color: palette.cardHover,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, 6))],
            gradient: widget.playlistImage == null && widget.isLiked
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [themeState.accentDeep, themeState.accentBright],
                  )
                : null,
            image: widget.playlistImage != null
                ? DecorationImage(image: FileImage(File(widget.playlistImage!)), fit: BoxFit.cover)
                : null,
          ),
          child: Stack(
            children: [
              if (widget.playlistImage == null && widget.isLiked)
                Center(child: Icon(Icons.favorite, size: 84, color: themeState.accentForeground)),
              if (widget.playlistImage == null && widget.isLocalFiles && !widget.isLiked)
                Center(child: Icon(Icons.folder, size: 84, color: palette.textSecondary)),
              if (widget.playlistImage == null && !widget.isLiked && !widget.isLocalFiles)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image, size: 52, color: palette.textSecondary),
                      const SizedBox(height: 8),
                      Text(AppLocalizations.of(context).choosePhotoLabel, style: TextStyle(color: palette.textSecondary, fontSize: 11)),
                    ],
                  ),
                ),
              if (_isHovered)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.edit, color: Colors.white, size: 36),
                        const SizedBox(height: 6),
                        Text(
                          AppLocalizations.of(context).editPhotoLabel,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
