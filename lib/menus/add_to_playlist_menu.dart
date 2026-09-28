import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/playlist_display_name.dart';

const _compactMenuItemStyle = ButtonStyle(
  padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12, vertical: 4)),
  minimumSize: WidgetStatePropertyAll(Size(0, 32)),
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  alignment: Alignment.centerLeft,
);

Future<void> showAddToPlaylistMenu(
  BuildContext context,
  Offset position,
  Set<String> paths, {
  List<String>? removeFromTracks,
  required Map<String, Map<String, dynamic>> playlists,
  required VoidCallback onCreatePlaylist,
  required Future<void> Function(String playlistName, List<String> playlistTracks, bool isInPlaylist) onToggleTracks,
  required Future<void> Function(List<String> removeFromTracks) onRemoveFromPlaylist,
  required Future<void> Function(Set<String> paths) onAddToQueue,
  VoidCallback? onViewArtist,
}) async {
  final MenuController subMenuController = MenuController();
  Timer? closeSubMenuTimer;

  void scheduleSubMenuClose() {
    closeSubMenuTimer?.cancel();
    closeSubMenuTimer = Timer(const Duration(milliseconds: 250), () {
      subMenuController.close();
    });
  }

  void cancelSubMenuClose() {
    closeSubMenuTimer?.cancel();
    closeSubMenuTimer = null;
  }

  final canRemoveFromPlaylist = removeFromTracks != null;

  final navigatorState = Navigator.of(context);

  final screenWidth = MediaQuery.of(context).size.width;
  final openSubMenuLeft = position.dx + 240 + 200 > screenWidth;
  final subMenuAlignmentOffset = openSubMenuLeft ? const Offset(-200, -44) : const Offset(240, -44);
  final palette = AppTheme.paletteOf(context);
  final menuBackground = Color.alphaBlend(palette.cardHover, Colors.black);
  final l10n = AppLocalizations.of(context);

  final selectedAction = await showMenu(
    context: context,
    position: RelativeRect.fromRect(
      position & const Size(40, 40),
      Offset.zero & MediaQuery.of(context).size,
    ),
    color: menuBackground,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    popUpAnimationStyle: AnimationStyle.noAnimation,
    items: <PopupMenuEntry<String>>[
      PopupMenuItem<String>(
        enabled: false,
        padding: EdgeInsets.zero,
        height: 40,
        child: MenuAnchor(
          controller: subMenuController,
          alignmentOffset: subMenuAlignmentOffset,
          style: MenuStyle(
            backgroundColor: WidgetStateProperty.all(menuBackground),
            elevation: WidgetStateProperty.all(8),
            shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          ),
          builder: (context, controller, child) {
            return MouseRegion(
              onEnter: (_) {
                cancelSubMenuClose();
                controller.open();
              },
              onExit: (_) => scheduleSubMenuClose(),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  cancelSubMenuClose();
                  if (controller.isOpen) {
                    controller.close();
                  } else {
                    controller.open();
                  }
                },
                child: SizedBox(
                  width: 240,
                  height: 40,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.add, color: palette.textSecondary, size: 20),
                            const SizedBox(width: 12),
                            Text(l10n.addToPlaylistLabel, style: TextStyle(color: palette.textPrimary)),
                          ],
                        ),
                        Icon(Icons.chevron_right, color: palette.textSecondary, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
          menuChildren: [
            MouseRegion(
              onEnter: (_) => cancelSubMenuClose(),
              onExit: (_) => scheduleSubMenuClose(),
              child: SizedBox(
                width: 200,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MenuItemButton(
                      style: _compactMenuItemStyle,
                      onPressed: () {
                        subMenuController.close();
                        navigatorState.pop();
                        onCreatePlaylist();
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, size: 18, color: palette.textSecondary),
                          const SizedBox(width: 12),
                          Text(l10n.newPlaylistLabel, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Divider(color: palette.border, height: 20),
                    ...playlists.entries.where((e) => e.value['isLocalFiles'] != true).map((playlistEntry) {
                      final playlistName = playlistEntry.key;
                      final playlistTracks = playlistEntry.value['tracks'] as List<String>;
                      final isInPlaylist = paths.every(playlistTracks.contains);
                      return MenuItemButton(
                        style: _compactMenuItemStyle,
                        onPressed: () async {
                          subMenuController.close();
                          navigatorState.pop();
                          await onToggleTracks(playlistName, playlistTracks, isInPlaylist);
                        },
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
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      const PopupMenuDivider(),
      PopupMenuItem<String>(
        value: 'add_to_queue',
        padding: EdgeInsets.zero,
        height: 40,
        child: SizedBox(
          width: 240,
          height: 40,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.queue_music, color: palette.textSecondary, size: 20),
                const SizedBox(width: 12),
                Text(l10n.addToQueueLabel, style: TextStyle(color: palette.textPrimary)),
              ],
            ),
          ),
        ),
      ),
      if (onViewArtist != null) ...[
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'view_artist',
          padding: EdgeInsets.zero,
          height: 40,
          child: SizedBox(
            width: 240,
            height: 40,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.person_outline, color: palette.textSecondary, size: 20),
                  const SizedBox(width: 12),
                  Text(l10n.viewArtistMenuLabel, style: TextStyle(color: palette.textPrimary)),
                ],
              ),
            ),
          ),
        ),
      ],
      if (canRemoveFromPlaylist) ...[
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'remove_from_playlist',
          padding: EdgeInsets.zero,
          height: 40,
          onTap: () {
            subMenuController.close();
          },
          child: SizedBox(
            width: 240,
            height: 40,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.remove_circle_outline, color: palette.textSecondary, size: 20),
                  const SizedBox(width: 12),
                  Text(l10n.removeFromPlaylistLabel, style: TextStyle(color: palette.textPrimary)),
                ],
              ),
            ),
          ),
        ),
      ],
    ],
  );
  closeSubMenuTimer?.cancel();
  subMenuController.close();
  if (selectedAction == 'remove_from_playlist' && canRemoveFromPlaylist) {
    await onRemoveFromPlaylist(removeFromTracks);
  } else if (selectedAction == 'add_to_queue') {
    await onAddToQueue(paths);
  } else if (selectedAction == 'view_artist') {
    onViewArtist?.call();
  }
}
