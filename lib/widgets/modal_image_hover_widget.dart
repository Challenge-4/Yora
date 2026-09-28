import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../l10n/generated/app_localizations.dart';

class ModalImageHoverWidget extends StatefulWidget {
  final String? tempImagePath;
  final VoidCallback onPickImage;
  final VoidCallback onRemoveImage;

  const ModalImageHoverWidget({
    super.key,
    required this.tempImagePath,
    required this.onPickImage,
    required this.onRemoveImage,
  });

  @override
  State<ModalImageHoverWidget> createState() => _ModalImageHoverWidgetState();
}

class _ModalImageHoverWidgetState extends State<ModalImageHoverWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.paletteOf(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onPickImage,
        mouseCursor: SystemMouseCursors.click,
        child: Container(
          width: 170,
          height: 170,
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(6),
            boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8)],
            image: widget.tempImagePath != null
                ? DecorationImage(image: FileImage(File(widget.tempImagePath!)), fit: BoxFit.cover)
                : null,
          ),
          child: Stack(
            children: [
              if (widget.tempImagePath == null)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.edit, size: 36, color: palette.textPrimary),
                      const SizedBox(height: 8),
                      Text(AppLocalizations.of(context).selectPhotoLabel, style: TextStyle(color: palette.textPrimary, fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    ],
                  ),
                ),
              Positioned(
                top: 4,
                right: 4,
                child: IgnorePointer(
                  ignoring: !_isHovered,
                  child: Opacity(
                    opacity: _isHovered ? 1.0 : 0.0,
                    child: PopupMenuButton<String>(
                      icon: Icon(Icons.more_horiz, color: palette.textPrimary),
                      color: palette.cardHover,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      onSelected: (val) {
                        if (val == 'pick') {
                          widget.onPickImage();
                        } else if (val == 'remove') {
                          widget.onRemoveImage();
                        }
                      },
                      itemBuilder: (context) => <PopupMenuEntry<String>>[
                        PopupMenuItem<String>(
                          value: 'pick',
                          child: Row(
                            children: [
                              Icon(Icons.image_outlined, size: 20, color: palette.textSecondary),
                              const SizedBox(width: 12),
                              Text(AppLocalizations.of(context).editPhotoLabel, style: TextStyle(color: palette.textPrimary)),
                            ],
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: 'remove',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, size: 20, color: palette.textSecondary),
                              const SizedBox(width: 12),
                              Text(AppLocalizations.of(context).removePhotoLabel, style: TextStyle(color: palette.textPrimary)),
                            ],
                          ),
                        ),
                      ],
                    ),
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
