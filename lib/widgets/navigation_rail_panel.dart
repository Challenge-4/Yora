import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../l10n/generated/app_localizations.dart';
import 'playlist_sidebar_item.dart';

class NavigationRailPanel extends StatelessWidget {
  final double sidebarWidth;
  final bool isCollapsed;
  final bool homeSelected;
  final VoidCallback onSelectHome;
  final bool explorerSelected;
  final VoidCallback onSelectExplorer;
  final VoidCallback onCreatePlaylist;
  final Map<String, Map<String, dynamic>> playlists;
  final Set<String> importingPlaylists;
  final String? selectedPlaylistFilter;
  final String? dragOverPlaylist;
  final String? currentQueueSourcePlaylist;
  final String? currentPlayingPath;
  final bool userPaused;
  final String? loadingQueuePath;
  final void Function(String playlistName) onDragEnterPlaylist;
  final VoidCallback onDragExitPlaylist;
  final Future<void> Function(String playlistName, List<XFile> files) onDropFiles;
  final void Function(String playlistName) onSelectPlaylist;
  final VoidCallback onTogglePlayPause;
  final void Function(List<String> tracks, int startIndex, {String? sourcePlaylist, bool shuffleFromStart}) onStartQueue;
  final void Function(String playlistName) onEditPlaylist;
  final void Function(String playlistName) onDeletePlaylist;
  final void Function(int oldIndex, int newIndex) onReorderPlaylist;

  const NavigationRailPanel({
    super.key,
    required this.sidebarWidth,
    required this.isCollapsed,
    required this.homeSelected,
    required this.onSelectHome,
    required this.explorerSelected,
    required this.onSelectExplorer,
    required this.onCreatePlaylist,
    required this.playlists,
    required this.importingPlaylists,
    required this.selectedPlaylistFilter,
    required this.dragOverPlaylist,
    required this.currentQueueSourcePlaylist,
    required this.currentPlayingPath,
    required this.userPaused,
    required this.loadingQueuePath,
    required this.onDragEnterPlaylist,
    required this.onDragExitPlaylist,
    required this.onDropFiles,
    required this.onSelectPlaylist,
    required this.onTogglePlayPause,
    required this.onStartQueue,
    required this.onEditPlaylist,
    required this.onDeletePlaylist,
    required this.onReorderPlaylist,
  });

  Widget _buildSidebarNavItem({
    required BuildContext context,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final palette = AppTheme.paletteOf(context);
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
      type: MaterialType.transparency,
      borderRadius: BorderRadius.circular(6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
      onTap: onTap,
      mouseCursor: SystemMouseCursors.click,
      hoverColor: palette.textPrimary.withValues(alpha: 0.15),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 0 : 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? palette.textPrimary.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: isCollapsed ? Alignment.center : null,
        child: isCollapsed
            ? Icon(selected ? selectedIcon : icon, color: selected ? palette.textPrimary : palette.textSecondary, size: 22)
            : Row(
                children: [
                  Icon(selected ? selectedIcon : icon, color: selected ? palette.textPrimary : palette.textSecondary, size: 22),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: TextStyle(
                        color: selected ? palette.textPrimary : palette.textSecondary,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
      ),
      ),
      ),
    );
    return isCollapsed ? Tooltip(message: label, child: content) : content;
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.paletteOf(context);
    return Container(
      width: sidebarWidth,
      color: palette.sidebarBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          _buildSidebarNavItem(
            context: context,
            icon: Icons.home_outlined,
            selectedIcon: Icons.home,
            label: AppLocalizations.of(context).homeNavLabel,
            selected: homeSelected,
            onTap: onSelectHome,
          ),
          const SizedBox(height: 4),
          _buildSidebarNavItem(
            context: context,
            icon: Icons.explore_outlined,
            selectedIcon: Icons.explore,
            label: AppLocalizations.of(context).exploreNavLabel,
            selected: explorerSelected,
            onTap: onSelectExplorer,
          ),
          const SizedBox(height: 12),
          Divider(color: palette.border, height: 1),
          Padding(
            padding: EdgeInsets.fromLTRB(isCollapsed ? 8 : 16, 16, 8, 8),
            child: Row(
              mainAxisAlignment: isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                if (!isCollapsed)
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context).playlistsHeaderLabel,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5),
                    ),
                  ),
                IconButton(
                  icon: Icon(Icons.playlist_add, color: AppTheme.of(context).accent, size: 20),
                  tooltip: AppLocalizations.of(context).createPlaylistTitle,
                  mouseCursor: SystemMouseCursors.click,
                  onPressed: onCreatePlaylist,
                ),
              ],
            ),
          ),
          Expanded(
            child: playlists.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(AppLocalizations.of(context).noPlaylistsMessage, style: TextStyle(color: palette.textSecondary, fontSize: 12)),
                  )
                : ReorderableListView.builder(
                    padding: EdgeInsets.only(right: isCollapsed ? 0 : 8),
                    buildDefaultDragHandles: false,
                    itemCount: playlists.length,
                    onReorderItem: onReorderPlaylist,
                    itemBuilder: (context, index) {
                      final entry = playlists.entries.elementAt(index);
                      final playlistName = entry.key;
                      final tracks = entry.value['tracks'] as List<String>;
                      final playlistImage = entry.value['image'] as String?;
                      final isLiked = entry.value['isLiked'] == true;
                      final isLocalFiles = entry.value['isLocalFiles'] == true;

                      final isActivePlaylist = currentQueueSourcePlaylist == playlistName && currentPlayingPath != null;

                      final row = DropTarget(
                        onDragEntered: (_) => onDragEnterPlaylist(playlistName),
                        onDragExited: (_) => onDragExitPlaylist(),
                        onDragDone: (detail) => onDropFiles(playlistName, detail.files),
                        child: PlaylistSidebarItem(
                          name: playlistName,
                          image: playlistImage,
                          trackCount: tracks.length,
                          selected: selectedPlaylistFilter == playlistName,
                          isActivePlaylist: isActivePlaylist,
                          isPlaying: isActivePlaylist && !userPaused,
                          isLoading: isActivePlaylist && loadingQueuePath != null,
                          collapsed: isCollapsed,
                          isDropTarget: dragOverPlaylist == playlistName,
                          isLiked: isLiked,
                          isLocalFiles: isLocalFiles,
                          isImporting: importingPlaylists.contains(playlistName),
                          onTap: () => onSelectPlaylist(playlistName),
                          onPlay: () {
                            if (isActivePlaylist) {
                              onTogglePlayPause();
                            } else if (tracks.isNotEmpty) {
                              onStartQueue(tracks, 0, sourcePlaylist: playlistName, shuffleFromStart: true);
                            }
                          },
                          onEdit: () => onEditPlaylist(playlistName),
                          onDelete: () => onDeletePlaylist(playlistName),
                        ),
                      );

                      if (isLiked || isLocalFiles) {
                        return KeyedSubtree(key: ValueKey(playlistName), child: row);
                      }
                      return ReorderableDragStartListener(
                        key: ValueKey(playlistName),
                        index: index,
                        child: row,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
