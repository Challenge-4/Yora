import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/playlist_display_name.dart';

class PlaylistSidebarItem extends StatefulWidget {
  final String name;
  final String? image;
  final int trackCount;
  final bool selected;
  final bool isActivePlaylist;
  final bool isPlaying;
  final bool isLoading;
  final bool collapsed;
  final bool isDropTarget;
  final bool isLiked;
  final bool isLocalFiles;
  final bool isImporting;
  final VoidCallback onTap;
  final VoidCallback onPlay;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const PlaylistSidebarItem({
    super.key,
    required this.name,
    required this.image,
    required this.trackCount,
    required this.selected,
    required this.isActivePlaylist,
    required this.isPlaying,
    required this.isLoading,
    required this.collapsed,
    required this.isDropTarget,
    required this.isLiked,
    required this.isLocalFiles,
    required this.isImporting,
    required this.onTap,
    required this.onPlay,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<PlaylistSidebarItem> createState() => PlaylistSidebarItemState();
}

class PlaylistSidebarItemState extends State<PlaylistSidebarItem> {
  bool _isHovered = false;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _previewOverlay;

  @override
  void dispose() {
    _removePreview();
    super.dispose();
  }

  void _showPreview() {
    if (!widget.collapsed) return;
    _removePreview();
    _previewOverlay = OverlayEntry(
      builder: (context) => CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        targetAnchor: Alignment.topRight,
        followerAnchor: Alignment.topLeft,
        offset: const Offset(8, 0),
        child: Align(
          alignment: Alignment.topLeft,
          child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 180),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.paletteOf(context).cardHover,
              borderRadius: BorderRadius.circular(6),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 3))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        playlistDisplayName(widget.name, AppLocalizations.of(context)),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppTheme.paletteOf(context).textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    if (widget.isActivePlaylist) ...[
                      const SizedBox(width: 6),
                      widget.isLoading
                          ? SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.of(context).accent),
                            )
                          : Icon(
                              widget.isPlaying ? Icons.volume_up : Icons.pause,
                              color: AppTheme.of(context).accent,
                              size: 14,
                            ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Playlist • ${AppLocalizations.of(context).trackCount(widget.trackCount)}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppTheme.paletteOf(context).textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
    Overlay.of(context).insert(_previewOverlay!);
  }

  void _removePreview() {
    _previewOverlay?.remove();
    _previewOverlay = null;
  }

  Future<void> _showContextMenu(Offset position) async {
    final palette = AppTheme.paletteOf(context);
    final selectedAction = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      color: palette.cardHover,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      items: [
        PopupMenuItem<String>(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, color: palette.textSecondary, size: 18),
              const SizedBox(width: 12),
              Text(AppLocalizations.of(context).editPlaylistTitle, style: TextStyle(color: palette.textPrimary)),
            ],
          ),
        ),
        if (!widget.isLiked && !widget.isLocalFiles)
          PopupMenuItem<String>(
            value: 'delete',
            child: Row(
              children: [
                const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                const SizedBox(width: 12),
                Text(AppLocalizations.of(context).deleteButton, style: const TextStyle(color: Colors.redAccent)),
              ],
            ),
          ),
      ],
    );
    if (selectedAction == 'edit') {
      widget.onEdit();
    } else if (selectedAction == 'delete') {
      widget.onDelete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeState = AppTheme.of(context);
    final palette = themeState.palette;
    final row = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() => _isHovered = true);
        _showPreview();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _removePreview();
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onSecondaryTapUp: (details) => _showContextMenu(details.globalPosition),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding: EdgeInsets.symmetric(horizontal: widget.collapsed ? 4 : 8, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isDropTarget
                ? themeState.accent.withValues(alpha: 0.35)
                : widget.selected
                    ? palette.textPrimary.withValues(alpha: _isHovered ? 0.16 : 0.1)
                    : _isHovered
                        ? palette.textPrimary.withValues(alpha: 0.15)
                        : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: widget.isDropTarget ? Border.all(color: themeState.accent, width: 1.5) : null,
          ),
          child: Row(
            mainAxisAlignment: widget.collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              SizedBox(
                width: widget.collapsed ? 40 : 48,
                height: widget.collapsed ? 40 : 48,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: widget.image != null
                          ? Image.file(File(widget.image!), fit: BoxFit.cover)
                          : widget.isLiked
                              ? Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [themeState.accentDeep, themeState.accentBright],
                                    ),
                                  ),
                                  child: Icon(Icons.favorite, color: themeState.accentForeground, size: 20),
                                )
                              : widget.isLocalFiles
                                  ? Container(
                                      color: palette.inputBackground,
                                      child: Icon(Icons.folder, color: palette.textSecondary, size: 20),
                                    )
                                  : Container(
                                      color: themeState.accent.withValues(alpha: 0.3),
                                      child: Icon(Icons.queue_music, color: palette.textSecondary),
                                    ),
                    ),
                    if (widget.isImporting)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            ),
                          ),
                        ),
                      )
                    else if (_isHovered)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(4),
                            onTap: widget.onPlay,
                            mouseCursor: SystemMouseCursors.click,
                            child: widget.isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Icon(
                                    widget.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (!widget.collapsed) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        playlistDisplayName(widget.name, AppLocalizations.of(context)),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: widget.selected ? palette.textPrimary : palette.textSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.isImporting
                            ? AppLocalizations.of(context).importInProgressLabel
                            : AppLocalizations.of(context).trackCount(widget.trackCount),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: palette.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (widget.isActivePlaylist) ...[
                  const SizedBox(width: 8),
                  widget.isLoading
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: themeState.accent),
                        )
                      : Icon(
                          widget.isPlaying ? Icons.volume_up : Icons.pause,
                          color: themeState.accent,
                          size: 18,
                        ),
                ],
              ],
            ],
          ),
        ),
      ),
    );

    return CompositedTransformTarget(link: _layerLink, child: row);
  }
}
