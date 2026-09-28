import 'dart:io';
import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/playlist_display_name.dart';
import '../../presenters/track_presenter.dart';
import '../../theme/app_theme.dart';

class MobileLibraryView extends StatefulWidget {
  final Map<String, Map<String, dynamic>> playlists;
  final Set<String> importingPlaylists;
  final List<String> trackPaths;
  final TrackPresenter trackPresenter;
  final String? currentPlayingPath;
  final void Function(String playlistName) onOpenPlaylist;
  final void Function(String playlistName) onPlaylistOptions;
  final void Function(String path) onPlayTrack;
  final VoidCallback onCreatePlaylist;
  final VoidCallback onOpenProfile;
  final String? profileImagePath;

  const MobileLibraryView({
    super.key,
    required this.playlists,
    required this.importingPlaylists,
    required this.trackPaths,
    required this.trackPresenter,
    required this.currentPlayingPath,
    required this.onOpenPlaylist,
    required this.onPlaylistOptions,
    required this.onPlayTrack,
    required this.onCreatePlaylist,
    required this.onOpenProfile,
    required this.profileImagePath,
  });

  @override
  State<MobileLibraryView> createState() => MobileLibraryViewState();
}

class MobileLibraryViewState extends State<MobileLibraryView> {
  static const _maxTrackResults = 100;
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  bool _searching = false;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  bool handleBack() {
    if (!_searching) return false;
    _closeSearch();
    return true;
  }

  void _openSearch() {
    setState(() => _searching = true);
    _searchFocus.requestFocus();
  }

  void _closeSearch() {
    _searchFocus.unfocus();
    _searchController.clear();
    setState(() {
      _searching = false;
      _query = '';
    });
  }

  Widget _playlistCover(BuildContext context, Map<String, dynamic> data, bool importing) {
    final palette = AppTheme.paletteOf(context);
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
        child: Icon(Icons.favorite, color: themeState.accentForeground, size: 30),
      );
    } else if (image != null) {
      child = Image.file(
        File(image),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(color: palette.card, child: Icon(Icons.queue_music, color: palette.textSecondary)),
      );
    } else if (data['isLocalFiles'] == true) {
      child = Container(color: palette.inputBackground, child: Icon(Icons.folder, color: palette.textSecondary, size: 30));
    } else {
      child = Container(color: themeState.accent.withValues(alpha: 0.3), child: Icon(Icons.queue_music, color: palette.textSecondary, size: 28));
    }
    return SizedBox(
      width: 64,
      height: 64,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(
          fit: StackFit.expand,
          children: [
            child,
            if (importing)
              Container(
                color: Colors.black.withValues(alpha: 0.55),
                child: const Center(
                  child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _row({required Widget cover, required String title, required String subtitle, required VoidCallback onTap, VoidCallback? onLongPress, bool highlighted = false}) {
    final palette = AppTheme.paletteOf(context);
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            cover,
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: highlighted ? AppTheme.of(context).accent : palette.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: palette.textSecondary, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _playlistRow(BuildContext context, MapEntry<String, Map<String, dynamic>> entry) {
    final l10n = AppLocalizations.of(context);
    final name = entry.key;
    final tracks = entry.value['tracks'] as List<String>;
    final importing = widget.importingPlaylists.contains(name);
    return _row(
      cover: _playlistCover(context, entry.value, importing),
      title: playlistDisplayName(name, l10n),
      subtitle: importing ? l10n.importInProgressLabel : 'Playlist · ${l10n.trackCount(tracks.length)}',
      onTap: () => widget.onOpenPlaylist(name),
      onLongPress: importing ? null : () => widget.onPlaylistOptions(name),
    );
  }

  Widget _trackRow(String path) {
    final presenter = widget.trackPresenter;
    return _row(
      cover: ClipRRect(borderRadius: BorderRadius.circular(6), child: presenter.thumbnail(path, size: 64)),
      title: presenter.title(path),
      subtitle: presenter.subtitle(path),
      highlighted: widget.currentPlayingPath == path,
      onTap: () => widget.onPlayTrack(path),
    );
  }

  Widget _sectionTitle(String text) {
    final palette = AppTheme.paletteOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(text, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.bold, fontSize: 20)),
    );
  }

  Widget _header(BuildContext context) {
    final palette = AppTheme.paletteOf(context);
    final l10n = AppLocalizations.of(context);
    if (_searching) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
        child: Row(
          children: [
            IconButton(icon: Icon(Icons.arrow_back, color: palette.textPrimary), onPressed: _closeSearch),
            Expanded(
              child: Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(color: palette.card, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocus,
                        style: TextStyle(color: palette.textPrimary, fontSize: 16),
                        decoration: InputDecoration(
                          hintText: l10n.searchLibraryHint,
                          hintStyle: TextStyle(color: palette.textSecondary),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onChanged: (value) => setState(() => _query = value),
                      ),
                    ),
                    if (_query.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        child: Icon(Icons.close, color: palette.textSecondary, size: 20),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onOpenProfile,
            child: CircleAvatar(
              radius: 20,
              backgroundColor: palette.inputBackground,
              backgroundImage: widget.profileImagePath != null ? FileImage(File(widget.profileImagePath!)) : null,
              child: widget.profileImagePath == null ? Icon(Icons.person, color: palette.textSecondary, size: 22) : null,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              l10n.libraryTabLabel,
              style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.bold, fontSize: 28),
            ),
          ),
          IconButton(icon: Icon(Icons.search, color: palette.textPrimary, size: 30), onPressed: _openSearch),
          IconButton(
            icon: Icon(Icons.add, color: palette.textPrimary, size: 34),
            tooltip: l10n.createPlaylistTitle,
            onPressed: widget.onCreatePlaylist,
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    final palette = AppTheme.paletteOf(context);
    final l10n = AppLocalizations.of(context);
    final query = _query.trim().toLowerCase();
    if (!_searching || query.isEmpty) {
      final entries = widget.playlists.entries.toList();
      if (entries.isEmpty) {
        return Center(child: Text(l10n.noPlaylistsMessage, style: TextStyle(color: palette.textSecondary, fontSize: 16)));
      }
      return ListView.builder(
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: entries.length,
        itemBuilder: (context, index) => _playlistRow(context, entries[index]),
      );
    }
    final playlists = widget.playlists.entries
        .where((e) => playlistDisplayName(e.key, l10n).toLowerCase().contains(query))
        .toList();
    final presenter = widget.trackPresenter;
    final tracks = <String>[];
    for (final path in widget.trackPaths) {
      if (presenter.title(path).toLowerCase().contains(query) || presenter.subtitle(path).toLowerCase().contains(query)) {
        tracks.add(path);
        if (tracks.length >= _maxTrackResults) break;
      }
    }
    if (playlists.isEmpty && tracks.isEmpty) {
      return Center(child: Text(l10n.noResultsLabel, style: TextStyle(color: palette.textSecondary, fontSize: 16)));
    }
    final items = <Widget Function()>[
      if (playlists.isNotEmpty) () => _sectionTitle(l10n.playlistsSectionTitle),
      for (final entry in playlists) () => _playlistRow(context, entry),
      if (tracks.isNotEmpty) () => _sectionTitle(l10n.libraryTracksSectionTitle),
      for (final path in tracks) () => _trackRow(path),
    ];
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: items.length,
      itemBuilder: (context, index) => items[index](),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(context),
        Expanded(child: _body(context)),
      ],
    );
  }
}
