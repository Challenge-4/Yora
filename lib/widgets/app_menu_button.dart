import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../l10n/generated/app_localizations.dart';

class AppMenuButton extends StatelessWidget {
  final bool shuffleActive;
  final bool repeatActive;
  final VoidCallback onCreatePlaylist;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onCut;
  final VoidCallback onCopy;
  final VoidCallback onPaste;
  final VoidCallback onDelete;
  final VoidCallback onSelectAll;
  final VoidCallback onToggleSearch;
  final VoidCallback onOpenSortMenu;
  final VoidCallback onShowPreferences;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onZoomReset;
  final VoidCallback onPlayPause;
  final VoidCallback onPlayNext;
  final VoidCallback onPlayPrevious;
  final VoidCallback onSeekForward;
  final VoidCallback onSeekBackward;
  final VoidCallback onToggleShuffle;
  final VoidCallback onCycleRepeatMode;
  final VoidCallback onVolumeUp;
  final VoidCallback onVolumeDown;
  final VoidCallback onAbout;

  const AppMenuButton({
    super.key,
    required this.shuffleActive,
    required this.repeatActive,
    required this.onCreatePlaylist,
    required this.onUndo,
    required this.onRedo,
    required this.onCut,
    required this.onCopy,
    required this.onPaste,
    required this.onDelete,
    required this.onSelectAll,
    required this.onToggleSearch,
    required this.onOpenSortMenu,
    required this.onShowPreferences,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onZoomReset,
    required this.onPlayPause,
    required this.onPlayNext,
    required this.onPlayPrevious,
    required this.onSeekForward,
    required this.onSeekBackward,
    required this.onToggleShuffle,
    required this.onCycleRepeatMode,
    required this.onVolumeUp,
    required this.onVolumeDown,
    required this.onAbout,
  });

  static const _menuTextStyle = TextStyle(fontSize: 13);

  static SingleActivator _cmd(LogicalKeyboardKey key) =>
      SingleActivator(key, control: !Platform.isMacOS, meta: Platform.isMacOS);

  static String _localizedShortcut(String label) =>
      Platform.isMacOS ? label.replaceFirst('Ctrl+', '⌘') : label;

  Widget _menuLabel(BuildContext context, String text, {bool active = false, String? shortcutLabel}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, style: _menuTextStyle),
            if (active) ...[
              const SizedBox(width: 8),
              Icon(Icons.check, size: 14, color: AppTheme.of(context).accent),
            ],
          ],
        ),
        if (shortcutLabel != null) ...[
          const SizedBox(width: 24),
          Text(_localizedShortcut(shortcutLabel), style: TextStyle(color: AppTheme.paletteOf(context).textSecondary, fontSize: 12)),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final menuStyle = MenuStyle(
      backgroundColor: WidgetStatePropertyAll(Color.alphaBlend(AppTheme.paletteOf(context).cardHover, Colors.black)),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
      elevation: const WidgetStatePropertyAll(8),
    );
    return MenuAnchor(
      style: menuStyle,
      builder: (context, controller, child) => IconButton(
        tooltip: AppLocalizations.of(context).appMenuTooltip,
        icon: Icon(Icons.more_horiz, color: AppTheme.paletteOf(context).textSecondary),
        mouseCursor: SystemMouseCursors.click,
        onPressed: () => controller.isOpen ? controller.close() : controller.open(),
      ),
      menuChildren: [
        SubmenuButton(
          menuStyle: menuStyle,
          menuChildren: [
            MenuItemButton(
              shortcut: _cmd(LogicalKeyboardKey.keyN),
              onPressed: onCreatePlaylist,
              child: _menuLabel(context, AppLocalizations.of(context).createPlaylistTitle),
            ),
          ],
          child: _menuLabel(context, AppLocalizations.of(context).fileMenuLabel),
        ),
        SubmenuButton(
          menuStyle: menuStyle,
          menuChildren: [
            MenuItemButton(
              onPressed: onUndo,
              child: _menuLabel(context, AppLocalizations.of(context).undoMenuItem, shortcutLabel: 'Ctrl+Z'),
            ),
            MenuItemButton(
              onPressed: onRedo,
              child: _menuLabel(context, AppLocalizations.of(context).redoMenuItem, shortcutLabel: 'Ctrl+Y'),
            ),
            Divider(color: AppTheme.paletteOf(context).border, height: 1),
            MenuItemButton(
              onPressed: onCut,
              child: _menuLabel(context, AppLocalizations.of(context).cutMenuItem, shortcutLabel: 'Ctrl+X'),
            ),
            MenuItemButton(
              onPressed: onCopy,
              child: _menuLabel(context, AppLocalizations.of(context).copyMenuItem, shortcutLabel: 'Ctrl+C'),
            ),
            MenuItemButton(
              onPressed: onPaste,
              child: _menuLabel(context, AppLocalizations.of(context).pasteMenuItem, shortcutLabel: 'Ctrl+V'),
            ),
            MenuItemButton(
              onPressed: onDelete,
              child: _menuLabel(context, AppLocalizations.of(context).deleteButton, shortcutLabel: 'Suppr'),
            ),
            Divider(color: AppTheme.paletteOf(context).border, height: 1),
            MenuItemButton(
              onPressed: onSelectAll,
              child: _menuLabel(context, AppLocalizations.of(context).selectAllMenuItem, shortcutLabel: 'Ctrl+A'),
            ),
            Divider(color: AppTheme.paletteOf(context).border, height: 1),
            MenuItemButton(
              shortcut: _cmd(LogicalKeyboardKey.keyL),
              onPressed: onToggleSearch,
              child: _menuLabel(context, AppLocalizations.of(context).searchMenuItem),
            ),
            MenuItemButton(
              shortcut: _cmd(LogicalKeyboardKey.keyF),
              onPressed: onOpenSortMenu,
              child: _menuLabel(context, AppLocalizations.of(context).filterMenuItem),
            ),
            Divider(color: AppTheme.paletteOf(context).border, height: 1),
            MenuItemButton(
              shortcut: _cmd(LogicalKeyboardKey.keyP),
              onPressed: onShowPreferences,
              child: _menuLabel(context, AppLocalizations.of(context).preferencesMenuItem),
            ),
          ],
          child: _menuLabel(context, AppLocalizations.of(context).editMenuLabel),
        ),
        SubmenuButton(
          menuStyle: menuStyle,
          menuChildren: [
            MenuItemButton(
              shortcut: _cmd(LogicalKeyboardKey.equal),
              onPressed: onZoomIn,
              child: _menuLabel(context, AppLocalizations.of(context).zoomInMenuItem),
            ),
            MenuItemButton(
              shortcut: _cmd(LogicalKeyboardKey.minus),
              onPressed: onZoomOut,
              child: _menuLabel(context, AppLocalizations.of(context).zoomOutMenuItem),
            ),
            MenuItemButton(
              shortcut: _cmd(LogicalKeyboardKey.digit0),
              onPressed: onZoomReset,
              child: _menuLabel(context, AppLocalizations.of(context).resetZoomMenuItem),
            ),
          ],
          child: _menuLabel(context, AppLocalizations.of(context).viewMenuLabel),
        ),
        SubmenuButton(
          menuStyle: menuStyle,
          menuChildren: [
            MenuItemButton(
              onPressed: onPlayPause,
              child: _menuLabel(context, AppLocalizations.of(context).playMenuItem, shortcutLabel: AppLocalizations.of(context).spaceKeyLabel),
            ),
            MenuItemButton(
              shortcut: _cmd(LogicalKeyboardKey.arrowRight),
              onPressed: onPlayNext,
              child: _menuLabel(context, AppLocalizations.of(context).nextMenuItem),
            ),
            MenuItemButton(
              shortcut: _cmd(LogicalKeyboardKey.arrowLeft),
              onPressed: onPlayPrevious,
              child: _menuLabel(context, AppLocalizations.of(context).previousMenuItem),
            ),
            MenuItemButton(
              shortcut: const SingleActivator(LogicalKeyboardKey.arrowRight, shift: true),
              onPressed: onSeekForward,
              child: _menuLabel(context, AppLocalizations.of(context).seekForwardMenuItem),
            ),
            MenuItemButton(
              shortcut: const SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true),
              onPressed: onSeekBackward,
              child: _menuLabel(context, AppLocalizations.of(context).seekBackwardMenuItem),
            ),
            MenuItemButton(
              shortcut: _cmd(LogicalKeyboardKey.keyS),
              onPressed: onToggleShuffle,
              child: _menuLabel(context, AppLocalizations.of(context).shuffleMenuItem, active: shuffleActive),
            ),
            MenuItemButton(
              shortcut: _cmd(LogicalKeyboardKey.keyR),
              onPressed: onCycleRepeatMode,
              child: _menuLabel(context, AppLocalizations.of(context).repeatMenuItem, active: repeatActive),
            ),
            MenuItemButton(
              shortcut: _cmd(LogicalKeyboardKey.arrowUp),
              onPressed: onVolumeUp,
              child: _menuLabel(context, AppLocalizations.of(context).volumeUpMenuItem),
            ),
            MenuItemButton(
              shortcut: _cmd(LogicalKeyboardKey.arrowDown),
              onPressed: onVolumeDown,
              child: _menuLabel(context, AppLocalizations.of(context).volumeDownMenuItem),
            ),
          ],
          child: _menuLabel(context, AppLocalizations.of(context).playbackMenuLabel),
        ),
        SubmenuButton(
          menuStyle: menuStyle,
          menuChildren: [
            MenuItemButton(
              onPressed: onAbout,
              child: _menuLabel(context, AppLocalizations.of(context).aboutMenuItem),
            ),
          ],
          child: _menuLabel(context, AppLocalizations.of(context).helpMenuLabel),
        ),
      ],
    );
  }
}
