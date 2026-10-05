import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../theme/app_palette.dart';
import '../theme/app_theme.dart';
import '../l10n/generated/app_localizations.dart';
import '../utils/link_launcher.dart';
import '../utils/platform_paths.dart';

const String githubRepoUrl = 'https://github.com/Challenge-4/Yora';
const String appVersion = '1.4.0';

class TopBar extends StatelessWidget {
  final Widget searchBar;
  final Widget appMenu;
  final String? profileImagePath;
  final bool isWindowMaximized;
  final VoidCallback onHomeTap;
  final VoidCallback onShowProfile;

  const TopBar({
    super.key,
    required this.searchBar,
    required this.appMenu,
    required this.profileImagePath,
    required this.isWindowMaximized,
    required this.onHomeTap,
    required this.onShowProfile,
  });

  Widget _buildGitHubButton(BuildContext context, AppPalette palette) {
    final l10n = AppLocalizations.of(context);
    return IconButton(
      icon: Icon(Icons.code, color: palette.textSecondary, size: 20),
      tooltip: l10n.githubTooltip,
      mouseCursor: SystemMouseCursors.click,
      onPressed: githubRepoUrl.isEmpty ? null : () => openLink(githubRepoUrl),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.paletteOf(context);
    return SizedBox(
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: palette.background,
                border: Border(bottom: BorderSide(color: palette.border, width: 1)),
              ),
            ),
          ),
          if (isDesktop) const Positioned.fill(child: DragToMoveArea(child: SizedBox.expand())),
          Positioned(
            left: Platform.isMacOS ? 100 : 24,
            top: 0,
            bottom: 0,
            child: Center(
              child: IgnorePointer(
                child: Text(
                  'YORA',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    letterSpacing: 6,
                    color: AppTheme.of(context).accent,
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.home_rounded, color: palette.textPrimary),
                  mouseCursor: SystemMouseCursors.click,
                  onPressed: onHomeTap,
                ),
                const SizedBox(width: 8),
                SizedBox(width: 320, child: searchBar),
                const SizedBox(width: 8),
                appMenu,
              ],
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Row(
              children: [
                _buildGitHubButton(context, palette),
                const SizedBox(width: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: onShowProfile,
                  mouseCursor: SystemMouseCursors.click,
                  hoverColor: palette.textPrimary.withValues(alpha: 0.15),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: palette.inputBackground,
                    backgroundImage: profileImagePath != null ? FileImage(File(profileImagePath!)) : null,
                    child: profileImagePath == null
                        ? Icon(Icons.person, color: palette.textSecondary, size: 18)
                        : null,
                  ),
                ),
                const SizedBox(width: 20),
                if (isDesktop && !Platform.isMacOS) ...[
                WindowCaptionButton.minimize(
                  brightness: palette.brightness,
                  onPressed: () => windowManager.minimize(),
                ),
                isWindowMaximized
                    ? WindowCaptionButton.unmaximize(
                        brightness: palette.brightness,
                        onPressed: () => windowManager.unmaximize(),
                      )
                    : WindowCaptionButton.maximize(
                        brightness: palette.brightness,
                        onPressed: () => windowManager.maximize(),
                      ),
                WindowCaptionButton.close(
                  brightness: palette.brightness,
                  onPressed: () => windowManager.close(),
                ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
