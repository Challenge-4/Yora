import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/settings_category.dart';
import '../utils/folder_launcher.dart';
import '../utils/link_launcher.dart';
import '../widgets/top_bar.dart' show appVersion, githubRepoUrl;
import 'confirmation_dialog.dart';
import '../utils/image_picker_util.dart';
import '../utils/dominant_color_extractor.dart';
import '../utils/data_backup.dart';
import '../utils/platform_paths.dart';
import '../services/android_media_store_service.dart';
import '../state/theme_state.dart';
import '../state/general_settings_state.dart';
import '../theme/app_palette.dart';
import '../theme/app_theme.dart';
import '../l10n/generated/app_localizations.dart';
import 'custom_color_picker_dialog.dart';

class ProfileSettingsDialog extends StatefulWidget {
  final ThemeState themeState;
  final GeneralSettingsState generalSettings;
  final String initialName;
  final String? initialImagePath;
  final String? initialDownloadDir;
  final String? initialCacheDir;
  final String defaultCacheBase;
  final Future<({int downloads, int cache})> Function() onComputeStorageUsage;
  final Future<void> Function() onClearCache;
  final Future<void> Function(String name, String? imagePath, String? downloadDir, String? cacheDir) onSave;
  final Future<void> Function() onDataImported;

  const ProfileSettingsDialog({
    super.key,
    required this.themeState,
    required this.generalSettings,
    required this.initialName,
    required this.initialImagePath,
    required this.initialDownloadDir,
    required this.initialCacheDir,
    required this.defaultCacheBase,
    required this.onComputeStorageUsage,
    required this.onClearCache,
    required this.onSave,
    required this.onDataImported,
  });

  @override
  State<ProfileSettingsDialog> createState() => ProfileSettingsDialogState();
}

class ProfileSettingsDialogState extends State<ProfileSettingsDialog> {
  late final TextEditingController _nameController = TextEditingController(text: widget.initialName);
  String? _tempImagePath;
  String? _tempDownloadDir;
  String? _tempCacheDir;
  bool _editingName = false;
  bool _hoveringPhoto = false;
  bool _extractingThemeImageColor = false;
  SettingsCategory? _category;

  bool _isProcessingDataAction = false;
  String? _dataFeedbackMessage;
  bool _dataFeedbackIsError = false;

  Future<({int downloads, int cache})>? _storageUsage;
  bool _clearingCache = false;
  bool _cacheJustCleared = false;

  void _openCategory(SettingsCategory value) => setState(() {
        _category = value;
        _storageUsage = null;
        _cacheJustCleared = false;
      });

  @override
  void initState() {
    super.initState();
    _tempImagePath = widget.initialImagePath;
    _tempDownloadDir = widget.initialDownloadDir;
    _tempCacheDir = widget.initialCacheDir;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get hasOpenCategory => _category != null;

  void closeCategory() => setState(() => _category = null);

  Future<void> _autoSave() =>
      widget.onSave(_nameController.text.trim(), _tempImagePath, _tempDownloadDir, _tempCacheDir);

  Future<void> _pickImage() async {
    final path = await pickSingleImagePath();
    if (path == null) return;
    setState(() => _tempImagePath = path);
    if (isMobile) await _autoSave();
  }

  Future<void> _pickDownloadDir() async {
    final dir = await FilePicker.platform.getDirectoryPath();
    if (dir != null) setState(() => _tempDownloadDir = dir);
  }

  Future<void> _pickCacheDir() async {
    final dir = await FilePicker.platform.getDirectoryPath();
    if (dir != null) setState(() => _tempCacheDir = dir);
  }

  Widget _buildFolderSetting({
    required String title,
    required String displayPath,
    required String realPath,
    required VoidCallback onPick,
    required bool hasCustomValue,
    required VoidCallback onReset,
  }) {
    final palette = AppTheme.paletteOf(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: TextStyle(color: palette.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                displayPath,
                style: TextStyle(color: palette.textSecondary, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: Icon(Icons.folder_open, color: palette.textSecondary, size: 18),
              tooltip: l10n.openFolderTooltip,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              mouseCursor: SystemMouseCursors.click,
              onPressed: () => openFolder(realPath),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: palette.textPrimary, side: BorderSide(color: palette.border)),
              onPressed: onPick,
              child: Text(l10n.changeFolderButton),
            ),
            if (hasCustomValue) ...[
              const SizedBox(width: 8),
              TextButton(onPressed: onReset, child: Text(l10n.resetButton)),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildMobilePublicFolderRow({required String title, required String folder}) {
    final palette = AppTheme.paletteOf(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: TextStyle(color: palette.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text('Music/$folder', style: TextStyle(color: palette.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: palette.textPrimary, side: BorderSide(color: palette.border)),
          onPressed: () => AndroidMediaStoreService.openMusicFolder(folder: folder),
          icon: const Icon(Icons.folder_open, size: 18),
          label: Text(l10n.openFolderTooltip),
        ),
      ],
    );
  }

  Widget _buildDownloadsSection() {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isMobile) ...[
          _buildFolderSetting(
            title: l10n.downloadFolderTitle,
            displayPath: _tempDownloadDir ?? l10n.defaultValueSuffix(defaultDownloadsPath()),
            realPath: _tempDownloadDir ?? defaultDownloadsPath(),
            onPick: _pickDownloadDir,
            hasCustomValue: _tempDownloadDir != null,
            onReset: () => setState(() => _tempDownloadDir = null),
          ),
          const SizedBox(height: 20),
        ] else if (Platform.isAndroid) ...[
          _buildMobilePublicFolderRow(title: l10n.downloadFolderTitle, folder: 'Yora'),
          const SizedBox(height: 20),
        ],
        if (!isMobile) ...[
          _buildFolderSetting(
            title: l10n.cacheFolderTitle,
            displayPath: _tempCacheDir ?? l10n.defaultValueSuffix(widget.defaultCacheBase),
            realPath: '${_tempCacheDir ?? widget.defaultCacheBase}${Platform.pathSeparator}yora_online',
            onPick: _pickCacheDir,
            hasCustomValue: _tempCacheDir != null,
            onReset: () => setState(() => _tempCacheDir = null),
          ),
          const SizedBox(height: 32),
        ],
        _buildToggleSetting(
          title: l10n.showDownloadButtonsTitle,
          subtitle: l10n.showDownloadButtonsSubtitle,
          value: widget.generalSettings.showLocalDownloadButtons,
          onChanged: (value) => setState(() => widget.generalSettings.showLocalDownloadButtons = value),
        ),
        if (isMobile) ...[
          const SizedBox(height: 20),
          _buildToggleSetting(
            title: l10n.wifiOnlyDownloadsTitle,
            subtitle: l10n.wifiOnlyDownloadsSubtitle,
            value: widget.generalSettings.downloadOnWifiOnly,
            onChanged: (value) => setState(() => widget.generalSettings.downloadOnWifiOnly = value),
          ),
        ],
        const SizedBox(height: 32),
        _buildStorageSection(),
      ],
    );
  }

  String _formatBytes(int bytes) {
    final l10n = AppLocalizations.of(context);
    const mb = 1024 * 1024;
    const gb = 1024 * mb;
    if (bytes >= gb) {
      return l10n.storageSizeGb(NumberFormat.decimalPatternDigits(locale: l10n.localeName, decimalDigits: 1).format(bytes / gb));
    }
    return l10n.storageSizeMb(NumberFormat.decimalPatternDigits(locale: l10n.localeName, decimalDigits: 0).format(bytes / mb));
  }

  Widget _buildStorageRow(IconData icon, String label, String? value) {
    final palette = AppTheme.paletteOf(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: palette.textSecondary),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: TextStyle(color: palette.textPrimary, fontSize: 13))),
        Text(value ?? '…', style: TextStyle(color: palette.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Future<void> _handleClearCache() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showConfirmationDialog(
      context,
      title: l10n.clearCacheConfirmTitle,
      content: l10n.clearCacheConfirmMessage,
      confirmLabel: l10n.clearCacheConfirmButton,
    );
    if (!confirmed || !mounted) return;
    setState(() => _clearingCache = true);
    await widget.onClearCache();
    if (!mounted) return;
    setState(() {
      _clearingCache = false;
      _cacheJustCleared = true;
      _storageUsage = null;
    });
  }

  Widget _buildStorageSection() {
    final palette = AppTheme.paletteOf(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.storageUsageGroupTitle, style: TextStyle(color: palette.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        FutureBuilder<({int downloads, int cache})>(
          future: _storageUsage ??= widget.onComputeStorageUsage(),
          builder: (context, snapshot) {
            final usage = snapshot.data;
            return Column(
              children: [
                _buildStorageRow(Icons.download_done, l10n.downloadedTracksStorageLabel,
                    usage == null ? null : _formatBytes(usage.downloads)),
                const SizedBox(height: 12),
                _buildStorageRow(Icons.cached, l10n.cacheStorageLabel, usage == null ? null : _formatBytes(usage.cache)),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.redAccent,
            side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.6)),
          ),
          onPressed: _clearingCache ? null : _handleClearCache,
          icon: _clearingCache
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent))
              : const Icon(Icons.delete_forever_outlined, size: 18),
          label: Text(l10n.clearCacheButtonLabel),
        ),
        const SizedBox(height: 10),
        if (_cacheJustCleared)
          Text(l10n.cacheClearedMessage, style: TextStyle(color: AppTheme.of(context).accent, fontSize: 12))
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orangeAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(l10n.clearCacheSubtitle, style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildToggleSetting({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final palette = AppTheme.paletteOf(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: palette.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(color: palette.textSecondary, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Switch(value: value, activeThumbColor: AppTheme.of(context).accent, onChanged: onChanged),
      ],
    );
  }

  Widget _buildCrossfadeDurationSlider() {
    final palette = AppTheme.paletteOf(context);
    final seconds = widget.generalSettings.crossfadeDurationSeconds;
    return Row(
      children: [
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppTheme.of(context).accent,
              thumbColor: AppTheme.of(context).accent,
            ),
            child: Slider(
              value: seconds,
              min: 1,
              max: 12,
              divisions: 11,
              onChanged: (value) => widget.generalSettings.crossfadeDurationSeconds = value,
            ),
          ),
        ),
        SizedBox(
          width: 32,
          child: Text('${seconds.round()}s', style: TextStyle(color: palette.textSecondary, fontSize: 12), textAlign: TextAlign.right),
        ),
      ],
    );
  }

  Widget _buildSettingsGroup(String title, List<Widget> rows) {
    final palette = AppTheme.paletteOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: TextStyle(color: palette.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          rows[i],
        ],
      ],
    );
  }

  Widget _buildLanguageDropdown() {
    final palette = AppTheme.paletteOf(context);
    final l10n = AppLocalizations.of(context);
    final current = widget.generalSettings.languageCode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.languageGroupTitle, style: TextStyle(color: palette.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(l10n.languageRestartNote, style: TextStyle(color: palette.textSecondary, fontSize: 12)),
            ),
            const SizedBox(width: 12),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: SizedBox(
                width: 170,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  decoration: BoxDecoration(
                    color: palette.inputBackground,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: palette.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: current,
                      isExpanded: true,
                      mouseCursor: SystemMouseCursors.click,
                      dropdownMenuItemMouseCursor: SystemMouseCursors.click,
                      focusColor: Colors.transparent,
                      dropdownColor: Color.alphaBlend(palette.cardHover, Colors.black),
                      borderRadius: BorderRadius.circular(12),
                      icon: Icon(Icons.keyboard_arrow_down, color: palette.textSecondary, size: 20),
                      style: TextStyle(color: palette.textPrimary, fontSize: 13),
                      items: [
                        DropdownMenuItem(value: null, child: Text(l10n.languageSystemOption)),
                        DropdownMenuItem(value: 'fr', child: Text(l10n.languageFrenchOption)),
                        DropdownMenuItem(value: 'en', child: Text(l10n.languageEnglishOption)),
                      ],
                      onChanged: (value) => widget.generalSettings.languageCode = value,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGeneralSection() {
    return AnimatedBuilder(
      animation: widget.generalSettings,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSettingsGroup(l10n.playbackGroupTitle, [
              _buildToggleSetting(
                title: l10n.resumeOnStartupTitle,
                subtitle: l10n.resumeOnStartupSubtitle,
                value: widget.generalSettings.autoResumeOnStartup,
                onChanged: (value) => widget.generalSettings.autoResumeOnStartup = value,
              ),
              _buildToggleSetting(
                title: l10n.crossfadeTitle,
                subtitle: l10n.crossfadeSubtitle,
                value: widget.generalSettings.crossfadeEnabled,
                onChanged: (value) => widget.generalSettings.crossfadeEnabled = value,
              ),
              if (widget.generalSettings.crossfadeEnabled) _buildCrossfadeDurationSlider(),
              _buildToggleSetting(
                title: l10n.smoothPlaylistTransitionsTitle,
                subtitle: l10n.smoothPlaylistTransitionsSubtitle,
                value: widget.generalSettings.smoothPlaylistTransitions,
                onChanged: (value) => widget.generalSettings.smoothPlaylistTransitions = value,
              ),
            ]),
            const SizedBox(height: 28),
            _buildSettingsGroup(l10n.systemGroupTitle, [
              _buildLanguageDropdown(),
              if (!isMobile) ...[
                _buildToggleSetting(
                  title: l10n.minimizeToTrayTitle,
                  subtitle: l10n.minimizeToTraySubtitle,
                  value: widget.generalSettings.minimizeToTrayOnClose,
                  onChanged: (value) => widget.generalSettings.minimizeToTrayOnClose = value,
                ),
                _buildToggleSetting(
                  title: l10n.launchAtStartupTitle,
                  subtitle: l10n.launchAtStartupSubtitle,
                  value: widget.generalSettings.launchAtStartupEnabled,
                  onChanged: (value) => widget.generalSettings.setLaunchAtStartupEnabled(value),
                ),
              ],
            ]),
          ],
        );
      },
    );
  }

  Future<void> _handleExportData() async {
    setState(() {
      _isProcessingDataAction = true;
      _dataFeedbackMessage = null;
    });
    final l10n = AppLocalizations.of(context);
    try {
      final path = await exportUserData();
      if (path != null) widget.generalSettings.markDataExported();
      if (!mounted) return;
      setState(() {
        _isProcessingDataAction = false;
        _dataFeedbackMessage = path == null
            ? null
            : (isMobile ? l10n.exportSuccessMessageGeneric : l10n.exportSuccessMessage(path));
        _dataFeedbackIsError = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isProcessingDataAction = false;
        _dataFeedbackMessage = l10n.exportErrorMessage;
        _dataFeedbackIsError = true;
      });
    }
  }

  Future<void> _handleImportData() async {
    setState(() {
      _isProcessingDataAction = true;
      _dataFeedbackMessage = null;
    });
    final l10n = AppLocalizations.of(context);
    final outcome = await importUserData();
    if (outcome == DataImportOutcome.success) {
      await widget.onDataImported();
    }
    if (!mounted) return;
    setState(() {
      _isProcessingDataAction = false;
      _dataFeedbackMessage = switch (outcome) {
        DataImportOutcome.success => l10n.importSuccessMessage,
        DataImportOutcome.invalidFile => l10n.importInvalidFileMessage,
        DataImportOutcome.cancelled => null,
      };
      _dataFeedbackIsError = outcome == DataImportOutcome.invalidFile;
    });
  }

  Widget _buildAboutSection() {
    final palette = AppTheme.paletteOf(context);
    final l10n = AppLocalizations.of(context);
    final groupTitleStyle = TextStyle(color: palette.textPrimary, fontSize: 14, fontWeight: FontWeight.bold);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Column(
            children: [
              Image.asset('assets/app_icon.png', width: 88, height: 88),
              const SizedBox(height: 12),
              Text('Yora', style: TextStyle(color: palette.textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(l10n.versionLabel(appVersion), style: TextStyle(color: palette.textSecondary, fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildAboutLink(Icons.code, l10n.githubTooltip, githubRepoUrl),
        _buildAboutLink(Icons.new_releases_outlined, l10n.checkForUpdatesTrayLabel, '$githubRepoUrl/releases'),
        _buildAboutLink(Icons.bug_report_outlined, l10n.reportIssueLabel, '$githubRepoUrl/issues'),
        const SizedBox(height: 24),
        Text(l10n.licenseGroupTitle, style: groupTitleStyle),
        const SizedBox(height: 8),
        Text(l10n.licenseDescription, style: TextStyle(color: palette.textSecondary, fontSize: 12)),
        _buildAboutLink(Icons.description_outlined, 'GNU GPL v3.0', '$githubRepoUrl/blob/HEAD/LICENSE'),
        const SizedBox(height: 24),
        Text(l10n.affiliationDisclaimer, style: TextStyle(color: palette.textSecondary, fontSize: 11)),
      ],
    );
  }

  Widget _buildAboutLink(IconData icon, String label, String url) {
    final palette = AppTheme.paletteOf(context);
    return InkWell(
      onTap: () => openLink(url),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: palette.textSecondary),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: TextStyle(color: palette.textPrimary, fontSize: 14))),
            Icon(Icons.open_in_new, size: 16, color: palette.textSecondary),
          ],
        ),
      ),
    );
  }

  static const _backupReminderAfter = Duration(days: 30);

  Widget _buildLastBackupInfo() {
    final palette = AppTheme.paletteOf(context);
    final l10n = AppLocalizations.of(context);
    final last = widget.generalSettings.lastDataExportAt;
    final needsReminder = last == null || DateTime.now().difference(last) >= _backupReminderAfter;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(Icons.history, size: 18, color: palette.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                last == null
                    ? l10n.noBackupYetLabel
                    : l10n.lastBackupLabel(MaterialLocalizations.of(context).formatFullDate(last)),
                style: TextStyle(color: palette.textPrimary, fontSize: 13),
              ),
            ),
          ],
        ),
        if (needsReminder) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orangeAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, size: 18, color: Colors.orangeAccent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(l10n.backupReminderMessage, style: TextStyle(color: palette.textPrimary, fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDataSecuritySection() {
    final palette = AppTheme.paletteOf(context);
    final l10n = AppLocalizations.of(context);
    return AnimatedBuilder(
      animation: widget.generalSettings,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.dataBackupGroupTitle, style: TextStyle(color: palette.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(l10n.dataBackupDescription, style: TextStyle(color: palette.textSecondary, fontSize: 12)),
            const SizedBox(height: 20),
            _buildLastBackupInfo(),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: palette.textPrimary, side: BorderSide(color: palette.border)),
                  onPressed: _isProcessingDataAction ? null : _handleExportData,
                  icon: const Icon(Icons.file_upload_outlined, size: 18),
                  label: Text(l10n.exportDataButtonLabel),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: palette.textPrimary, side: BorderSide(color: palette.border)),
                  onPressed: _isProcessingDataAction ? null : _handleImportData,
                  icon: const Icon(Icons.file_download_outlined, size: 18),
                  label: Text(l10n.importDataButtonLabel),
                ),
              ],
            ),
            if (_isProcessingDataAction) ...[
              const SizedBox(height: 16),
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.of(context).accent)),
            ],
            if (_dataFeedbackMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _dataFeedbackMessage!,
                style: TextStyle(color: _dataFeedbackIsError ? Colors.redAccent : AppTheme.of(context).accent, fontSize: 12),
              ),
            ],
            if (!isMobile) ...[
              const SizedBox(height: 28),
              _buildToggleSetting(
                title: l10n.discordRichPresenceTitle,
                subtitle: l10n.discordRichPresenceSubtitle,
                value: widget.generalSettings.discordRichPresenceEnabled,
                onChanged: (value) => widget.generalSettings.discordRichPresenceEnabled = value,
              ),
            ],
          ],
        );
      },
    );
  }

  String _categoryTitle(SettingsCategory value) {
    final l10n = AppLocalizations.of(context);
    return switch (value) {
      SettingsCategory.themes => l10n.settingsCategoryThemes,
      SettingsCategory.downloads => l10n.settingsCategoryDownloads,
      SettingsCategory.general => l10n.settingsCategoryGeneral,
      SettingsCategory.dataAndSecurity => l10n.settingsCategoryDataAndSecurity,
      SettingsCategory.about => l10n.settingsCategoryAbout,
    };
  }

  Widget _buildCategoryContent(SettingsCategory value) => switch (value) {
        SettingsCategory.themes => _buildThemesSection(),
        SettingsCategory.downloads => _buildDownloadsSection(),
        SettingsCategory.general => _buildGeneralSection(),
        SettingsCategory.dataAndSecurity => _buildDataSecuritySection(),
        SettingsCategory.about => _buildAboutSection(),
      };

  Widget _buildThemesSection() {
    final activePalette = AppTheme.paletteOf(context);
    return AnimatedBuilder(
      animation: widget.themeState,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AppLocalizations.of(context).mainThemeGroupTitle, style: TextStyle(color: activePalette.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _balancedGrid(
              itemWidth: 88,
              runSpacing: 18,
              children: [
                _buildThemeSwatch(activePalette, AppThemeId.light),
                _buildThemeSwatch(activePalette, AppThemeId.ash),
                _buildThemeSwatch(activePalette, AppThemeId.dark),
                _buildThemeSwatch(activePalette, AppThemeId.onyx),
                _buildCustomThemeSwatch(activePalette),
                _buildThemeSwatch(activePalette, AppThemeId.aurora),
                _buildThemeSwatch(activePalette, AppThemeId.galaxy),
                _buildImageThemeSwatch(activePalette),
              ],
            ),
            const SizedBox(height: 36),
            Text(AppLocalizations.of(context).accentColorGroupTitle, style: TextStyle(color: activePalette.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _balancedGrid(
              itemWidth: 32,
              runSpacing: 18,
              children: [
                for (final preset in kAccentPresets) _buildAccentSwatch(activePalette, preset.$1, preset.$2),
                _buildCustomAccentSwatch(activePalette),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _balancedGrid({required double itemWidth, required double runSpacing, required List<Widget> children}) {
    const minGap = 12.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxColumns = ((constraints.maxWidth + minGap) / (itemWidth + minGap)).floor().clamp(1, children.length);
        final rows = (children.length / maxColumns).ceil();
        final columns = (children.length / rows).ceil();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var row = 0; row < rows; row++) ...[
              if (row > 0) SizedBox(height: runSpacing),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var column = 0; column < columns; column++)
                    SizedBox(
                      width: itemWidth,
                      child: row * columns + column < children.length ? children[row * columns + column] : null,
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildThemeSwatch(AppPalette activePalette, AppThemeId id) {
    final palette = paletteFor(id);
    final selected = widget.themeState.customThemeSeed == null && widget.themeState.themeId == id;
    return InkWell(
      onTap: () => widget.themeState.setThemeId(id),
      borderRadius: BorderRadius.circular(10),
      mouseCursor: SystemMouseCursors.click,
      child: Container(
        width: 88,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? activePalette.textPrimary : Colors.transparent, width: 2),
        ),
        child: Column(
          children: [
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: palette.background,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: palette.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Container(
                    width: 20,
                    height: 14,
                    decoration: BoxDecoration(color: palette.card, borderRadius: BorderRadius.circular(3)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              themeLabelFor(id),
              style: TextStyle(
                color: selected ? activePalette.textPrimary : activePalette.textSecondary,
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomThemeSwatch(AppPalette activePalette) {
    final customSeed = widget.themeState.customThemeSeed;
    final selected = customSeed != null && widget.themeState.customThemeImagePath == null;
    final previewPalette = selected ? customPaletteFrom(customSeed) : null;
    return InkWell(
      onTap: () => showCustomColorPickerDialog(
        context,
        initialColor: customSeed ?? activePalette.background,
        onColorSelected: widget.themeState.setCustomThemeSeed,
      ),
      borderRadius: BorderRadius.circular(10),
      mouseCursor: SystemMouseCursors.click,
      child: Container(
        width: 88,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? activePalette.textPrimary : Colors.transparent, width: 2),
        ),
        child: Column(
          children: [
            Container(
              height: 48,
              decoration: BoxDecoration(
                gradient: previewPalette == null
                    ? const SweepGradient(colors: [
                        Color(0xFFFF0000),
                        Color(0xFFFFFF00),
                        Color(0xFF00FF00),
                        Color(0xFF00FFFF),
                        Color(0xFF0000FF),
                        Color(0xFFFF00FF),
                        Color(0xFFFF0000),
                      ])
                    : null,
                color: previewPalette?.background,
                borderRadius: BorderRadius.circular(6),
                border: previewPalette != null ? Border.all(color: previewPalette.border) : null,
              ),
              child: previewPalette == null
                  ? const Center(child: Icon(Icons.add, color: Colors.white, size: 20))
                  : Padding(
                      padding: const EdgeInsets.all(6),
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: Container(
                          width: 20,
                          height: 14,
                          decoration: BoxDecoration(color: previewPalette.card, borderRadius: BorderRadius.circular(3)),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 6),
            Text(
              AppLocalizations.of(context).customThemeLabel,
              style: TextStyle(
                color: selected ? activePalette.textPrimary : activePalette.textSecondary,
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageThemeSwatch(AppPalette activePalette) {
    final imagePath = widget.themeState.customThemeImagePath;
    final selected = imagePath != null;
    return InkWell(
      onTap: _extractingThemeImageColor ? null : () => _pickImageForTheme(),
      borderRadius: BorderRadius.circular(10),
      mouseCursor: SystemMouseCursors.click,
      child: Container(
        width: 88,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? activePalette.textPrimary : Colors.transparent, width: 2),
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 48,
                width: double.infinity,
                child: _extractingThemeImageColor
                    ? Container(
                        color: activePalette.card,
                        child: const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
                      )
                    : imagePath == null
                        ? Container(
                            color: activePalette.card,
                            child: Icon(Icons.image_outlined, color: activePalette.textSecondary, size: 20),
                          )
                        : Image.file(
                            File(imagePath),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              color: activePalette.card,
                              child: Icon(Icons.broken_image_outlined, color: activePalette.textSecondary, size: 20),
                            ),
                          ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              AppLocalizations.of(context).imageThemeLabel,
              style: TextStyle(
                color: selected ? activePalette.textPrimary : activePalette.textSecondary,
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageForTheme() async {
    final path = await pickSingleImagePath();
    if (path == null || !mounted) return;
    setState(() => _extractingThemeImageColor = true);
    final dominant = await extractDominantColor(path);
    if (!mounted) return;
    setState(() => _extractingThemeImageColor = false);
    if (dominant != null) {
      widget.themeState.setCustomThemeFromImage(path, dominant);
    }
  }

  Widget _buildAccentSwatch(AppPalette activePalette, String label, Color color) {
    final selected = widget.themeState.accentSeed.toARGB32() == color.toARGB32();
    return InkWell(
      onTap: () => widget.themeState.setAccentSeed(color),
      borderRadius: BorderRadius.circular(20),
      mouseCursor: SystemMouseCursors.click,
      child: Tooltip(
        message: label,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(color: selected ? activePalette.textPrimary : Colors.transparent, width: 2),
          ),
          child: selected ? Icon(Icons.check, color: widget.themeState.accentForeground, size: 16) : null,
        ),
      ),
    );
  }

  Widget _buildCustomAccentSwatch(AppPalette activePalette) {
    final accent = widget.themeState.accentSeed;
    final isPreset = kAccentPresets.any((preset) => preset.$2.toARGB32() == accent.toARGB32());
    return InkWell(
      onTap: () => showCustomColorPickerDialog(
        context,
        initialColor: accent,
        onColorSelected: widget.themeState.setAccentSeed,
      ),
      borderRadius: BorderRadius.circular(20),
      mouseCursor: SystemMouseCursors.click,
      child: Tooltip(
        message: AppLocalizations.of(context).customAccentTooltip,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isPreset
                ? const SweepGradient(colors: [
                    Color(0xFFFF0000),
                    Color(0xFFFFFF00),
                    Color(0xFF00FF00),
                    Color(0xFF00FFFF),
                    Color(0xFF0000FF),
                    Color(0xFFFF00FF),
                    Color(0xFFFF0000),
                  ])
                : null,
            color: isPreset ? null : accent,
            border: Border.all(color: !isPreset ? activePalette.textPrimary : Colors.transparent, width: 2),
          ),
          child: isPreset
              ? const Icon(Icons.add, color: Colors.white, size: 16)
              : Icon(Icons.check, color: widget.themeState.accentForeground, size: 16),
        ),
      ),
    );
  }

  Widget _buildCategoryMenuItem(String label, IconData icon, SettingsCategory value) {
    final palette = AppTheme.paletteOf(context);
    return InkWell(
      onTap: () => _openCategory(value),
      borderRadius: BorderRadius.circular(8),
      mouseCursor: SystemMouseCursors.click,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: palette.textSecondary),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: TextStyle(color: palette.textPrimary, fontSize: 14))),
            Icon(Icons.chevron_right, size: 18, color: palette.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileProfileHeader(AppPalette palette, AppLocalizations l10n) {
    final displayName = _nameController.text.trim().isEmpty ? l10n.defaultUserName : _nameController.text.trim();
    return Column(
      children: [
        GestureDetector(
          onTap: _pickImage,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: palette.card,
                backgroundImage: _tempImagePath != null ? FileImage(File(_tempImagePath!)) : null,
                child: _tempImagePath == null ? Icon(Icons.person, color: palette.textSecondary, size: 60) : null,
              ),
              CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.of(context).accent,
                child: Icon(Icons.edit, color: AppTheme.of(context).accentForeground, size: 18),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _editingName
            ? SizedBox(
                width: 240,
                child: TextField(
                  controller: _nameController,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.bold, fontSize: 24),
                  decoration: InputDecoration(
                    isDense: true,
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: palette.border)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.of(context).accent)),
                  ),
                  onSubmitted: (_) {
                    setState(() => _editingName = false);
                    _autoSave();
                  },
                  onTapOutside: (_) {
                    if (!_editingName) return;
                    setState(() => _editingName = false);
                    _autoSave();
                  },
                ),
              )
            : GestureDetector(
                onTap: () => setState(() => _editingName = true),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.bold, fontSize: 26),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.edit, color: palette.textSecondary, size: 20),
                  ],
                ),
              ),
      ],
    );
  }

  Widget _buildMobileCategoryItem(String label, IconData icon, SettingsCategory value) {
    final palette = AppTheme.paletteOf(context);
    return InkWell(
      onTap: () => _openCategory(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
        child: Row(
          children: [
            Icon(icon, size: 26, color: palette.textSecondary),
            const SizedBox(width: 18),
            Expanded(child: Text(label, style: TextStyle(color: palette.textPrimary, fontSize: 18, fontWeight: FontWeight.w500))),
            Icon(Icons.chevron_right, size: 26, color: palette.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildMobilePage(AppPalette palette, AppLocalizations l10n) {
    final category = _category;
    if (category != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
            child: Row(
              children: [
                IconButton(icon: Icon(Icons.arrow_back, color: palette.textPrimary), onPressed: closeCategory),
                Expanded(
                  child: Text(
                    _categoryTitle(category),
                    style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.bold, fontSize: 24),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.15)),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: _buildCategoryContent(category),
              ),
            ),
          ),
        ],
      );
    }
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.only(top: 32),
          sliver: SliverList.list(
            children: [
              Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: _buildMobileProfileHeader(palette, l10n)),
              const SizedBox(height: 28),
              Divider(color: palette.border, height: 1),
              _buildMobileCategoryItem(l10n.settingsCategoryThemes, Icons.palette_outlined, SettingsCategory.themes),
              _buildMobileCategoryItem(l10n.settingsCategoryDownloads, Icons.download_outlined, SettingsCategory.downloads),
              _buildMobileCategoryItem(l10n.settingsCategoryGeneral, Icons.settings_outlined, SettingsCategory.general),
              _buildMobileCategoryItem(l10n.settingsCategoryDataAndSecurity, Icons.shield_outlined, SettingsCategory.dataAndSecurity),
              _buildMobileCategoryItem(l10n.settingsCategoryAbout, Icons.info_outline, SettingsCategory.about),
            ],
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: _buildAppFooter(palette),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppFooter(AppPalette palette) {
    final style = TextStyle(color: palette.textSecondary, fontSize: 13);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Yora v$appVersion  ·  ', style: style),
        InkWell(
          onTap: () => openLink(githubRepoUrl),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Text('GitHub', style: style.copyWith(decoration: TextDecoration.underline, decorationColor: palette.textSecondary)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.paletteOf(context);
    final l10n = AppLocalizations.of(context);
    if (isMobile) return _buildMobilePage(palette, l10n);
    return AlertDialog(
      backgroundColor: palette.cardHover.withValues(alpha: 1.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: _category == null
          ? null
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: palette.textSecondary),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      mouseCursor: SystemMouseCursors.click,
                      onPressed: () => setState(() => _category = null),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _categoryTitle(_category!),
                      style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.bold, fontSize: 20),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close, color: palette.textSecondary),
                  mouseCursor: SystemMouseCursors.click,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
      titlePadding: _category == null ? EdgeInsets.zero : const EdgeInsets.fromLTRB(24, 16, 24, 0),
      contentPadding: EdgeInsets.fromLTRB(24, _category == null ? 24 : 4, 24, 24),
      content: SizedBox(
        width: (MediaQuery.sizeOf(context).width * 0.9).clamp(0.0, 520.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_category == null) ...[
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      onEnter: (_) => setState(() => _hoveringPhoto = true),
                      onExit: (_) => setState(() => _hoveringPhoto = false),
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircleAvatar(
                              radius: 44,
                              backgroundColor: palette.card,
                              backgroundImage: _tempImagePath != null ? FileImage(File(_tempImagePath!)) : null,
                              child: _tempImagePath == null
                                  ? Icon(Icons.person, color: palette.textSecondary, size: 44)
                                  : null,
                            ),
                            if (_hoveringPhoto)
                              Container(
                                width: 88,
                                height: 88,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: 0.45)),
                                child: const Icon(Icons.edit, color: Colors.white, size: 26),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: IconButton(
                      icon: Icon(Icons.close, color: palette.textSecondary),
                      mouseCursor: SystemMouseCursors.click,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Center(
                child: _editingName
                    ? SizedBox(
                        width: 200,
                        child: TextField(
                          controller: _nameController,
                          autofocus: true,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                          decoration: InputDecoration(
                            isDense: true,
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: palette.border)),
                            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.of(context).accent)),
                          ),
                          onSubmitted: (_) => setState(() => _editingName = false),
                          onTapOutside: (_) => setState(() => _editingName = false),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _nameController.text.trim().isEmpty ? l10n.defaultUserName : _nameController.text.trim(),
                            style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () => setState(() => _editingName = true),
                            borderRadius: BorderRadius.circular(12),
                            mouseCursor: SystemMouseCursors.click,
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(Icons.edit, color: palette.textSecondary, size: 15),
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 20),
              Divider(color: palette.border, height: 1),
            ],
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: (MediaQuery.sizeOf(context).height * 0.75 - 220).clamp(200.0, double.infinity)),
              child: SingleChildScrollView(
                child: _category == null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCategoryMenuItem(l10n.settingsCategoryThemes, Icons.palette_outlined, SettingsCategory.themes),
                          Divider(color: palette.border, height: 1),
                          _buildCategoryMenuItem(l10n.settingsCategoryDownloads, Icons.download_outlined, SettingsCategory.downloads),
                          Divider(color: palette.border, height: 1),
                          _buildCategoryMenuItem(l10n.settingsCategoryGeneral, Icons.settings_outlined, SettingsCategory.general),
                          Divider(color: palette.border, height: 1),
                          _buildCategoryMenuItem(l10n.settingsCategoryDataAndSecurity, Icons.shield_outlined, SettingsCategory.dataAndSecurity),
                          Divider(color: palette.border, height: 1),
                          _buildCategoryMenuItem(l10n.settingsCategoryAbout, Icons.info_outline, SettingsCategory.about),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          _buildCategoryContent(_category!),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(foregroundColor: palette.textPrimary),
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancelButton),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.of(context).accent, foregroundColor: AppTheme.of(context).accentForeground),
          onPressed: () async {
            await widget.onSave(_nameController.text.trim(), _tempImagePath, _tempDownloadDir, _tempCacheDir);
            if (context.mounted) Navigator.pop(context);
          },
          child: Text(l10n.saveButton),
        ),
      ],
    );
  }
}
