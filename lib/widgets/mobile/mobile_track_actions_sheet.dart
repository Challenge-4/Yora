import 'dart:io';
import 'package:flutter/material.dart';
import 'mobile_insets.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/playlist_display_name.dart';
import '../../presenters/track_presenter.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';

Future<void> showMobileTrackActionsSheet(
  BuildContext context, {
  required String path,
  required TrackPresenter trackPresenter,
  required Map<String, Map<String, dynamic>> playlists,
  required VoidCallback onCreatePlaylist,
  required Future<void> Function(String playlistName, List<String> playlistTracks, bool isInPlaylist) onToggleTracks,
  List<String>? removeFromTracks,
  Future<void> Function(List<String> removeFromTracks)? onRemoveFromPlaylist,
  Future<void> Function(Set<String> paths)? onAddToQueue,
  VoidCallback? onViewArtist,
  Future<void> Function(String path)? onDownload,
  bool startAtPlaylistPicker = false,
}) {
  final palette = AppTheme.paletteOf(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _MobileTrackActionsSheet(
      path: path,
      trackPresenter: trackPresenter,
      playlists: playlists,
      onCreatePlaylist: onCreatePlaylist,
      onToggleTracks: onToggleTracks,
      removeFromTracks: removeFromTracks,
      onRemoveFromPlaylist: onRemoveFromPlaylist,
      onAddToQueue: onAddToQueue,
      onViewArtist: onViewArtist,
      onDownload: onDownload,
      startAtPlaylistPicker: startAtPlaylistPicker,
      surfaceColor: Color.alphaBlend(palette.cardHover, Colors.black),
    ),
  );
}

class _MobileTrackActionsSheet extends StatefulWidget {
  final String path;
  final TrackPresenter trackPresenter;
  final Map<String, Map<String, dynamic>> playlists;
  final VoidCallback onCreatePlaylist;
  final Future<void> Function(String playlistName, List<String> playlistTracks, bool isInPlaylist) onToggleTracks;
  final List<String>? removeFromTracks;
  final Future<void> Function(List<String> removeFromTracks)? onRemoveFromPlaylist;
  final Future<void> Function(Set<String> paths)? onAddToQueue;
  final VoidCallback? onViewArtist;
  final Future<void> Function(String path)? onDownload;
  final bool startAtPlaylistPicker;
  final Color surfaceColor;

  const _MobileTrackActionsSheet({
    required this.path,
    required this.trackPresenter,
    required this.playlists,
    required this.onCreatePlaylist,
    required this.onToggleTracks,
    required this.removeFromTracks,
    required this.onRemoveFromPlaylist,
    required this.onAddToQueue,
    required this.onViewArtist,
    required this.onDownload,
    required this.startAtPlaylistPicker,
    required this.surfaceColor,
  });

  @override
  State<_MobileTrackActionsSheet> createState() => _MobileTrackActionsSheetState();
}

class _MobileTrackActionsSheetState extends State<_MobileTrackActionsSheet> {
  late bool _showingPlaylistPicker = widget.startAtPlaylistPicker;

  void _close() => Navigator.of(context).pop();

  Widget _handle(AppPalette palette) => Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 6),
        child: Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(color: palette.border, borderRadius: BorderRadius.circular(2)),
          ),
        ),
      );

  Widget _header(AppPalette palette) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Row(
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(4), child: widget.trackPresenter.thumbnail(widget.path, size: 48)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.trackPresenter.title(widget.path),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.trackPresenter.subtitle(widget.path),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionRow(AppPalette palette, {required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: palette.textPrimary, size: 24),
            const SizedBox(width: 20),
            Expanded(child: Text(label, style: TextStyle(color: palette.textPrimary, fontSize: 16))),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsList(BuildContext context, AppPalette palette) {
    final l10n = AppLocalizations.of(context);
    final canRemoveFromPlaylist = widget.removeFromTracks != null && widget.onRemoveFromPlaylist != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _handle(palette),
        _header(palette),
        Divider(color: palette.border, height: 1),
        _actionRow(
          palette,
          icon: Icons.add,
          label: l10n.addToPlaylistLabel,
          onTap: () => setState(() => _showingPlaylistPicker = true),
        ),
        if (widget.onAddToQueue != null)
          _actionRow(
            palette,
            icon: Icons.queue_music,
            label: l10n.addToQueueLabel,
            onTap: () {
              _close();
              widget.onAddToQueue!({widget.path});
            },
          ),
        if (widget.onViewArtist != null)
          _actionRow(
            palette,
            icon: Icons.person_outline,
            label: l10n.viewArtistMenuLabel,
            onTap: () {
              _close();
              widget.onViewArtist!();
            },
          ),
        if (widget.onDownload != null)
          _actionRow(
            palette,
            icon: Icons.download_for_offline_outlined,
            label: l10n.downloadTrackTooltip,
            onTap: () {
              _close();
              widget.onDownload!(widget.path);
            },
          ),
        if (canRemoveFromPlaylist)
          _actionRow(
            palette,
            icon: Icons.remove_circle_outline,
            label: l10n.removeFromPlaylistLabel,
            onTap: () {
              _close();
              widget.onRemoveFromPlaylist!(widget.removeFromTracks!);
            },
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildPlaylistPicker(BuildContext context, AppPalette palette) {
    final l10n = AppLocalizations.of(context);
    final entries = widget.playlists.entries.where((e) => e.value['isLocalFiles'] != true).toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _handle(palette),
        const SizedBox(height: 8),
        Divider(color: palette.border, height: 1),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 8),
            children: [
              _actionRow(
                palette,
                icon: Icons.add,
                label: l10n.newPlaylistLabel,
                onTap: () {
                  _close();
                  widget.onCreatePlaylist();
                },
              ),
              Divider(color: palette.border, height: 1),
              for (final entry in entries) _playlistRow(context, palette, entry),
            ],
          ),
        ),
      ],
    );
  }

  Widget _playlistCover(AppPalette palette, Map<String, dynamic> data) {
    final themeState = AppTheme.of(context);
    final image = data['image'] as String?;
    Widget child;
    if (data['isLiked'] == true && image == null) {
      child = Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [themeState.accentDeep, themeState.accentBright],
          ),
        ),
        child: Icon(Icons.favorite, color: themeState.accentForeground, size: 20),
      );
    } else if (image != null) {
      child = Image.file(
        File(image),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(color: palette.card, child: Icon(Icons.queue_music, color: palette.textSecondary)),
      );
    } else {
      child = Container(color: themeState.accent.withValues(alpha: 0.3), child: Icon(Icons.queue_music, color: palette.textSecondary, size: 20));
    }
    return SizedBox(width: 44, height: 44, child: ClipRRect(borderRadius: BorderRadius.circular(4), child: child));
  }

  Widget _playlistRow(BuildContext context, AppPalette palette, MapEntry<String, Map<String, dynamic>> entry) {
    final l10n = AppLocalizations.of(context);
    final playlistName = entry.key;
    final playlistTracks = entry.value['tracks'] as List<String>;
    final isInPlaylist = playlistTracks.contains(widget.path);
    return InkWell(
      onTap: () {
        _close();
        widget.onToggleTracks(playlistName, playlistTracks, isInPlaylist);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            _playlistCover(palette, entry.value),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                playlistDisplayName(playlistName, l10n),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: palette.textPrimary, fontSize: 16),
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              isInPlaylist ? Icons.check_circle : Icons.add_circle_outline,
              size: 22,
              color: isInPlaylist ? AppTheme.of(context).accent : palette.textPrimary.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.paletteOf(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      child: Material(
        color: widget.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.only(bottom: mobileBottomInset(context)),
          child: SingleChildScrollView(
            child: _showingPlaylistPicker ? _buildPlaylistPicker(context, palette) : _buildActionsList(context, palette),
          ),
        ),
      ),
    );
  }
}
