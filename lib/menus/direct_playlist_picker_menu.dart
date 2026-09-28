import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/playlist_display_name.dart';

const _newPlaylistMenuValue = '__new_playlist__';

Future<void> showDirectPlaylistPickerMenu(
  BuildContext context,
  Offset position,
  String path, {
  required Map<String, Map<String, dynamic>> playlists,
  required VoidCallback onCreatePlaylist,
  required Future<void> Function(String playlistName) onToggleInPlaylist,
  required bool Function() isMounted,
}) async {
  final anchor = position + const Offset(24, 0);
  final palette = AppTheme.paletteOf(context);
  final l10n = AppLocalizations.of(context);
  final selected = await showMenu<String>(
    context: context,
    position: RelativeRect.fromRect(
      anchor & const Size(40, 40),
      Offset.zero & MediaQuery.of(context).size,
    ),
    color: Color.alphaBlend(palette.cardHover, Colors.black),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    items: [
      PopupMenuItem<String>(
        value: _newPlaylistMenuValue,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 18, color: palette.textSecondary),
            const SizedBox(width: 12),
            Text(l10n.newPlaylistLabel, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      const PopupMenuDivider(),
      ...playlists.entries.where((e) => e.value['isLocalFiles'] != true).map((entry) {
        final playlistName = entry.key;
        final tracks = entry.value['tracks'] as List<String>;
        final isInPlaylist = tracks.contains(path);
        return PopupMenuItem<String>(
          value: playlistName,
          child: Row(
            children: [
              Expanded(
                child: Text(playlistDisplayName(playlistName, l10n), overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.textPrimary)),
              ),
              const SizedBox(width: 10),
              Icon(
                isInPlaylist ? Icons.check_circle : Icons.circle_outlined,
                size: 18,
                color: isInPlaylist ? AppTheme.of(context).accent : palette.textPrimary.withValues(alpha: 0.38),
              ),
            ],
          ),
        );
      }),
    ],
  );
  if (selected == null || !isMounted()) return;
  if (selected == _newPlaylistMenuValue) {
    onCreatePlaylist();
    return;
  }
  await onToggleInPlaylist(selected);
}
