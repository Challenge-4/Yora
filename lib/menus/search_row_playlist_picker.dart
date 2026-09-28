import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/playlist_display_name.dart';

void showSearchRowPlaylistPicker(
  BuildContext context, {
  required OverlayEntry? above,
  required Offset position,
  required String path,
  required Map<String, Map<String, dynamic>> playlists,
  required VoidCallback onCreatePlaylist,
  required Future<void> Function(String playlistName, bool isInPlaylist) onToggleInPlaylist,
}) {
  OverlayEntry? entry;
  void dismiss() {
    entry?.remove();
    entry = null;
  }

  entry = OverlayEntry(
    builder: (overlayContext) => _SearchRowPlaylistPickerContent(
      position: position,
      path: path,
      playlists: playlists,
      onDismiss: dismiss,
      onCreatePlaylist: () {
        dismiss();
        onCreatePlaylist();
      },
      onToggleInPlaylist: (playlistName, isInPlaylist) async {
        dismiss();
        await onToggleInPlaylist(playlistName, isInPlaylist);
      },
    ),
  );
  Overlay.of(context).insert(entry!, above: above);
}

class _SearchRowPlaylistPickerContent extends StatelessWidget {
  final Offset position;
  final String path;
  final Map<String, Map<String, dynamic>> playlists;
  final VoidCallback onDismiss;
  final VoidCallback onCreatePlaylist;
  final Future<void> Function(String playlistName, bool isInPlaylist) onToggleInPlaylist;

  const _SearchRowPlaylistPickerContent({
    required this.position,
    required this.path,
    required this.playlists,
    required this.onDismiss,
    required this.onCreatePlaylist,
    required this.onToggleInPlaylist,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.paletteOf(context);
    final l10n = AppLocalizations.of(context);
    const menuWidth = 240.0;
    final screenSize = MediaQuery.sizeOf(context);
    const estimatedMenuHeight = 260.0;
    final left = (position.dx).clamp(0.0, (screenSize.width - menuWidth).clamp(0.0, double.infinity));
    final top = (position.dy).clamp(0.0, (screenSize.height - estimatedMenuHeight).clamp(0.0, double.infinity));
    final localPlaylists = playlists.entries.where((e) => e.value['isLocalFiles'] != true).toList();

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onDismiss),
        ),
        Positioned(
          left: left,
          top: top,
          child: Material(
            color: Color.alphaBlend(palette.cardHover, Colors.black),
            borderRadius: BorderRadius.circular(8),
            elevation: 8,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: menuWidth, maxHeight: 400),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _item(
                      context,
                      icon: Icons.add,
                      label: l10n.newPlaylistLabel,
                      bold: true,
                      onTap: onCreatePlaylist,
                    ),
                    const PopupMenuDivider(),
                    for (final entry in localPlaylists)
                      _playlistItem(context, entry.key, (entry.value['tracks'] as List<String>).contains(path)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _playlistItem(BuildContext context, String playlistName, bool isInPlaylist) {
    final palette = AppTheme.paletteOf(context);
    final l10n = AppLocalizations.of(context);
    return InkWell(
      onTap: () => onToggleInPlaylist(playlistName, isInPlaylist),
      mouseCursor: SystemMouseCursors.click,
      child: SizedBox(
        height: kMinInteractiveDimension,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  playlistDisplayName(playlistName, l10n),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.textPrimary),
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                isInPlaylist ? Icons.check_circle : Icons.circle_outlined,
                size: 18,
                color: isInPlaylist ? AppTheme.of(context).accent : palette.textPrimary.withValues(alpha: 0.38),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool bold = false,
  }) {
    final palette = AppTheme.paletteOf(context);
    return InkWell(
      onTap: onTap,
      mouseCursor: SystemMouseCursors.click,
      child: SizedBox(
        width: double.infinity,
        height: kMinInteractiveDimension,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: palette.textSecondary),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(color: palette.textPrimary, fontWeight: bold ? FontWeight.bold : FontWeight.normal),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
