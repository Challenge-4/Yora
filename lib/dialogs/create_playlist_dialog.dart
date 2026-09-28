import 'package:flutter/material.dart';
import '../state/library_state.dart';
import '../theme/app_theme.dart';
import '../l10n/generated/app_localizations.dart';

class CreatePlaylistDialog extends StatefulWidget {
  final LibraryState library;
  final Future<void> Function(String name) onCreate;
  final void Function(String url) onImportUrl;

  const CreatePlaylistDialog({
    super.key,
    required this.library,
    required this.onCreate,
    required this.onImportUrl,
  });

  @override
  State<CreatePlaylistDialog> createState() => CreatePlaylistDialogState();
}

class CreatePlaylistDialogState extends State<CreatePlaylistDialog> {
  String _playlistName = '';
  String _importUrl = '';
  bool _importMode = false;

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.paletteOf(context);
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      backgroundColor: palette.card.withValues(alpha: 1.0),
      title: Text(
        _importMode ? l10n.importPlaylistTitle : l10n.createPlaylistTitle,
        style: TextStyle(color: palette.textPrimary),
      ),
      content: _importMode
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  autofocus: true,
                  onChanged: (v) => _importUrl = v,
                  style: TextStyle(color: palette.textPrimary),
                  decoration:
                      InputDecoration(hintText: l10n.importUrlHint, hintStyle: TextStyle(color: palette.textSecondary)),
                ),
                const SizedBox(height: 8),
                Text(l10n.importUrlHelperText, style: TextStyle(color: palette.textSecondary, fontSize: 12)),
                const SizedBox(height: 4),
                Text(l10n.importUrlRateLimitHelperText, style: TextStyle(color: palette.textSecondary, fontSize: 12)),
              ],
            )
          : TextField(
              autofocus: true,
              onChanged: (v) => _playlistName = v,
              style: TextStyle(color: palette.textPrimary),
              decoration: InputDecoration(hintText: l10n.playlistNameHint, hintStyle: TextStyle(color: palette.textSecondary)),
            ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actionsPadding: const EdgeInsets.fromLTRB(8, 0, 24, 16),
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: palette.textPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          onPressed: () => setState(() => _importMode = !_importMode),
          child: Text(_importMode ? l10n.backButton : l10n.importButton),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.of(context).accent,
            foregroundColor: AppTheme.of(context).accentForeground,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          onPressed: () async {
            if (_importMode) {
              final url = _importUrl.trim();
              if (url.isEmpty) return;
              Navigator.pop(context);
              widget.onImportUrl(url);
              return;
            }
            final name = _playlistName.trim();
            if (name.isNotEmpty && !widget.library.musicPlaylists.containsKey(name)) {
              await widget.onCreate(name);
            }
            if (!context.mounted) return;
            Navigator.pop(context);
          },
          child: Text(_importMode ? l10n.importButton : l10n.createButton),
        ),
      ],
    );
  }
}
