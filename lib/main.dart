import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:cross_file/cross_file.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart' as tray;
import 'package:launch_at_startup/launch_at_startup.dart';
import 'services/yt_dlp_service.dart';
import 'services/youtube_backend.dart';
import 'services/youtube_explode_service.dart';
import 'services/yt_dlp_android_service.dart';
import 'services/metadata_lookup_service.dart';
import 'services/playlist_import_service.dart';
import 'services/charts_service.dart';
import 'services/track_metadata_repair_service.dart';
import 'services/discord_presence_service.dart';
import 'services/media_hotkey_service.dart';
import 'services/media_session_service.dart';
import 'services/android_media_store_service.dart';
import 'models/repeat_mode.dart';
import 'utils/window_geometry.dart';
import 'utils/platform_paths.dart';
import 'utils/link_launcher.dart';
import 'utils/network_status.dart';
import 'utils/artist_names.dart';
import 'widgets/app_menu_button.dart';
import 'widgets/top_bar.dart';
import 'widgets/navigation_rail_panel.dart';
import 'widgets/explorer_view.dart';
import 'widgets/home_view.dart';
import 'widgets/playlist_detail_view.dart';
import 'widgets/expanded_now_playing_panel.dart';
import 'widgets/aurora_background.dart';
import 'widgets/galaxy_background.dart';
import 'widgets/image_theme_background.dart';
import 'widgets/now_playing_bar.dart';
import 'widgets/queue_panel.dart';
import 'widgets/mobile/mobile_add_track_row.dart';
import 'widgets/mobile/mobile_add_tracks_search_page.dart';
import 'widgets/mobile/mobile_bottom_nav.dart';
import 'widgets/mobile/mobile_edit_playlist_sheet.dart';
import 'widgets/mobile/mobile_insets.dart';
import 'widgets/mobile/mobile_library_view.dart';
import 'widgets/mobile/mobile_mini_player.dart';
import 'widgets/mobile/mobile_now_playing_page.dart';
import 'widgets/mobile/mobile_playlist_view.dart';
import 'widgets/mobile/mobile_search_view.dart';
import 'widgets/mobile/mobile_search_to_playlist_page.dart';
import 'widgets/mobile/mobile_track_actions_sheet.dart';
import 'widgets/search_result_row.dart';
import 'widgets/top_search_bar.dart';
import 'menus/direct_playlist_picker_menu.dart';
import 'menus/add_to_playlist_menu.dart';
import 'menus/search_row_playlist_picker.dart';
import 'widgets/search_results_dropdown.dart';
import 'widgets/sort_menu_dropdown.dart';
import 'utils/track_formatting.dart';
import 'state/playlist_view_state.dart';
import 'state/library_state.dart';
import 'state/playback_state.dart';
import 'state/selection_state.dart';
import 'presenters/track_presenter.dart';
import 'controllers/playlist_editing_controller.dart';
import 'controllers/taskbar_sync_controller.dart';
import 'controllers/download_cache_controller.dart';
import 'controllers/playback_controller.dart';
import 'controllers/playlist_import_controller.dart';
import 'controllers/charts_controller.dart';
import 'state/charts_state.dart';
import 'controllers/artist_controller.dart';
import 'state/artist_state.dart';
import 'widgets/artist_page_view.dart';
import 'dialogs/confirmation_dialog.dart';
import 'dialogs/create_playlist_dialog.dart';
import 'dialogs/edit_playlist_dialog.dart';
import 'dialogs/profile_settings_dialog.dart';
import 'state/theme_state.dart';
import 'state/general_settings_state.dart';
import 'theme/app_theme.dart';
import 'l10n/generated/app_localizations.dart';
import 'models/playlist_display_name.dart';
import 'models/sort_criterion_labels.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  if (isDesktop) await windowManager.ensureInitialized();

  await initMobilePaths();
  if (Platform.isAndroid) unawaited(AndroidMediaStoreService.purgeLegacyCacheFolder());
  final prefs = await SharedPreferences.getInstance();
  final themeState = ThemeState.load(prefs);
  final generalSettings = GeneralSettingsState.load(prefs);
  if (isDesktop) launchAtStartup.setup(appName: 'Yora', appPath: Platform.resolvedExecutable);
  final savedMaximized = prefs.getBool(prefsWindowMaximizedKey);
  final savedX = prefs.getDouble(prefsWindowXKey);
  final savedY = prefs.getDouble(prefsWindowYKey);
  final savedWidth = prefs.getDouble(prefsWindowWidthKey);
  final savedHeight = prefs.getDouble(prefsWindowHeightKey);

  if (isDesktop) {
  unawaited(windowManager.waitUntilReadyToShow(
    const WindowOptions(
      minimumSize: Size(kMinWindowWidth, kMinWindowHeight),
      titleBarStyle: TitleBarStyle.hidden,
    ),
    () async {
      if (savedMaximized == false &&
          savedX != null &&
          savedY != null &&
          savedWidth != null &&
          savedHeight != null) {
        final safeBounds = await sanitizedRestoreBounds(
          Rect.fromLTWH(savedX, savedY, savedWidth, savedHeight),
        );
        await windowManager.setBounds(safeBounds);
        final size = await windowManager.getSize();
        await windowManager.setSize(Size(size.width + 1, size.height));
        await windowManager.setSize(size);
      } else {
        await windowManager.setBounds(await defaultRestoreBounds());
        await windowManager.maximize();
      }
      await windowManager.show();
      await windowManager.focus();
    },
  ));
  }

  runApp(YoraApp(themeState: themeState, generalSettings: generalSettings));
}

class YoraApp extends StatefulWidget {
  final ThemeState themeState;
  final GeneralSettingsState generalSettings;
  const YoraApp({super.key, required this.themeState, required this.generalSettings});

  @override
  State<YoraApp> createState() => _YoraAppState();
}

class _YoraAppState extends State<YoraApp> {
  @override
  void initState() {
    super.initState();
    widget.themeState.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    widget.themeState.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final palette = widget.themeState.palette;
    return MaterialApp(
      title: 'Yora',
      debugShowCheckedModeBanner: false,
      locale: widget.generalSettings.languageCode != null ? Locale(widget.generalSettings.languageCode!) : null,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: widget.themeState.accentSeed,
          brightness: palette.brightness,
        ).copyWith(
          primary: widget.themeState.accentSeed,
          onPrimary: widget.themeState.accentForeground,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: palette.background,
      ),
      builder: (context, child) => AppTheme(themeState: widget.themeState, child: child!),
      home: MainDashboardScreen(themeState: widget.themeState, generalSettings: widget.generalSettings),
    );
  }
}

sealed class _NavPage {
  const _NavPage();
}

class _NavHome extends _NavPage {
  const _NavHome();
}

class _NavExplorer extends _NavPage {
  const _NavExplorer();
}

class _NavPlaylist extends _NavPage {
  final String name;
  const _NavPlaylist(this.name);
}

class _NavArtist extends _NavPage {
  final String artistName;
  const _NavArtist(this.artistName);
}

class MainDashboardScreen extends StatefulWidget {
  final ThemeState themeState;
  final GeneralSettingsState generalSettings;
  const MainDashboardScreen({super.key, required this.themeState, required this.generalSettings});

  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen> with WindowListener, tray.TrayListener {
  static const double _kSidebarMinWidth = 72.0;
  static const double _kSidebarMaxWidth = 400.0;
  static const double _kSidebarCollapseThreshold = 120.0;

  static const List<String> _audioExtensions = ['.mp3', '.flac', '.wav', '.m4a', '.aac', '.ogg'];

  static const MethodChannel _taskbarChannel = MethodChannel('yora/taskbar');

  int _selectedIndex = 0;
  double _sidebarWidth = 260.0;
  bool get _isSidebarCollapsed => _sidebarWidth < _kSidebarCollapseThreshold;
  double _uiScale = 1.0;
  static const double _kUiScaleMin = 0.8;
  static const double _kUiScaleMax = 1.4;
  void _zoomIn() => setState(() => _uiScale = (_uiScale + 0.1).clamp(_kUiScaleMin, _kUiScaleMax));
  void _zoomOut() => setState(() => _uiScale = (_uiScale - 0.1).clamp(_kUiScaleMin, _kUiScaleMax));
  void _zoomReset() => setState(() => _uiScale = 1.0);

  final LayerLink _sortControlLayerLink = LayerLink();
  OverlayEntry? _sortMenuOverlayEntry;

  String _profileName = '';
  String? _profileImagePath;

  final YoutubeBackend _ytDlpService =
      Platform.isAndroid ? YtDlpAndroidService() : (Platform.isIOS ? YoutubeExplodeService() : YtDlpService());
  final MetadataLookupService _metadataLookupService = MetadataLookupService();
  late final TrackMetadataRepairService _trackMetadataRepairService =
      TrackMetadataRepairService(ytDlpService: _ytDlpService);
  late final PlaylistImportService _playlistImportService = PlaylistImportService(_ytDlpService);
  final PlaylistViewState _playlistView = PlaylistViewState();
  final LibraryState _library = LibraryState();
  final PlaybackState _playback = PlaybackState();
  final SelectionState _selection = SelectionState();
  AppLocalizations _l10n() => AppLocalizations.of(context);
  late final TrackPresenter _trackPresenter = TrackPresenter(_library, _playback, _playlistView, widget.themeState, _l10n);
  final DiscordPresenceService _discordPresence = DiscordPresenceService();
  final MediaHotkeyService _mediaHotkeys = MediaHotkeyService();
  final MediaSessionService _mediaSession = MediaSessionService();

  late final TaskbarSyncController _taskbarSync = TaskbarSyncController(_playback, _trackPresenter, _l10n);
  late final PlaylistEditingController _editing = PlaylistEditingController(
    library: _library,
    selection: _selection,
    playback: _playback,
    playlistView: _playlistView,
    trackPresenter: _trackPresenter,
    themeState: widget.themeState,
    saveMedia: _saveMedia,
    showAppToast: _showAppToast,
    l10n: _l10n,
  );
  late final DownloadCacheController _downloads = DownloadCacheController(
    library: _library,
    playback: _playback,
    selection: _selection,
    ytDlpService: _ytDlpService,
    themeState: widget.themeState,
    saveMedia: _saveMedia,
    showAppToast: _showAppToast,
    completeTrackMetadata: _completeTrackMetadata,
    isMounted: () => mounted,
    requestRebuild: _requestControllerRebuild,
    l10n: _l10n,
    networkAllowsDownloads: () async => !isMobile || !widget.generalSettings.downloadOnWifiOnly || await isOnWifi(),
  );
  late final PlaybackController _playbackController = PlaybackController(
    audioPlayer: _audioPlayer,
    library: _library,
    playback: _playback,
    selection: _selection,
    downloads: _downloads,
    taskbarSync: _taskbarSync,
    generalSettings: widget.generalSettings,
    saveMedia: _saveMedia,
    showAppToast: _showAppToast,
    completeTrackMetadata: _completeTrackMetadata,
    refreshSearchOverlay: _refreshSearchOverlay,
    isMounted: () => mounted,
    requestRebuild: _requestControllerRebuild,
    l10n: _l10n,
    onPresenceUpdateNeeded: () => unawaited(_updateDiscordPresence()),
  );
  late final PlaylistImportController _playlistImport = PlaylistImportController(
    library: _library,
    selection: _selection,
    playlistImportService: _playlistImportService,
    ytDlpService: _ytDlpService,
    saveMedia: _saveMedia,
    showAppToast: _showAppToast,
    rewarmMissingOnlineCaches: _rewarmMissingOnlineCaches,
    isMounted: () => mounted,
    requestRebuild: _requestControllerRebuild,
    l10n: _l10n,
  );
  final ChartsState _chartsState = ChartsState();
  late final ChartsService _chartsService = ChartsService(ytDlpService: _ytDlpService);
  late final ChartsController _charts = ChartsController(
    state: _chartsState,
    chartsService: _chartsService,
    requestRebuild: _requestControllerRebuild,
  );
  final ArtistState _artistState = ArtistState();
  late final ArtistController _artist = ArtistController(
    state: _artistState,
    chartsService: _chartsService,
    requestRebuild: _requestArtistRebuild,
  );

  void _requestArtistRebuild() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  void _requestControllerRebuild() {
    if (!mounted) return;
    setState(() {});
    _playback.notifyChanged();
  }

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _rootFocusNode = FocusNode();
  final LayerLink _searchLayerLink = LayerLink();
  String _searchQuery = '';
  List<YtSearchResult> _searchResults = [];
  bool _isSearching = false;
  Timer? _searchDebounce;
  OverlayEntry? _searchResultsOverlay;

  bool _isDragging = false;

  String? _toastMessage;
  IconData _toastIcon = Icons.check_circle;
  Color _toastIconColor = Colors.deepPurpleAccent;
  Timer? _toastTimer;

  void _showAppToast(
    String message, {
    IconData icon = Icons.check_circle,
    Color? iconColor,
    bool persistent = false,
  }) {
    if (!mounted) return;
    _toastTimer?.cancel();
    _toastTimer = null;
    setState(() {
      _toastMessage = message;
      _toastIcon = icon;
      _toastIconColor = iconColor ?? AppTheme.paletteOf(context).textSecondary;
    });
    if (!persistent) {
      _toastTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _toastMessage = null);
      });
    }
  }

  Widget _buildAppToast() {
    final palette = AppTheme.paletteOf(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: palette.cardHover,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_toastIcon, color: _toastIconColor, size: 18),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                _toastMessage ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  late final Player _audioPlayer;
  bool _nowPlayingExpanded = false;
  bool _queuePanelOpen = false;
  final GlobalKey _audioBarKey = GlobalKey();
  double _audioBarHeight = 78;

  bool _isWindowMaximized = false;

  void _handlePlaylistViewChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _playlistView.addListener(_handlePlaylistViewChanged);
    _playback.shuffle = widget.generalSettings.shuffleEnabled;
    _playback.repeatMode = widget.generalSettings.repeatMode;
    _discordSettingLastSeen = widget.generalSettings.discordRichPresenceEnabled;
    widget.generalSettings.addListener(_handleGeneralSettingsChangedForDiscord);
    unawaited(_updateDiscordPresence());
    unawaited(_mediaHotkeys.register(
      onPlayPause: () => unawaited(_togglePlayPause()),
      onNext: () => unawaited(_playNext()),
      onPrevious: () => unawaited(_playPrevious()),
    ));
    unawaited(_mediaSession.init(
      onPlay: () {
        if (_playback.userPaused) unawaited(_togglePlayPause());
      },
      onPause: () {
        if (!_playback.userPaused) unawaited(_togglePlayPause());
      },
      onNext: () => unawaited(_playNext()),
      onPrevious: () => unawaited(_playPrevious()),
      onSeek: (position) => unawaited(_audioPlayer.seek(position)),
    ));
    if (isDesktop) {
    windowManager.addListener(this);
    windowManager.isMaximized().then((maximized) {
      if (mounted) setState(() => _isWindowMaximized = maximized);
    });
    unawaited(_initSystemTray());
    unawaited(launchAtStartup.isEnabled().then((enabled) {
      if (mounted) widget.generalSettings.syncLaunchAtStartupEnabled(enabled);
    }));
    unawaited(windowManager.setPreventClose(true));
    }
    unawaited(_charts.loadGenres());
    unawaited(_charts.loadCountries());
    unawaited(_charts.loadNewReleases());
    _searchFocusNode.addListener(() {
      _topSearchBarFocused = _searchFocusNode.hasFocus;
      if (_searchFocusNode.hasFocus && _searchQuery.trim().isNotEmpty && _searchResultsOverlay == null) {
        _showSearchResultsOverlay();
      }
    });
    GestureBinding.instance.pointerRouter.addGlobalRoute(_handleGlobalPointerDownForFocus);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_handleGlobalPointerDownForMouseNavigation);
    _audioPlayer = Player(configuration: const PlayerConfiguration(title: 'Yora'));
    _initAudioListeners();
    _loadSavedMedia().then((_) {
      _repairMissingOnlineTrackMetadata();
      _maybeAutoResumeLastSession();
      unawaited(_recoverCrashedOrphanCleanups());
      unawaited(_restoreMissingAndroidDownloads());
      if (isMobile && mounted) setState(() => _selection.selectedPlaylistFilter = null);
      final restoredPlaylist = _selection.selectedPlaylistFilter;
      _navHistory[0] = restoredPlaylist != null ? _NavPlaylist(restoredPlaylist) : (_selectedIndex == 1 ? const _NavExplorer() : const _NavHome());
    });
    _taskbarChannel.setMethodCallHandler((call) async {
      if (call.method != 'buttonClick') return;
      switch (call.arguments as int) {
        case 0:
          await _toggleLikeCurrentTrack();
          break;
        case 1:
          await _playPrevious();
          break;
        case 2:
          await _togglePlayPause();
          break;
        case 3:
          await _playNext();
          break;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateTaskbarThumbnailToolbar();
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _updateTaskbarThumbnailToolbar();
    });
  }

  void _handleGlobalPointerDownForFocus(PointerEvent event) {
    if (event is! PointerDownEvent) return;
    if (!mounted) return;
    if (_topSearchBarFocused || _playlistSearchFieldFocused) {
      _rootFocusNode.requestFocus();
    }
  }

  Future<void> _saveWindowState() async {
    final prefs = await SharedPreferences.getInstance();
    final isMaximized = await windowManager.isMaximized();
    await prefs.setBool(prefsWindowMaximizedKey, isMaximized);
    if (!isMaximized) {
      final bounds = await windowManager.getBounds();
      await prefs.setDouble(prefsWindowXKey, bounds.left);
      await prefs.setDouble(prefsWindowYKey, bounds.top);
      await prefs.setDouble(prefsWindowWidthKey, bounds.width);
      await prefs.setDouble(prefsWindowHeightKey, bounds.height);
    }
  }

  @override
  void onWindowResized() => unawaited(_saveWindowState());

  @override
  void onWindowMoved() => unawaited(_saveWindowState());

  @override
  void onWindowMaximize() {
    setState(() => _isWindowMaximized = true);
    unawaited(_saveWindowState());
  }

  @override
  void onWindowUnmaximize() {
    setState(() => _isWindowMaximized = false);
    unawaited(() async {
      await centerWindowOnPrimaryDisplay();
      await _saveWindowState();
    }());
  }

  void _syncMediaSession() {
    if (!MediaSessionService.isSupported) return;
    final path = _playback.currentPlayingPath;
    _mediaSession.update(
      id: path,
      title: path == null ? '' : _trackPresenter.title(path),
      artist: path == null ? '' : _trackPresenter.subtitle(path),
      thumbnailUrl: path == null ? null : _library.trackMetadata[path]?['thumbnailUrl'],
      position: _playback.position,
      duration: _playback.duration,
      isPlaying: !_playback.userPaused,
    );
  }

  Future<void> _updateDiscordPresence() async {
    _syncMediaSession();
    if (!widget.generalSettings.discordRichPresenceEnabled) {
      if (_discordPresence.isConnected) {
        await _discordPresence.clear();
        await _discordPresence.disconnect();
      }
      return;
    }
    if (!_discordPresence.isConnected) {
      await _discordPresence.connect();
    }
    final path = _playback.currentPlayingPath;
    if (path == null) {
      await _discordPresence.clear();
      return;
    }
    await _discordPresence.updateNowPlaying(
      title: _trackPresenter.title(path),
      artist: _trackPresenter.subtitle(path),
      thumbnailUrl: _library.trackMetadata[path]?['thumbnailUrl'],
      position: _playback.position,
      duration: _playback.duration,
      isPaused: _playback.userPaused,
    );
  }

  bool? _discordSettingLastSeen;
  void _handleGeneralSettingsChangedForDiscord() {
    final current = widget.generalSettings.discordRichPresenceEnabled;
    if (current == _discordSettingLastSeen) return;
    _discordSettingLastSeen = current;
    unawaited(_updateDiscordPresence());
  }

  Future<void> _quitApp() async {
    await windowManager.hide();
    try {
      await _audioPlayer.stop();
      await _saveWindowState();
      await _flushPendingOrphanCleanups();
      await _discordPresence.disconnect();
      await _mediaHotkeys.unregisterAll();
    } finally {
      await tray.trayManager.destroy();
      await windowManager.destroy();
    }
  }

  @override
  void onWindowClose() {
    unawaited(() async {
      if (Platform.isMacOS || widget.generalSettings.minimizeToTrayOnClose) {
        await _saveWindowState();
        if (!Platform.isMacOS && !widget.generalSettings.trayHintShown) {
          widget.generalSettings.markTrayHintShown();
          _showAppToast('Yora continue de fonctionner dans la zone de notification.', icon: Icons.info_outline);
        }
        await windowManager.hide();
        return;
      }
      await _quitApp();
    }());
  }

  @override
  void onTrayIconMouseDown() {
    unawaited(() async {
      await windowManager.show();
      await windowManager.focus();
    }());
  }

  @override
  void onTrayIconRightMouseDown() {
    if (Platform.isLinux) return;
    unawaited(const MethodChannel('tray_manager').invokeMethod('popUpContextMenu', {'bringAppToFront': true}));
  }

  Future<void> _initSystemTray() async {
    tray.trayManager.addListener(this);
    try {
      await tray.trayManager.setIcon(Platform.isWindows ? 'assets/app_icon.ico' : 'assets/app_icon.png');
      if (!Platform.isLinux) await tray.trayManager.setToolTip('Yora');
      await tray.trayManager.setContextMenu(
        tray.Menu(
          items: [
            tray.MenuItem(
              key: 'check_for_updates',
              label: _l10n().checkForUpdatesTrayLabel,
              onClick: (_) => openLink(githubRepoUrl),
            ),
            tray.MenuItem.separator(),
            tray.MenuItem(
              key: 'quit',
              label: _l10n().quitAppTrayLabel,
              onClick: (_) => unawaited(_quitApp()),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Initialisation de l\'icône système ignorée : $e');
    }
  }

  void _initAudioListeners() {
    _audioPlayer.stream.playing.listen((playing) {
      setState(() {
        _playback.isPlaying = playing;
        if (playing) _playback.loadingQueuePath = null;
      });
      _refreshSearchOverlay();
    });

    _audioPlayer.stream.completed.listen((completed) {
      if (!completed || _playbackController.isCrossfadeAdvancing) return;
      if (_playback.currentPlayingPath?.startsWith('preview:') == true) {
        unawaited(_playbackController.resumeInterruptedByPreview());
        return;
      }
      _playNext(userInitiated: false);
    });

    _audioPlayer.stream.duration.listen((newDuration) {
      if (_playbackController.isResumingAfterPreview) return;
      setState(() {
        _playback.duration = newDuration;
      });
      unawaited(_updateDiscordPresence());
    });

    _audioPlayer.stream.position.listen((position) {
      if (_playbackController.isResumingAfterPreview) return;
      _playback.setPosition(position);
      _playbackController.maybeTriggerCrossfade();
    });

    _audioPlayer.stream.error.listen((error) {
      debugPrint('Erreur lecteur : $error');
    });
  }

  @override
  void dispose() {
    _playlistView.removeListener(_handlePlaylistViewChanged);
    _playlistView.dispose();
    widget.generalSettings.removeListener(_handleGeneralSettingsChangedForDiscord);
    unawaited(_discordPresence.disconnect());
    unawaited(_mediaHotkeys.unregisterAll());
    if (isDesktop) {
      windowManager.removeListener(this);
      tray.trayManager.removeListener(this);
    }
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_handleGlobalPointerDownForFocus);
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_handleGlobalPointerDownForMouseNavigation);
    _audioPlayer.dispose();
    _toastTimer?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _rootFocusNode.dispose();
    _removeSearchResultsOverlay();
    _removeSortMenuOverlay();
    for (final timer in _pendingOrphanCleanup.values) {
      timer.cancel();
    }
    super.dispose();
  }

  Map<String, Map<String, dynamic>> _ensureLikedPlaylist(Map<String, Map<String, dynamic>> playlists) {
    MapEntry<String, Map<String, dynamic>>? likedEntry;
    for (final entry in playlists.entries) {
      if (entry.value['isLiked'] == true) {
        likedEntry = entry;
        break;
      }
    }
    if (likedEntry != null) {
      if (playlists.keys.first == likedEntry.key) return playlists;
      final reordered = <String, Map<String, dynamic>>{likedEntry.key: likedEntry.value};
      for (final entry in playlists.entries) {
        if (entry.key != likedEntry.key) reordered[entry.key] = entry.value;
      }
      return reordered;
    }

    if (playlists.containsKey('Favoris') && !playlists.containsKey('Titres likés')) {
      final favoris = playlists['Favoris']!;
      final reordered = <String, Map<String, dynamic>>{
        'Titres likés': {...favoris, 'isLiked': true},
      };
      for (final entry in playlists.entries) {
        if (entry.key != 'Favoris') reordered[entry.key] = entry.value;
      }
      return reordered;
    }

    final reordered = <String, Map<String, dynamic>>{
      'Titres likés': {'tracks': <String>[], 'image': null, 'description': '', 'isLiked': true},
    };
    reordered.addAll(playlists);
    return reordered;
  }

  Map<String, Map<String, dynamic>> _ensureSpecialPlaylists(Map<String, Map<String, dynamic>> playlists) {
    final withLiked = _ensureLikedPlaylist(playlists);
    MapEntry<String, Map<String, dynamic>>? localFilesEntry;
    for (final entry in withLiked.entries) {
      if (entry.value['isLocalFiles'] == true) {
        localFilesEntry = entry;
        break;
      }
    }
    final localFilesName = localFilesEntry?.key ?? 'Fichiers locaux';
    final localFilesData = <String, dynamic>{
      ...?localFilesEntry?.value,
      'tracks': _library.musicPaths,
      'isLocalFiles': true,
    };
    final reordered = <String, Map<String, dynamic>>{};
    var afterFirst = false;
    for (final entry in withLiked.entries) {
      if (entry.key == localFilesName) continue;
      reordered[entry.key] = entry.value;
      if (!afterFirst) {
        reordered[localFilesName] = localFilesData;
        afterFirst = true;
      }
    }
    if (!afterFirst) reordered[localFilesName] = localFilesData;
    return reordered;
  }

  Future<void> _loadSavedMedia() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final savedMusic = prefs.getStringList('musicPaths') ?? [];
    final savedProfileName = prefs.getString('profileName') ?? '';
    final savedProfileImagePath = prefs.getString('profileImagePath');
    final savedCustomDownloadDir = prefs.getString('customDownloadDir');
    final savedCustomCacheDir = prefs.getString('customCacheDir');
    for (final key in [
      'spotifyClientId',
      'spotifyClientSecret',
      'spotifyAccessToken',
      'spotifyRefreshToken',
      'spotifyTokenExpiry',
      'spotifyDisplayName',
    ]) {
      await prefs.remove(key);
    }
    for (final key in ['photoVideoPaths', 'albumsData']) {
      await prefs.remove(key);
    }

    Map<String, Map<String, dynamic>> loadedPlaylists = _library.musicPlaylists;
    final savedPlaylistsString = prefs.getString('playlistsData');
    if (savedPlaylistsString != null) {
      try {
        final decoded = jsonDecode(savedPlaylistsString) as Map<String, dynamic>;
        final rebuilt = <String, Map<String, dynamic>>{};
        for (final entry in decoded.entries) {
          try {
            final value = entry.value;
            if (value is Map) {
              rebuilt[entry.key] = {
                'tracks': List<String>.from(value['tracks'] ?? []),
                'image': value['image'],
                'description': value['description'] ?? '',
                'isLiked': value['isLiked'] == true,
              };
            } else {
              rebuilt[entry.key] = {
                'tracks': List<String>.from(value as List),
                'image': null,
                'description': '',
                'isLiked': false,
              };
            }
          } catch (_) {}
        }
        if (rebuilt.isNotEmpty) loadedPlaylists = rebuilt;
      } catch (_) {}
    }
    loadedPlaylists = _ensureSpecialPlaylists(loadedPlaylists);

    Map<String, Map<String, String>> loadedTrackMetadata = {};
    final savedTrackMetadataString = prefs.getString('trackMetadata');
    if (savedTrackMetadataString != null) {
      try {
        final decoded = jsonDecode(savedTrackMetadataString) as Map<String, dynamic>;
        loadedTrackMetadata = decoded.map(
          (key, value) => MapEntry(key, Map<String, String>.from(value as Map)),
        );
      } catch (_) {}
    }

    Map<String, String> loadedTrackAddedDates = {};
    final savedTrackAddedDatesString = prefs.getString('trackAddedDates');
    if (savedTrackAddedDatesString != null) {
      try {
        final decoded = jsonDecode(savedTrackAddedDatesString) as Map<String, dynamic>;
        loadedTrackAddedDates = decoded.map((key, value) => MapEntry(key, value as String));
      } catch (_) {}
    }

    Map<String, String> loadedTrackLastPlayedDates = {};
    final savedTrackLastPlayedDatesString = prefs.getString('trackLastPlayedDates');
    if (savedTrackLastPlayedDatesString != null) {
      try {
        final decoded = jsonDecode(savedTrackLastPlayedDatesString) as Map<String, dynamic>;
        loadedTrackLastPlayedDates = decoded.map((key, value) => MapEntry(key, value as String));
      } catch (_) {}
    }

    Map<String, String> loadedPlaylistCreatedDates = {};
    final savedPlaylistCreatedDatesString = prefs.getString('playlistCreatedDates');
    if (savedPlaylistCreatedDatesString != null) {
      try {
        final decoded = jsonDecode(savedPlaylistCreatedDatesString) as Map<String, dynamic>;
        loadedPlaylistCreatedDates = decoded.map((key, value) => MapEntry(key, value as String));
      } catch (_) {}
    }

    Map<String, int> loadedPlaylistPlayCounts = {};
    final savedPlaylistPlayCountsString = prefs.getString('playlistPlayCounts');
    if (savedPlaylistPlayCountsString != null) {
      try {
        final decoded = jsonDecode(savedPlaylistPlayCountsString) as Map<String, dynamic>;
        loadedPlaylistPlayCounts = decoded.map((key, value) => MapEntry(key, value as int));
      } catch (_) {}
    }

    Map<String, Duration> loadedTrackDurations = {};
    final savedTrackDurationsString = prefs.getString('trackDurationsMs');
    if (savedTrackDurationsString != null) {
      try {
        final decoded = jsonDecode(savedTrackDurationsString) as Map<String, dynamic>;
        loadedTrackDurations = decoded.map(
          (key, value) => MapEntry(key, Duration(milliseconds: value as int)),
        );
      } catch (_) {}
    }

    final savedVolume = prefs.getDouble('volume') ?? 50.0;
    final savedSidebarWidth = prefs.getDouble('sidebarWidth');
    final savedSelectedIndex = prefs.getInt('selectedIndex') ?? 0;
    final savedPlaylistFilter = prefs.getString('selectedPlaylistFilter');
    final restoredPlaylistFilter = (savedPlaylistFilter != null &&
            savedPlaylistFilter.isNotEmpty &&
            loadedPlaylists.containsKey(savedPlaylistFilter))
        ? savedPlaylistFilter
        : (savedSelectedIndex == 0 || savedSelectedIndex == 1 ? null : 'Fichiers locaux');

    setState(() {
      _library.musicPlaylists = loadedPlaylists;
      _library.trackMetadata
        ..clear()
        ..addAll(loadedTrackMetadata);
      _library.trackAddedDates
        ..clear()
        ..addAll(loadedTrackAddedDates);
      _library.trackLastPlayedDates
        ..clear()
        ..addAll(loadedTrackLastPlayedDates);
      _library.playlistCreatedDates
        ..clear()
        ..addAll(loadedPlaylistCreatedDates);
      _library.playlistPlayCounts
        ..clear()
        ..addAll(loadedPlaylistPlayCounts);
      _library.trackDurations
        ..clear()
        ..addAll(loadedTrackDurations);
      _profileName = savedProfileName;
      _profileImagePath = savedProfileImagePath;
      _customDownloadDir = savedCustomDownloadDir;
      _customCacheDir = savedCustomCacheDir;
      _playback.volume = savedVolume;
      if (savedSidebarWidth != null) {
        _sidebarWidth = savedSidebarWidth.clamp(_kSidebarMinWidth, _kSidebarMaxWidth);
      }
      _selectedIndex = savedSelectedIndex;
      _selection.selectedPlaylistFilter = restoredPlaylistFilter;
      for (var path in savedMusic) {
        if (!_library.musicPaths.contains(path)) _library.musicPaths.add(path);
      }
      _library.musicPaths.removeWhere((path) => path.startsWith('youtube:'));
      for (final playlist in _library.musicPlaylists.values) {
        (playlist['tracks'] as List<String>).removeWhere((path) => path.startsWith('youtube:'));
      }
    });
    await _audioPlayer.setVolume(_playback.volume);
    await _saveMedia();
    unawaited(_rewarmMissingOnlineCaches());
  }

  Future<void> _rewarmMissingOnlineCaches() async => _downloads.rewarmMissingOnlineCaches();

  Future<void> _saveMediaQueue = Future.value();

  static const _orphanCleanupGracePeriod = Duration(minutes: 5);
  final Map<String, Timer> _pendingOrphanCleanup = {};

  Future<void> _persistPendingOrphanCleanupPaths() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('pendingOrphanCleanupPaths', _pendingOrphanCleanup.keys.toList());
  }

  void _scheduleOrphanCleanup(String path) {
    if (_pendingOrphanCleanup.containsKey(path)) return;
    _pendingOrphanCleanup[path] = Timer(_orphanCleanupGracePeriod, () {
      _pendingOrphanCleanup.remove(path);
      unawaited(_persistPendingOrphanCleanupPaths());
      _library.trackMetadata.remove(path);
      _library.trackAddedDates.remove(path);
      _library.trackLastPlayedDates.remove(path);
      _library.trackDurations.remove(path);
      _deleteOrphanedDownload(path);
      _saveMedia();
    });
    unawaited(_persistPendingOrphanCleanupPaths());
  }

  void _cancelOrphanCleanup(String path) {
    final timer = _pendingOrphanCleanup.remove(path);
    if (timer == null) return;
    timer.cancel();
    unawaited(_persistPendingOrphanCleanupPaths());
  }

  Future<void> _flushPendingOrphanCleanups() async {
    if (_pendingOrphanCleanup.isEmpty) return;
    final paths = _pendingOrphanCleanup.keys.toList();
    for (final timer in _pendingOrphanCleanup.values) {
      timer.cancel();
    }
    _pendingOrphanCleanup.clear();
    await _persistPendingOrphanCleanupPaths();
    for (final path in paths) {
      _library.trackMetadata.remove(path);
      _library.trackAddedDates.remove(path);
      _library.trackLastPlayedDates.remove(path);
      _library.trackDurations.remove(path);
      await _deleteOrphanedDownload(path);
    }
    await _saveMedia();
  }

  Future<void> _recoverCrashedOrphanCleanups() async {
    final prefs = await SharedPreferences.getInstance();
    final paths = prefs.getStringList('pendingOrphanCleanupPaths') ?? [];
    if (paths.isEmpty) return;
    final referencedPaths = <String>{..._library.musicPaths};
    for (final playlist in _library.musicPlaylists.values) {
      referencedPaths.addAll(playlist['tracks'] as List<String>);
    }
    var changed = false;
    for (final path in paths) {
      if (referencedPaths.contains(path)) continue;
      _library.trackMetadata.remove(path);
      _library.trackAddedDates.remove(path);
      _library.trackLastPlayedDates.remove(path);
      _library.trackDurations.remove(path);
      await _deleteOrphanedDownload(path);
      changed = true;
    }
    await prefs.remove('pendingOrphanCleanupPaths');
    if (changed) await _saveMedia();
  }

  Future<void> _saveMedia() async {
    final previous = _saveMediaQueue;
    final completer = Completer<void>();
    _saveMediaQueue = completer.future;
    await previous.catchError((_) {});
    try {
      await _saveMediaImpl();
    } finally {
      completer.complete();
    }
  }

  Future<void> _saveMediaImpl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('musicPaths', _library.musicPaths);
    await prefs.setString('playlistsData', jsonEncode(_library.musicPlaylists));
    final referencedPaths = <String>{..._library.musicPaths};
    for (final playlist in _library.musicPlaylists.values) {
      referencedPaths.addAll(playlist['tracks'] as List<String>);
    }
    for (final path in referencedPaths) {
      _library.trackAddedDates.putIfAbsent(path, () => DateTime.now().toIso8601String());
    }
    await prefs.setString('trackAddedDates', jsonEncode(_library.trackAddedDates));
    await prefs.setString('trackLastPlayedDates', jsonEncode(_library.trackLastPlayedDates));
    await prefs.setString('playlistCreatedDates', jsonEncode(_library.playlistCreatedDates));
    await prefs.setString('playlistPlayCounts', jsonEncode(_library.playlistPlayCounts));
    await prefs.setString('trackMetadata', jsonEncode(_library.trackMetadata));
    for (final path in _library.trackMetadata.keys.toList()) {
      if (referencedPaths.contains(path)) {
        _cancelOrphanCleanup(path);
        continue;
      }
      final current = _playback.currentPlayingPath;
      final matchesCurrentPlayback =
          current != null && (current == path || _likeKeyForPath(current) == path);
      if (matchesCurrentPlayback) {
        await _audioPlayer.stop();
        if (mounted) setState(() => _playback.currentPlayingPath = null);
      }
      _scheduleOrphanCleanup(path);
    }
    await _persistTrackDurations();
  }

  Future<void> _deleteOrphanedDownload(String path) => _downloads.deleteOrphanedDownload(path);

  Future<void> _restoreMissingAndroidDownloads() async {
    if (!Platform.isAndroid) return;
    final downloadsDir = _downloads.onlineDownloadsDir.path;
    final missing = <String>[];
    for (final path in _library.musicPaths) {
      if (path.startsWith(downloadsDir) && !await File(path).exists()) missing.add(path);
    }
    if (missing.isEmpty) return;
    final restored = await AndroidMediaStoreService.restoreDownloads(missing);
    if (restored > 0 && mounted) setState(() {});
  }

  Future<void> _saveProfileSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profileName', _profileName);
    if (_profileImagePath != null) {
      await prefs.setString('profileImagePath', _profileImagePath!);
    } else {
      await prefs.remove('profileImagePath');
    }
    if (_customDownloadDir != null) {
      await prefs.setString('customDownloadDir', _customDownloadDir!);
    } else {
      await prefs.remove('customDownloadDir');
    }
    if (_customCacheDir != null) {
      await prefs.setString('customCacheDir', _customCacheDir!);
    } else {
      await prefs.remove('customCacheDir');
    }
  }

  Future<void> _onTrackTap(List<String> queueSource, int index, {String? sourcePlaylist}) =>
      _playbackController.onTrackTap(queueSource, index, sourcePlaylist: sourcePlaylist);

  Future<void> _togglePlayPause() => _playbackController.togglePlayPause();

  void _updateTaskbarThumbnailToolbar() => _taskbarSync.update();

  void _setVolume(double value) {
    setState(() => _playback.volume = value);
    _audioPlayer.setVolume(value);
    SharedPreferences.getInstance().then((prefs) => prefs.setDouble('volume', value));
  }

  void _toggleMute() {
    if (_playback.volume > 0) {
      _playback.volumeBeforeMute = _playback.volume;
      _setVolume(0);
    } else {
      _setVolume(_playback.volumeBeforeMute ?? 50);
      _playback.volumeBeforeMute = null;
    }
  }

  MapEntry<String, Map<String, dynamic>>? get _likedPlaylistEntry => _trackPresenter.likedPlaylistEntry;
  String _likeKeyForPath(String path) => _trackPresenter.likeKeyForPath(path);

  Future<void> _toggleLikeCurrentTrack() async {
    final path = _playback.currentPlayingPath;
    final liked = _likedPlaylistEntry;
    if (path == null || liked == null) return;
    final key = _likeKeyForPath(path);
    final tracks = liked.value['tracks'] as List<String>;
    setState(() {
      if (tracks.contains(key)) {
        tracks.remove(key);
      } else {
        tracks.add(key);
        final preview = _playback.previewVideo;
        if (isPreviewTrack(path) && preview != null) {
          _library.trackMetadata[key] = metadataMap(preview);
        }
      }
      _playback.syncQueueWithPlaylistTracks(liked.key, tracks);
    });
    _updateTaskbarThumbnailToolbar();
    await _saveMedia();
  }

  void _ensureDurationProbed(String path) {
    if (_library.trackDurations.containsKey(path) || _library.durationProbeInFlight.contains(path)) return;
    _library.durationProbeInFlight.add(path);
    unawaited(() async {
      final duration = await _ytDlpService.probeDuration(path);
      _library.durationProbeInFlight.remove(path);
      if (duration != null && mounted) {
        setState(() => _library.trackDurations[path] = duration);
        await _persistTrackDurations();
      }
    }());
  }

  Future<void> _persistTrackDurations() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'trackDurationsMs',
      jsonEncode(_library.trackDurations.map((key, value) => MapEntry(key, value.inMilliseconds))),
    );
  }

  void _completeTrackMetadata(String path, YtSearchResult video, File realFile) {
    if (_library.trackMetadataCompletedOrFailed.contains(path) || _library.trackMetadataCompletionInFlight.contains(path)) {
      return;
    }
    final isOnline = isOnlineTrack(path);
    final meta = _library.trackMetadata[path];
    final hasDuration = isOnline ? (meta?['durationMs'] != null) : _library.trackDurations.containsKey(path);
    final hasAlbum = meta?['album']?.isNotEmpty ?? false;
    if (hasDuration && hasAlbum) return;
    _library.trackMetadataCompletionInFlight.add(path);
    unawaited(() async {
      try {
        final duration = hasDuration ? null : await _ytDlpService.probeDuration(realFile.path);
        final albumInfo = (hasAlbum || video.title.isEmpty)
            ? null
            : await _metadataLookupService.lookupAlbum(video.title, video.author);
        if (!mounted) return;
        var metaChanged = false;
        if (duration != null) {
          if (isOnline) {
            final updated = Map<String, String>.from(_library.trackMetadata[path] ?? {});
            updated['durationMs'] = duration.inMilliseconds.toString();
            _library.trackMetadata[path] = updated;
            metaChanged = true;
          } else {
            _library.trackDurations[path] = duration;
          }
        }
        if (albumInfo != null && (albumInfo.album != null || albumInfo.releaseYear != null)) {
          final updated = Map<String, String>.from(_library.trackMetadata[path] ?? {});
          if (albumInfo.album != null) updated['album'] = albumInfo.album!;
          if (albumInfo.releaseYear != null && (updated['year']?.isEmpty ?? true)) {
            updated['year'] = albumInfo.releaseYear!;
          }
          _library.trackMetadata[path] = updated;
          metaChanged = true;
        }
        if (metaChanged || duration != null) {
          setState(() {});
          if (metaChanged) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('trackMetadata', jsonEncode(_library.trackMetadata));
          }
          if (duration != null && !isOnline) await _persistTrackDurations();
        }
      } finally {
        _library.trackMetadataCompletionInFlight.remove(path);
        _library.trackMetadataCompletedOrFailed.add(path);
      }
    }());
  }

  Future<void> _repairMissingOnlineTrackMetadata() async {
    final brokenIds = <String>{};
    for (final playlist in _library.musicPlaylists.values) {
      for (final path in playlist['tracks'] as List<String>) {
        if (!isOnlineTrack(path)) continue;
        if (_library.trackMetadata[path]?['title'] == null) {
          brokenIds.add(path.substring('online:'.length));
        }
      }
    }
    if (brokenIds.isEmpty) return;
    var repairedCount = 0;
    for (final id in brokenIds) {
      if (!mounted) return;
      final video = await _trackMetadataRepairService.fetchVideoInfo(id);
      if (video == null || !mounted) continue;
      setState(() => _library.trackMetadata['online:$id'] = metadataMap(video));
      repairedCount++;
    }
    if (repairedCount == 0 || !mounted) return;
    await _saveMedia();
    if (!mounted) return;
    _showAppToast(
      AppLocalizations.of(context).repairedTracksToast(repairedCount),
      icon: Icons.build_circle_outlined,
      iconColor: AppTheme.of(context).accent,
    );
  }

  String _trackDurationLabel(String path) {
    final label = _trackPresenter.durationLabel(path);
    if (label == '--:--' && !isOnlineTrack(path)) _ensureDurationProbed(path);
    return label;
  }

  List<String> _displayTracksForPlaylist(String playlistName, List<String> tracks) =>
      _trackPresenter.displayTracksForPlaylist(playlistName, tracks);

  void _removeSortMenuOverlay() {
    _sortMenuOverlayEntry?.remove();
    _sortMenuOverlayEntry = null;
  }

  void _applySortSelection(String playlistName, String? selected) =>
      _playlistView.applySortSelection(playlistName, selected);

  void _showSortMenu(String playlistName) {
    _removeSortMenuOverlay();
    _sortMenuOverlayEntry = OverlayEntry(
      builder: (overlayContext) => SortMenuDropdown(
        layerLink: _sortControlLayerLink,
        currentCriterion: _playlistView.sortCriterionFor(playlistName),
        onDismiss: _removeSortMenuOverlay,
        onSelectCriterion: (key) {
          _applySortSelection(playlistName, key ?? '__default__');
          _removeSortMenuOverlay();
        },
        onReset: () {
          _applySortSelection(playlistName, '__reset__');
          _removeSortMenuOverlay();
        },
      ),
    );
    Overlay.of(context).insert(_sortMenuOverlayEntry!);
  }

  String get _defaultCacheBase => _downloads.defaultCacheBase;
  void _prefetchFullPlaybackCache(YtSearchResult video) => _downloads.prefetchFullPlaybackCache(video);

  String? get _customDownloadDir => _downloads.customDownloadDir;
  set _customDownloadDir(String? value) => _downloads.customDownloadDir = value;
  String? get _customCacheDir => _downloads.customCacheDir;
  set _customCacheDir(String? value) => _downloads.customCacheDir = value;
  String? get _downloadingTrackPath => _downloads.downloadingTrackPath;
  bool get _bulkDownloadInProgress => _downloads.bulkDownloadInProgress;

  Future<void> _downloadCurrentTrackToLibrary() => _downloads.downloadCurrentTrackToLibrary();

  void _cleanupUnclaimedPreview() => _playbackController.cleanupUnclaimedPreview(resumeInterrupted: true);

  Future<void> _playPreview(YtSearchResult video) => _playbackController.playPreview(video);

  void _onSearchQueryChanged(String query) {
    setState(() => _searchQuery = query);
    _searchDebounce?.cancel();
    if (query.trim().isEmpty) {
      _cleanupUnclaimedPreview();
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      _removeSearchResultsOverlay();
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 500), () => _performSearch(query.trim()));
  }

  Future<List<YtSearchResult>> _searchTracks(String query) => _chartsService.searchWithMusicPriority(query);

  Future<void> _performSearch(String query) async {
    setState(() => _isSearching = true);
    _showSearchResultsOverlay();
    try {
      final results = await _searchTracks(query);
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      debugPrint('Erreur recherche : $e');
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
    }
    _showSearchResultsOverlay();
  }

  void _closeSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    _playback.previewRequestId++;
    _cleanupUnclaimedPreview();
    setState(() {
      _searchQuery = '';
      _searchResults = [];
      _isSearching = false;
      _playback.loadingPreviewId = null;
    });
    _removeSearchResultsOverlay();
  }

  void _removeSearchResultsOverlay() {
    _searchResultsOverlay?.remove();
    _searchResultsOverlay = null;
  }

  void _refreshSearchOverlay() {
    if (_searchResultsOverlay == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchResultsOverlay?.markNeedsBuild();
    });
  }

  void _showSearchResultsOverlay() {
    _removeSearchResultsOverlay();
    if (isMobile) return;
    if (_searchQuery.trim().isEmpty) return;
    _searchResultsOverlay = OverlayEntry(
      builder: (overlayContext) => SearchResultsDropdown(
        layerLink: _searchLayerLink,
        isSearching: _isSearching,
        results: _searchResults,
        onDismiss: _removeSearchResultsOverlay,
        resultRowBuilder: _buildSearchResultRow,
      ),
    );
    Overlay.of(context).insert(_searchResultsOverlay!);
  }

  Future<void> _confirmAndDownloadAllOnlineTracksInPlaylist(BuildContext context, String playlistName) async {
    final tracks = _library.musicPlaylists[playlistName]?['tracks'] as List<String>?;
    final onlineCount = tracks?.where(isOnlineTrack).toSet().length ?? 0;
    if (onlineCount == 0) {
      _showAppToast(
        AppLocalizations.of(context).allTracksAlreadyDownloadedToast,
        icon: Icons.check_circle,
        iconColor: AppTheme.of(context).accent,
      );
      return;
    }
    final confirmed = await showConfirmationDialog(
      context,
      title: AppLocalizations.of(context).downloadPlaylistConfirmTitle,
      content: AppLocalizations.of(context).downloadPlaylistConfirmContent(onlineCount),
      confirmLabel: AppLocalizations.of(context).downloadButtonLabel,
    );
    if (!confirmed || !context.mounted) return;
    await _downloads.downloadAllOnlineTracksInPlaylist(playlistName);
  }

  void _toggleLikeForSearchResult(YtSearchResult video) {
    final onlinePath = 'online:${video.id}';
    final liked = _likedPlaylistEntry;
    if (liked == null) return;
    final tracks = liked.value['tracks'] as List<String>;
    final currentlyLiked = tracks.contains(onlinePath);
    setState(() {
      _library.trackMetadata[onlinePath] = metadataMap(video);
      if (currentlyLiked) {
        tracks.remove(onlinePath);
      } else {
        tracks.add(onlinePath);
        if (_playback.previewVideo?.id == video.id) _playback.previewClaimed = true;
      }
      _playback.syncQueueWithPlaylistTracks(liked.key, tracks);
    });
    if (!currentlyLiked) _prefetchFullPlaybackCache(video);
    _refreshSearchOverlay();
    _saveMedia();
  }

  void _showSearchRowPlaylistPicker(BuildContext context, Offset position, YtSearchResult video) {
    final onlinePath = 'online:${video.id}';
    if (!_library.trackMetadata.containsKey(onlinePath)) {
      setState(() => _library.trackMetadata[onlinePath] = metadataMap(video));
    }
    if (isMobile) {
      showMobileTrackActionsSheet(
        context,
        path: onlinePath,
        trackPresenter: _trackPresenter,
        playlists: _library.musicPlaylists,
        startAtPlaylistPicker: true,
        onCreatePlaylist: () {
          _showCreatePlaylistDialog(pathsToAdd: {onlinePath});
          _prefetchFullPlaybackCache(video);
        },
        onToggleTracks: (playlistName, playlistTracks, isInPlaylist) async {
          await _toggleTracksInPlaylist(playlistName, playlistTracks, {onlinePath}, isInPlaylist);
          if (!isInPlaylist) _prefetchFullPlaybackCache(video);
        },
      );
      return;
    }
    showSearchRowPlaylistPicker(
      context,
      above: _searchResultsOverlay,
      position: position,
      path: onlinePath,
      playlists: _library.musicPlaylists,
      onCreatePlaylist: () {
        _showCreatePlaylistDialog(pathsToAdd: {onlinePath});
        _prefetchFullPlaybackCache(video);
      },
      onToggleInPlaylist: (playlistName, isInPlaylist) async {
        await _toggleTracksInPlaylist(
            playlistName, _library.musicPlaylists[playlistName]!['tracks'] as List<String>, {onlinePath}, isInPlaylist);
        if (!isInPlaylist) _prefetchFullPlaybackCache(video);
      },
    );
  }

  Widget _buildSearchResultRow(YtSearchResult video, {bool large = false}) => SearchResultRow(
        video: video,
        large: large,
        playback: _playback,
        trackPresenter: _trackPresenter,
        onTap: () => _playPreview(video),
        onToggleLike: () => _toggleLikeForSearchResult(video),
        onViewArtist: video.author.isEmpty ? null : _showArtistPage,
        onShowPlaylistPicker: (context, position) => _showSearchRowPlaylistPicker(context, position, video),
      );

  Widget _buildSearchBar() => TopSearchBar(
        layerLink: _searchLayerLink,
        controller: _searchController,
        focusNode: _searchFocusNode,
        query: _searchQuery,
        onQueryChanged: _onSearchQueryChanged,
        onClear: _closeSearch,
      );

  Future<void> _startQueue(List<String> queue, int startIndex, {String? sourcePlaylist, bool shuffleFromStart = false}) =>
      _playbackController.startQueue(queue, startIndex, sourcePlaylist: sourcePlaylist, shuffleFromStart: shuffleFromStart);

  void _handleTrackReorder(String playlistName, List<String> tracks, int oldIndex, int newIndex) =>
      setState(() => _editing.handleTrackReorder(playlistName, tracks, oldIndex, newIndex));

  void _undo() => setState(() => _editing.undo());

  void _redo() => setState(() => _editing.redo());

  void _selectAllTracksInCurrentPlaylist() => setState(() => _editing.selectAllTracksInCurrentPlaylist());

  void _copySelectedTracks({bool showToast = true}) => _editing.copySelectedTracks(notify: showToast);

  void _deleteSelectedTracks() => _editing.deleteSelectedTracks();

  void _cutSelectedTracks() => _editing.cutSelectedTracks();

  void _pasteTracksIntoCurrentPlaylist() => _editing.pasteTracksIntoCurrentPlaylist();

  void _togglePlaylistSearch() {
    final playlistName = _selection.selectedPlaylistFilter;
    if (playlistName == null) return;
    _playlistView.toggleSearch(playlistName);
  }

  void _openSortMenuFromKeyboard() {
    if (_sortMenuOverlayEntry != null) {
      _removeSortMenuOverlay();
      return;
    }
    final playlistName = _selection.selectedPlaylistFilter;
    if (playlistName == null) return;
    _showSortMenu(playlistName);
  }

  void _toggleShuffle() => setState(() {
        _playback.toggleShuffle();
        widget.generalSettings.shuffleEnabled = _playback.shuffle;
      });

  void _cycleRepeatMode() => setState(() {
        _playback.cycleRepeatMode();
        widget.generalSettings.repeatMode = _playback.repeatMode;
      });

  Future<void> _playNext({bool userInitiated = true}) => _playbackController.playNext(userInitiated: userInitiated);

  Future<void> _seekBy(Duration delta) => _playbackController.seekBy(delta);

  Future<void> _playPrevious() => _playbackController.playPrevious();

  Widget _buildAppMenuButton() => AppMenuButton(
        shuffleActive: _playback.shuffle,
        repeatActive: _playback.repeatMode != RepeatMode.off,
        onCreatePlaylist: _showCreatePlaylistDialog,
        onUndo: _undo,
        onRedo: _redo,
        onCut: _cutSelectedTracks,
        onCopy: _copySelectedTracks,
        onPaste: _pasteTracksIntoCurrentPlaylist,
        onDelete: _deleteSelectedTracks,
        onSelectAll: _selectAllTracksInCurrentPlaylist,
        onToggleSearch: _togglePlaylistSearch,
        onOpenSortMenu: _openSortMenuFromKeyboard,
        onShowPreferences: _showProfileSettingsDialog,
        onZoomIn: _zoomIn,
        onZoomOut: _zoomOut,
        onZoomReset: _zoomReset,
        onPlayPause: _togglePlayPause,
        onPlayNext: _playNext,
        onPlayPrevious: _playPrevious,
        onSeekForward: () => _seekBy(const Duration(seconds: 10)),
        onSeekBackward: () => _seekBy(const Duration(seconds: -10)),
        onToggleShuffle: _toggleShuffle,
        onCycleRepeatMode: _cycleRepeatMode,
        onVolumeUp: () => _setVolume((_playback.volume + 5).clamp(0.0, 100.0)),
        onVolumeDown: () => _setVolume((_playback.volume - 5).clamp(0.0, 100.0)),
        onAbout: () => openLink(githubRepoUrl),
      );

  Widget _buildTopBar() => TopBar(
        searchBar: _buildSearchBar(),
        appMenu: _buildAppMenuButton(),
        profileImagePath: _profileImagePath,
        isWindowMaximized: _isWindowMaximized,
        onHomeTap: () => _selectFixedView(0),
        onShowProfile: _showProfileSettingsDialog,
      );

  bool _topSearchBarFocused = false;
  bool _playlistSearchFieldFocused = false;
  bool get _isTypingInTextField =>
      _topSearchBarFocused || _playlistSearchFieldFocused;

  Widget _applyUiScale(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaledSize = Size(constraints.maxWidth / _uiScale, constraints.maxHeight / _uiScale);
        final windowSize = MediaQuery.sizeOf(context);
        return ClipRect(
          child: FittedBox(
            fit: BoxFit.fill,
            alignment: Alignment.topLeft,
            child: SizedBox.fromSize(
              size: scaledSize,
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(size: windowSize / _uiScale),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }

  void _openMacUninstaller() {
    final contents = File(Platform.resolvedExecutable).parent.parent.path;
    unawaited(Process.run('open', ['$contents/Resources/Désinstaller Yora.app']));
  }

  Widget _wrapWithNativeMenuBar(Widget child) {
    if (!Platform.isMacOS) return child;
    final l10n = AppLocalizations.of(context);
    PlatformMenuItem item(String label, VoidCallback onSelected, {MenuSerializableShortcut? shortcut}) =>
        PlatformMenuItem(label: label, shortcut: shortcut, onSelected: onSelected);
    return PlatformMenuBar(
      menus: [
        PlatformMenu(label: 'Yora', menus: [
          PlatformMenuItemGroup(members: [item(l10n.aboutMenuItem, () => openLink(githubRepoUrl))]),
          PlatformMenuItemGroup(members: [item(l10n.preferencesMenuItem, _showProfileSettingsDialog)]),
          if (PlatformProvidedMenuItem.hasMenu(PlatformProvidedMenuItemType.hide))
            const PlatformMenuItemGroup(members: [
              PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.hide),
              PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.hideOtherApplications),
            ]),
          PlatformMenuItemGroup(members: [item(l10n.uninstallMenuItem, _openMacUninstaller)]),
          PlatformMenuItemGroup(members: [
            item(l10n.quitAppTrayLabel, () => unawaited(_quitApp()),
                shortcut: const SingleActivator(LogicalKeyboardKey.keyQ, meta: true)),
          ]),
        ]),
        PlatformMenu(label: l10n.fileMenuLabel, menus: [
          item(l10n.createPlaylistTitle, _showCreatePlaylistDialog),
        ]),
        PlatformMenu(label: l10n.editMenuLabel, menus: [
          item(l10n.undoMenuItem, _undo),
          item(l10n.redoMenuItem, _redo),
          item(l10n.cutMenuItem, _cutSelectedTracks),
          item(l10n.copyMenuItem, _copySelectedTracks),
          item(l10n.pasteMenuItem, _pasteTracksIntoCurrentPlaylist),
          item(l10n.selectAllMenuItem, _selectAllTracksInCurrentPlaylist),
        ]),
        PlatformMenu(label: l10n.viewMenuLabel, menus: [
          item(l10n.zoomInMenuItem, _zoomIn),
          item(l10n.zoomOutMenuItem, _zoomOut),
          item(l10n.resetZoomMenuItem, _zoomReset),
        ]),
        PlatformMenu(label: l10n.playbackMenuLabel, menus: [
          item(l10n.playMenuItem, () => unawaited(_togglePlayPause())),
          item(l10n.nextMenuItem, () => unawaited(_playNext())),
          item(l10n.previousMenuItem, () => unawaited(_playPrevious())),
        ]),
      ],
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isMobile) return _buildMobileRoot();
    return _wrapWithNativeMenuBar(Focus(
      focusNode: _rootFocusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.space) {
          if (_isTypingInTextField) return KeyEventResult.ignored;
          _togglePlayPause();
          return KeyEventResult.handled;
        }
        if (_isTypingInTextField) return KeyEventResult.ignored;
        final pressed = HardwareKeyboard.instance.logicalKeysPressed;
        final ctrl = Platform.isMacOS
            ? (pressed.contains(LogicalKeyboardKey.metaLeft) || pressed.contains(LogicalKeyboardKey.metaRight))
            : (pressed.contains(LogicalKeyboardKey.controlLeft) || pressed.contains(LogicalKeyboardKey.controlRight));
        final shift = pressed.contains(LogicalKeyboardKey.shiftLeft) || pressed.contains(LogicalKeyboardKey.shiftRight);
        if (ctrl && key == LogicalKeyboardKey.keyN) {
          _showCreatePlaylistDialog();
          return KeyEventResult.handled;
        }
        if (ctrl && key == LogicalKeyboardKey.keyP) {
          _showProfileSettingsDialog();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.delete) {
          _deleteSelectedTracks();
          return KeyEventResult.handled;
        }
        if (ctrl && key == LogicalKeyboardKey.keyL) {
          _togglePlaylistSearch();
          return KeyEventResult.handled;
        }
        if (ctrl && key == LogicalKeyboardKey.keyF) {
          _openSortMenuFromKeyboard();
          return KeyEventResult.handled;
        }
        if (ctrl && key == LogicalKeyboardKey.keyA) {
          _selectAllTracksInCurrentPlaylist();
          return KeyEventResult.handled;
        }
        if (ctrl && key == LogicalKeyboardKey.keyC) {
          _copySelectedTracks();
          return KeyEventResult.handled;
        }
        if (ctrl && key == LogicalKeyboardKey.keyX) {
          _cutSelectedTracks();
          return KeyEventResult.handled;
        }
        if (ctrl && key == LogicalKeyboardKey.keyV) {
          _pasteTracksIntoCurrentPlaylist();
          return KeyEventResult.handled;
        }
        if (ctrl && key == LogicalKeyboardKey.keyZ) {
          _undo();
          return KeyEventResult.handled;
        }
        if (ctrl && key == LogicalKeyboardKey.keyY) {
          _redo();
          return KeyEventResult.handled;
        }
        if (ctrl && key == LogicalKeyboardKey.arrowRight) {
          _playNext();
          return KeyEventResult.handled;
        }
        if (ctrl && key == LogicalKeyboardKey.arrowLeft) {
          _playPrevious();
          return KeyEventResult.handled;
        }
        if (shift && key == LogicalKeyboardKey.arrowRight) {
          _seekBy(const Duration(seconds: 10));
          return KeyEventResult.handled;
        }
        if (shift && key == LogicalKeyboardKey.arrowLeft) {
          _seekBy(const Duration(seconds: -10));
          return KeyEventResult.handled;
        }
        if (ctrl && key == LogicalKeyboardKey.keyS) {
          _toggleShuffle();
          return KeyEventResult.handled;
        }
        if (ctrl && key == LogicalKeyboardKey.keyR) {
          _cycleRepeatMode();
          return KeyEventResult.handled;
        }
        if (ctrl && key == LogicalKeyboardKey.arrowUp) {
          _setVolume((_playback.volume + 5).clamp(0.0, 100.0));
          return KeyEventResult.handled;
        }
        if (ctrl && key == LogicalKeyboardKey.arrowDown) {
          _setVolume((_playback.volume - 5).clamp(0.0, 100.0));
          return KeyEventResult.handled;
        }
        if (ctrl && (key == LogicalKeyboardKey.equal || key == LogicalKeyboardKey.numpadAdd)) {
          _zoomIn();
          return KeyEventResult.handled;
        }
        if (ctrl && (key == LogicalKeyboardKey.minus || key == LogicalKeyboardKey.numpadSubtract)) {
          _zoomOut();
          return KeyEventResult.handled;
        }
        if (ctrl && key == LogicalKeyboardKey.digit0) {
          _zoomReset();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Stack(
      children: [
      if (widget.themeState.isGalaxyActive) const Positioned.fill(child: GalaxyBackground()),
      if (widget.themeState.isAuroraActive) const Positioned.fill(child: AuroraBackground()),
      if (widget.themeState.isImageThemeActive)
        Positioned.fill(child: ImageThemeBackground(imagePath: widget.themeState.customThemeImagePath!)),
      Scaffold(
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: Row(
              children: [
                _buildNavigationRail(),
                MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        _sidebarWidth = (_sidebarWidth + details.delta.dx)
                            .clamp(_kSidebarMinWidth, _kSidebarMaxWidth);
                      });
                    },
                    onHorizontalDragEnd: (_) {
                      SharedPreferences.getInstance().then((prefs) => prefs.setDouble('sidebarWidth', _sidebarWidth));
                    },
                    child: SizedBox(
                      width: 6,
                      child: VerticalDivider(thickness: 1, width: 1, color: AppTheme.paletteOf(context).border),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    child: DropTarget(
                      onDragEntered: (_) => setState(() => _isDragging = true),
                      onDragExited: (_) => setState(() => _isDragging = false),
                      onDragDone: (detail) async {
                        setState(() {
                          _isDragging = false;
                          final currentPlaylist = _selection.selectedPlaylistFilter != null
                              ? _library.musicPlaylists[_selection.selectedPlaylistFilter]
                              : null;
                          final currentPlaylistTracks = currentPlaylist?['tracks'] as List<String>?;
                          for (var file in detail.files) {
                            final ext = file.path.contains('.')
                                ? '.${file.path.split('.').last.toLowerCase()}'
                                : '';

                            if (_audioExtensions.contains(ext)) {
                              if (!_library.musicPaths.contains(file.path)) {
                                _library.musicPaths.add(file.path);
                              }
                              if (currentPlaylistTracks != null && !currentPlaylistTracks.contains(file.path)) {
                                currentPlaylistTracks.add(file.path);
                              }
                            }
                          }
                        });
                        await _saveMedia();
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: _isDragging ? AppTheme.of(context).accent.withValues(alpha: 0.1) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _applyUiScale(_buildSelectedScreenContent()),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_playback.currentPlayingPath != null) _buildSpotifyStyleAudioBar(),
        ],
      ),
      ),
      if (_playback.currentPlayingPath != null && _nowPlayingExpanded)
        Positioned(
          left: 0,
          bottom: _audioBarHeight,
          child: _buildExpandedNowPlayingPanel(),
        ),
      if (_queuePanelOpen)
        Positioned(
          right: 0,
          bottom: _audioBarHeight,
          child: _buildQueuePanel(),
        ),
      if (_toastMessage != null)
        Positioned(
          left: 0,
          right: 0,
          bottom: (_playback.currentPlayingPath != null ? _audioBarHeight : 0) + 16,
          child: IgnorePointer(
            child: Center(child: _buildAppToast()),
          ),
        ),
      ],
      ),
    ));
  }

  final List<_NavPage> _navHistory = [const _NavHome()];
  int _navHistoryIndex = 0;
  bool _navigatingViaHistory = false;

  void _pushNavHistory(_NavPage page) {
    if (_navigatingViaHistory) return;
    if (_navHistoryIndex < _navHistory.length - 1) {
      _navHistory.removeRange(_navHistoryIndex + 1, _navHistory.length);
    }
    _navHistory.add(page);
    _navHistoryIndex = _navHistory.length - 1;
  }

  void _restoreNavPage(_NavPage page) {
    _navigatingViaHistory = true;
    try {
      switch (page) {
        case _NavHome():
          _selectFixedView(0);
        case _NavExplorer():
          _selectFixedView(1);
        case _NavPlaylist(:final name):
          if (_library.musicPlaylists.containsKey(name)) {
            _selectPlaylistFromSidebar(name);
          } else {
            _selectFixedView(0);
          }
        case _NavArtist(:final artistName):
          _showArtistPage(artistName);
      }
    } finally {
      _navigatingViaHistory = false;
    }
  }

  void _navigateBack() {
    if (_navHistoryIndex <= 0) return;
    _navHistoryIndex--;
    _restoreNavPage(_navHistory[_navHistoryIndex]);
  }

  void _navigateForward() {
    if (_navHistoryIndex >= _navHistory.length - 1) return;
    _navHistoryIndex++;
    _restoreNavPage(_navHistory[_navHistoryIndex]);
  }

  void _handleGlobalPointerDownForMouseNavigation(PointerEvent event) {
    if (event is! PointerDownEvent) return;
    if (event.buttons & kBackMouseButton != 0) {
      _navigateBack();
    } else if (event.buttons & kForwardMouseButton != 0) {
      _navigateForward();
    }
  }

  void _selectFixedView(int index) {
    _pushNavHistory(index == 1 ? const _NavExplorer() : const _NavHome());
    setState(() {
      _selectedIndex = index;
      _selection.selectedPlaylistFilter = null;
      _selection.selectedTrackPaths.clear();
    });
    _artist.closeArtist();
    _saveLayoutState();
    _closeSearch();
  }

  Future<void> _saveLayoutState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selectedIndex', _selectedIndex);
    await prefs.setString('selectedPlaylistFilter', _selection.selectedPlaylistFilter ?? '');
  }

  Future<void> _deletePlaylist(String playlistName) async {
    final wasSelected = _selection.selectedPlaylistFilter == playlistName;
    setState(() {
      final deleted = _editing.deletePlaylist(playlistName);
      if (deleted && wasSelected) _selectedIndex = 0;
      if (deleted) _playlistImport.cancelImport(playlistName);
    });
    await _saveMedia();
  }

  Future<void> _confirmAndDeletePlaylist(String playlistName) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: AppLocalizations.of(context).deletePlaylistConfirmTitle,
      content: AppLocalizations.of(context).deletePlaylistConfirmContent(playlistDisplayName(playlistName, AppLocalizations.of(context))),
      confirmLabel: AppLocalizations.of(context).deleteButton,
    );
    if (!confirmed) return;
    await _deletePlaylist(playlistName);
    if (!mounted) return;
    _showAppToast(
      AppLocalizations.of(context).playlistDeletedToast(playlistDisplayName(playlistName, AppLocalizations.of(context))),
      icon: Icons.delete_outline,
      iconColor: AppTheme.paletteOf(context).textSecondary,
    );
  }

  Future<void> _toggleTrackInPlaylist(String playlistName, String path) async {
    final tracks = _library.musicPlaylists[playlistName]?['tracks'] as List<String>?;
    if (tracks == null) return;
    setState(() {
      if (tracks.contains(path)) {
        tracks.remove(path);
      } else {
        tracks.add(path);
      }
      _playback.syncQueueWithPlaylistTracks(playlistName, tracks);
    });
    await _saveMedia();
  }

  Future<void> _showDirectPlaylistPickerMenu(BuildContext context, Offset position, String path) =>
      showDirectPlaylistPickerMenu(
        context,
        position,
        path,
        playlists: _library.musicPlaylists,
        onCreatePlaylist: () => _showCreatePlaylistDialog(pathsToAdd: {path}),
        onToggleInPlaylist: (playlistName) => _toggleTrackInPlaylist(playlistName, path),
        isMounted: () => mounted,
      );

  Future<void> _toggleTracksInPlaylist(String playlistName, List<String> playlistTracks, Set<String> paths, bool isInPlaylist) async {
    setState(() {
      if (isInPlaylist) {
        playlistTracks.removeWhere(paths.contains);
      } else {
        for (final p in paths) {
          if (!playlistTracks.contains(p)) playlistTracks.add(p);
        }
      }
      _playback.syncQueueWithPlaylistTracks(playlistName, playlistTracks);
    });
    await _saveMedia();
    if (!mounted) return;
    _showAppToast(
      isInPlaylist
          ? AppLocalizations.of(context).removedFromPlaylistToast(playlistDisplayName(playlistName, AppLocalizations.of(context)))
          : AppLocalizations.of(context).addedToPlaylistToast(playlistDisplayName(playlistName, AppLocalizations.of(context))),
      icon: isInPlaylist ? Icons.remove_circle_outline : Icons.check_circle,
      iconColor: isInPlaylist ? AppTheme.paletteOf(context).textSecondary : AppTheme.of(context).accent,
    );
  }

  Future<void> _removeTracksFromPlaylist(List<String> removeFromTracks, Set<String> paths) async {
    final removedCount = paths.length;
    final playlistName = _selection.selectedPlaylistFilter;
    setState(() {
      if (playlistName != null) _editing.pushUndoSnapshot(playlistName, removeFromTracks);
      removeFromTracks.removeWhere(paths.contains);
      if (playlistName != null) _playback.syncQueueWithPlaylistTracks(playlistName, removeFromTracks);
    });
    await _saveMedia();
    if (!mounted) return;
    _showAppToast(
      AppLocalizations.of(context).tracksRemovedFromPlaylistToast(removedCount),
      icon: Icons.remove_circle_outline,
      iconColor: AppTheme.paletteOf(context).textSecondary,
    );
  }

  Future<void> _showAddToPlaylistMenu(
    BuildContext context,
    Offset position,
    Set<String> paths, {
    List<String>? removeFromTracks,
  }) {
    if (isMobile) {
      return showMobileTrackActionsSheet(
        context,
        path: paths.first,
        trackPresenter: _trackPresenter,
        playlists: _library.musicPlaylists,
        onCreatePlaylist: () => _showCreatePlaylistDialog(pathsToAdd: paths),
        onToggleTracks: (playlistName, playlistTracks, isInPlaylist) =>
            _toggleTracksInPlaylist(playlistName, playlistTracks, paths, isInPlaylist),
        removeFromTracks: removeFromTracks,
        onRemoveFromPlaylist: removeFromTracks == null ? null : (tracks) => _removeTracksFromPlaylist(tracks, paths),
        onAddToQueue: (tracks) => _playbackController.addToQueue(tracks),
        onViewArtist: _viewArtistCallbackFor(paths),
        onDownload: widget.generalSettings.showLocalDownloadButtons && paths.length == 1 && isOnlineTrack(paths.first)
            ? (path) => _downloads.downloadTrackFromMenu(path)
            : null,
      );
    }
    return showAddToPlaylistMenu(
      context,
      position,
      paths,
      removeFromTracks: removeFromTracks,
      playlists: _library.musicPlaylists,
      onCreatePlaylist: () => _showCreatePlaylistDialog(pathsToAdd: paths),
      onToggleTracks: (playlistName, playlistTracks, isInPlaylist) =>
          _toggleTracksInPlaylist(playlistName, playlistTracks, paths, isInPlaylist),
      onRemoveFromPlaylist: (tracks) => _removeTracksFromPlaylist(tracks, paths),
      onAddToQueue: (tracks) => _playbackController.addToQueue(tracks),
      onViewArtist: _viewArtistCallbackFor(paths),
    );
  }

  VoidCallback? _viewArtistCallbackFor(Set<String> paths) {
    if (paths.length != 1) return null;
    final author = _library.trackMetadata[paths.first]?['author'];
    if (author == null || author.isEmpty) return null;
    return () => _showArtistPage(splitArtistNames(author).first);
  }

  void _showArtistPage(String artistName) {
    _pushNavHistory(_NavArtist(artistName));
    _closeSearch();
    _mobilePlayerOpen = false;
    _mobileSearchAddPlaylist = null;
    _mobileAddSearchOpen = false;
    _artist.openArtist(artistName);
  }

  Widget _buildArtistView() => ArtistPageView(
        artistState: _artistState,
        resultRowBuilder: _buildSearchResultRow,
        onOpenRelease: _artist.openRelease,
        onCloseReleaseDetail: _artist.closeReleaseDetail,
        onClose: () {
          _closeSearch();
          _artist.closeArtist();
        },
      );

  Future<void> _addDroppedFilesToPlaylist(String playlistName, List<XFile> files) async {
    const audioExts = _audioExtensions;
    final tracks = _library.musicPlaylists[playlistName]?['tracks'] as List<String>?;
    if (tracks == null) return;

    bool changed = false;
    setState(() {
      for (final file in files) {
        final ext = file.path.contains('.') ? '.${file.path.split('.').last.toLowerCase()}' : '';
        if (!audioExts.contains(ext)) continue;
        if (!_library.musicPaths.contains(file.path)) {
          _library.musicPaths.add(file.path);
          changed = true;
        }
        if (!tracks.contains(file.path)) {
          tracks.add(file.path);
          changed = true;
        }
      }
      if (changed) _playback.syncQueueWithPlaylistTracks(playlistName, tracks);
    });
    if (changed) await _saveMedia();
  }

  void _selectPlaylistFromSidebar(String playlistName) {
    _pushNavHistory(_NavPlaylist(playlistName));
    setState(() {
      _selection.selectedPlaylistFilter = playlistName;
      _selection.selectedTrackPaths.clear();
    });
    _artist.closeArtist();
    _saveLayoutState();
    _closeSearch();
  }

  void _setDragOverPlaylist(String? playlistName) => setState(() => _selection.dragOverPlaylist = playlistName);

  Future<void> _dropFilesOnPlaylist(String playlistName, List<XFile> files) async {
    _setDragOverPlaylist(null);
    await _addDroppedFilesToPlaylist(playlistName, files);
  }

  void _reorderPlaylists(int oldIndex, int newIndex) => setState(() => _editing.reorderPlaylists(oldIndex, newIndex));

  Widget _buildNavigationRail() => NavigationRailPanel(
        sidebarWidth: _sidebarWidth,
        isCollapsed: _isSidebarCollapsed,
        homeSelected: _selection.selectedPlaylistFilter == null && _selectedIndex == 0,
        onSelectHome: () => _selectFixedView(0),
        explorerSelected: _selection.selectedPlaylistFilter == null && _selectedIndex == 1,
        onSelectExplorer: () => _selectFixedView(1),
        onCreatePlaylist: _showCreatePlaylistDialog,
        playlists: _library.musicPlaylists,
        importingPlaylists: _library.importingPlaylists,
        selectedPlaylistFilter: _selection.selectedPlaylistFilter,
        dragOverPlaylist: _selection.dragOverPlaylist,
        currentQueueSourcePlaylist: _playback.currentQueueSourcePlaylist,
        currentPlayingPath: _playback.currentPlayingPath,
        userPaused: _playback.userPaused,
        loadingQueuePath: _playback.loadingQueuePath,
        onDragEnterPlaylist: _setDragOverPlaylist,
        onDragExitPlaylist: () => _setDragOverPlaylist(null),
        onDropFiles: _dropFilesOnPlaylist,
        onSelectPlaylist: _selectPlaylistFromSidebar,
        onTogglePlayPause: _togglePlayPause,
        onStartQueue: _startQueue,
        onEditPlaylist: _showEditPlaylistDialog,
        onDeletePlaylist: _confirmAndDeletePlaylist,
        onReorderPlaylist: _reorderPlaylists,
      );

  Widget _buildSelectedScreenContent() {
    if (_artistState.openArtistName != null) {
      return _buildArtistView();
    }
    if (_selection.selectedPlaylistFilter != null) {
      return _buildPlaylistDetailView(_selection.selectedPlaylistFilter!);
    }
    return _selectedIndex == 1 ? _buildExplorerView() : _buildHomeView();
  }

  int _mobileTab = 0;
  bool _mobilePlayerOpen = false;
  String? _mobileSearchAddPlaylist;
  List<YtSearchResult>? _mobileAddSuggestions;
  bool _mobileAddSuggestionsLoading = false;
  bool _mobileAddSearchOpen = false;
  final _mobileLibraryKey = GlobalKey<MobileLibraryViewState>();
  final _mobileProfileKey = GlobalKey<ProfileSettingsDialogState>();

  bool get _chartsDetailOpen =>
      _chartsState.openGenreParams != null ||
      _chartsState.openCountryName != null ||
      _chartsState.openReleasePlaylistId != null ||
      _chartsState.showingAllNewReleases;

  bool get _mobileHasBackTarget =>
      _mobilePlayerOpen ||
      _mobileSearchAddPlaylist != null ||
      _artistState.openArtistName != null ||
      _selection.selectedPlaylistFilter != null ||
      _mobileTab != 0;

  void _selectMobileTab(int index) {
    _searchFocusNode.unfocus();
    if (index == 1 && _mobileTab == 1) _charts.closeDetail();
    _artist.closeArtist();
    setState(() {
      _mobileTab = index;
      _selection.selectedPlaylistFilter = null;
      _selection.selectedTrackPaths.clear();
    });
  }

  void _handleMobileBack() {
    if (_mobilePlayerOpen) {
      setState(() => _mobilePlayerOpen = false);
    } else if (_mobileSearchAddPlaylist != null && _mobileAddSearchOpen) {
      _closeMobileAddSearch();
    } else if (_mobileSearchAddPlaylist != null) {
      _closeSearch();
      setState(() => _mobileSearchAddPlaylist = null);
    } else if (_artistState.openArtistName != null) {
      if (_artistState.openReleasePlaylistId != null) {
        _artist.closeReleaseDetail();
      } else {
        _closeSearch();
        _artist.closeArtist();
      }
    } else if (_selection.selectedPlaylistFilter != null) {
      setState(() {
        _selection.selectedPlaylistFilter = null;
        _selection.selectedTrackPaths.clear();
      });
    } else if (_mobileTab == 2 && _mobileLibraryKey.currentState?.handleBack() == true) {
      return;
    } else if (_mobileTab == 3 && _mobileProfileKey.currentState?.hasOpenCategory == true) {
      _mobileProfileKey.currentState!.closeCategory();
    } else if (_mobileTab == 1 && _chartsDetailOpen) {
      _charts.closeDetail();
    } else if (_mobileTab == 1 && _searchQuery.isNotEmpty) {
      _closeSearch();
    } else if (_mobileTab != 0) {
      _selectMobileTab(0);
    }
  }

  void _openMobileQueue() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        final size = MediaQuery.sizeOf(sheetContext);
        return ListenableBuilder(
          listenable: _playback,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QueuePanel(
                width: size.width,
                maxHeight: size.height * 0.6,
                playback: _playback,
                library: _library,
                trackPresenter: _trackPresenter,
                onClose: () => Navigator.of(sheetContext).pop(),
                onJumpToQueueIndex: _jumpToQueueIndex,
                onPlayRecentTrack: (path) => _playbackController.playStandaloneTrack(path),
                onClearCustomQueue: () => _playbackController.clearCustomQueue(),
                onRemoveFromCustomQueue: (index) => _playbackController.removeFromCustomQueue(index),
                onRemoveFromAutomaticQueue: (index) => _playbackController.removeFromAutomaticQueue(index),
                onReorderCustomQueue: _playbackController.reorderCustomQueue,
                onReorderUpcoming: _playbackController.reorderUpcoming,
                onViewArtist: (artist) {
                  Navigator.of(sheetContext).pop();
                  _showArtistPage(artist);
                },
              ),
              ColoredBox(
                color: Color.alphaBlend(AppTheme.paletteOf(context).cardHover, Colors.black),
                child: SizedBox(width: size.width, height: mobileBottomInset(sheetContext)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMobilePlaylistOptions(String playlistName) {
    final data = _library.musicPlaylists[playlistName];
    if (data == null) return;
    final editable = data['isLiked'] != true && data['isLocalFiles'] != true;
    final l10n = AppLocalizations.of(context);
    final palette = AppTheme.paletteOf(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Color.alphaBlend(palette.cardHover, Colors.black),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: mobileBottomInset(sheetContext)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.edit_outlined, color: palette.textPrimary),
              title: Text(l10n.editInfoButtonLabel, style: TextStyle(color: palette.textPrimary)),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _showEditPlaylistDialog(playlistName);
              },
            ),
            if (editable)
              ListTile(
                leading: Icon(Icons.delete_outline, color: palette.textPrimary),
                title: Text(l10n.deleteButton, style: TextStyle(color: palette.textPrimary)),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _confirmAndDeletePlaylist(playlistName);
                },
              ),
          ],
        ),
      ),
    );
  }

  List<String> _allLibraryTrackPaths() {
    final paths = <String>{..._library.musicPaths};
    for (final playlist in _library.musicPlaylists.values) {
      paths.addAll(playlist['tracks'] as List<String>);
    }
    return paths.toList();
  }

  Widget _buildMobileBody() {
    if (_artistState.openArtistName != null) {
      return Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _buildArtistView());
    }
    final playlistName = _selection.selectedPlaylistFilter;
    if (playlistName != null && _library.musicPlaylists.containsKey(playlistName)) {
      return _buildMobilePlaylistView(playlistName);
    }
    switch (_mobileTab) {
      case 1:
        return MobileSearchView(
          controller: _searchController,
          focusNode: _searchFocusNode,
          layerLink: _searchLayerLink,
          query: _searchQuery,
          isSearching: _isSearching,
          results: _searchResults,
          onQueryChanged: _onSearchQueryChanged,
          onClear: _closeSearch,
          resultRowBuilder: _buildSearchResultRow,
          browseContent: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _buildExplorerView()),
        );
      case 2:
        return MobileLibraryView(
          key: _mobileLibraryKey,
          playlists: _library.musicPlaylists,
          importingPlaylists: _library.importingPlaylists,
          trackPaths: _allLibraryTrackPaths(),
          trackPresenter: _trackPresenter,
          currentPlayingPath: _playback.currentPlayingPath,
          onOpenPlaylist: _selectPlaylistFromSidebar,
          onPlaylistOptions: _showMobilePlaylistOptions,
          onPlayTrack: (path) => _playbackController.playStandaloneTrack(path),
          onCreatePlaylist: _showCreatePlaylistDialog,
          onOpenProfile: () => _selectMobileTab(3),
          profileImagePath: _profileImagePath,
        );
      case 3:
        return _buildProfileSettings(key: _mobileProfileKey);
      default:
        return Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _buildHomeView());
    }
  }

  static const _fallbackSuggestionArtists = [
    'The Weeknd',
    'Taylor Swift',
    'Drake',
    'Billie Eilish',
    'Dua Lipa',
    'Bad Bunny',
    'Ed Sheeran',
    'Ariana Grande',
    'Daft Punk',
    'Rihanna',
    'Aya Nakamura',
    'Stromae',
    'Bruno Mars',
    'Coldplay',
    'Kendrick Lamar',
    'SZA',
  ];

  void _openMobileSearchToAdd(String playlistName) {
    setState(() {
      _mobileSearchAddPlaylist = playlistName;
      _mobileAddSearchOpen = false;
    });
    if (_mobileAddSuggestions == null && !_mobileAddSuggestionsLoading) {
      unawaited(_loadMobileAddSuggestions());
    }
  }

  List<String> _suggestionArtists() {
    final counts = <String, int>{};
    for (final metadata in _library.trackMetadata.values) {
      final author = metadata['author'];
      if (author == null || author.isEmpty) continue;
      final names = splitArtistNames(author);
      if (names.isEmpty) continue;
      counts[names.first] = (counts[names.first] ?? 0) + 1;
    }
    final ranked = counts.keys.toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    final artists = (ranked.take(10).toList()..shuffle()).take(6).toList();
    if (artists.length < 3) {
      for (final name in [..._fallbackSuggestionArtists]..shuffle()) {
        if (artists.length >= 6) break;
        if (!artists.contains(name)) artists.add(name);
      }
    }
    return artists;
  }

  Future<void> _loadMobileAddSuggestions() async {
    setState(() => _mobileAddSuggestionsLoading = true);
    final lists = await Future.wait(_suggestionArtists().map(
      (name) => _chartsService.fetchArtistPopularSongs(name).catchError((Object _) => <YtSearchResult>[]),
    ));
    final seen = <String>{};
    final songs = [
      for (final list in lists) ...list.where((song) => seen.add(song.id)),
    ]..shuffle();
    if (!mounted) return;
    setState(() {
      _mobileAddSuggestions = songs;
      _mobileAddSuggestionsLoading = false;
    });
  }

  void _showMobileSortSheet(String playlistName) {
    final l10n = AppLocalizations.of(context);
    final palette = AppTheme.paletteOf(context);
    final accent = AppTheme.of(context).accent;
    final current = _playlistView.sortCriterionFor(playlistName);
    final options = <(String?, String)>[
      (null, l10n.sortByCustomOption),
      for (final entry in sortCriterionLabelsFor(l10n).entries) (entry.key, entry.value),
    ];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Color.alphaBlend(palette.cardHover, Colors.black),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: mobileBottomInset(sheetContext)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: palette.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Text(
                  l10n.sortByMenuTitle,
                  style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              for (final (key, label) in options)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                  title: Text(label, style: TextStyle(color: key == current ? accent : palette.textPrimary, fontSize: 17)),
                  trailing: key == current ? Icon(Icons.check_circle, color: accent) : null,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    setState(() => _applySortSelection(playlistName, key ?? '__default__'));
                  },
                ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: Text(
                      l10n.cancelButton,
                      style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobilePlaylistView(String playlistName) {
    final playlistData = _library.musicPlaylists[playlistName]!;
    final tracks = playlistData['tracks'] as List<String>;
    final displayTracks = _displayTracksForPlaylist(playlistName, tracks);
    final isActivePlaylist = _playback.currentQueueSourcePlaylist == playlistName && _playback.currentPlayingPath != null;
    return MobilePlaylistView(
      playlistName: playlistName,
      tracks: tracks,
      displayTracks: displayTracks,
      playlistImage: playlistData['image'],
      description: playlistData['description'] ?? '',
      isLiked: playlistData['isLiked'] == true,
      isLocalFiles: playlistData['isLocalFiles'] == true,
      isActivePlaylist: isActivePlaylist,
      showDownloadButton: widget.generalSettings.showLocalDownloadButtons,
      library: _library,
      playback: _playback,
      playlistView: _playlistView,
      trackPresenter: _trackPresenter,
      onBack: _handleMobileBack,
      onPlay: () {
        if (isActivePlaylist) {
          _togglePlayPause();
        } else {
          _startQueue(displayTracks, 0, sourcePlaylist: playlistName, shuffleFromStart: true);
        }
      },
      onEdit: () => _showEditPlaylistDialog(playlistName),
      onSearchToAdd: () => _openMobileSearchToAdd(playlistName),
      onSort: () => _showMobileSortSheet(playlistName),
      onAddLocalFiles: () => _addFilesToPlaylist(playlistName, tracks),
      onDownloadAll: (context) => _confirmAndDownloadAllOnlineTracksInPlaylist(context, playlistName),
      onTrackTap: (index) => _onTrackTap(displayTracks, index, sourcePlaylist: playlistName),
      onTrackMenu: (context, position, path) =>
          _showAddToPlaylistMenu(context, position, {path}, removeFromTracks: tracks),
    );
  }

  Widget _buildMobileSearchToPlaylistPage() {
    final playlistName = _mobileSearchAddPlaylist!;
    Widget row(YtSearchResult video) => _buildMobileAddTrackRow(playlistName, video);
    if (_mobileAddSearchOpen) {
      return MobileAddTracksSearchPage(
        controller: _searchController,
        focusNode: _searchFocusNode,
        layerLink: _searchLayerLink,
        query: _searchQuery,
        isSearching: _isSearching,
        results: _searchResults,
        rowBuilder: row,
        onQueryChanged: _onSearchQueryChanged,
        onClear: _closeSearch,
        onBack: _closeMobileAddSearch,
      );
    }
    return MobileSearchToPlaylistPage(
      suggestions: _mobileAddSuggestions,
      suggestionsLoading: _mobileAddSuggestionsLoading,
      rowBuilder: row,
      onOpenSearch: _openMobileAddSearch,
      onClose: () {
        _closeSearch();
        setState(() => _mobileSearchAddPlaylist = null);
      },
    );
  }

  void _openMobileAddSearch() {
    setState(() => _mobileAddSearchOpen = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  void _closeMobileAddSearch() {
    _searchFocusNode.unfocus();
    _closeSearch();
    setState(() => _mobileAddSearchOpen = false);
  }

  Widget _buildMobileAddTrackRow(String playlistName, YtSearchResult video) {
    final onlinePath = 'online:${video.id}';
    final tracks = (_library.musicPlaylists[playlistName]?['tracks'] as List<String>?) ?? const <String>[];
    final likedTracks = (_likedPlaylistEntry?.value['tracks'] as List<String>?) ?? const <String>[];
    final current = _playback.currentPlayingPath;
    final isInPlaylist = tracks.contains(onlinePath);
    return MobileAddTrackRow(
      video: video,
      isInPlaylist: isInPlaylist,
      isLiked: likedTracks.contains(onlinePath),
      isPlaying: current == 'preview:${video.id}' && !_playback.userPaused,
      onTap: () => _playPreview(video),
      onLongPress: () {
        if (!_library.trackMetadata.containsKey(onlinePath)) {
          setState(() => _library.trackMetadata[onlinePath] = metadataMap(video));
        }
        _showAddToPlaylistMenu(context, Offset.zero, {onlinePath});
      },
      onToggleLike: () => _toggleLikeForSearchResult(video),
      onToggleAdd: () {
        if (!_library.trackMetadata.containsKey(onlinePath)) {
          setState(() => _library.trackMetadata[onlinePath] = metadataMap(video));
        }
        final playlistTracks = _library.musicPlaylists[playlistName]!['tracks'] as List<String>;
        _toggleTracksInPlaylist(playlistName, playlistTracks, {onlinePath}, isInPlaylist);
        if (!isInPlaylist) _prefetchFullPlaybackCache(video);
      },
    );
  }

  Widget _buildMobileNowPlayingPage() => MobileNowPlayingPage(
        playback: _playback,
        trackPresenter: _trackPresenter,
        onClose: () => setState(() => _mobilePlayerOpen = false),
        onOpenQueue: _openMobileQueue,
        onOpenTrackMenu: () {
          final path = _playback.currentPlayingPath;
          if (path != null) _showAddToPlaylistMenu(context, Offset.zero, {_libraryKeyForCurrentTrack(path)});
        },
        onOpenAddToPlaylist: () {
          final path = _playback.currentPlayingPath;
          if (path != null) unawaited(_showAddCurrentPreviewToPlaylistMenu(context, path));
        },
        onTogglePlayPause: _togglePlayPause,
        onNext: _playNext,
        onPrevious: _playPrevious,
        onToggleShuffle: _toggleShuffle,
        onCycleRepeat: _cycleRepeatMode,
        onToggleLike: _toggleLikeCurrentTrack,
        onSeek: (position) => unawaited(_audioPlayer.seek(position)),
        onViewArtist: _showArtistPage,
      );

  Widget _buildMobileRoot() {
    final hasTrack = _playback.currentPlayingPath != null;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return PopScope(
      canPop: !_mobileHasBackTarget,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleMobileBack();
      },
      child: Stack(
        children: [
          if (widget.themeState.isGalaxyActive) const Positioned.fill(child: GalaxyBackground()),
          if (widget.themeState.isAuroraActive) const Positioned.fill(child: AuroraBackground()),
          if (widget.themeState.isImageThemeActive)
            Positioned.fill(child: ImageThemeBackground(imagePath: widget.themeState.customThemeImagePath!)),
          Scaffold(
            body: Column(
              children: [
                Expanded(child: SafeArea(bottom: false, child: _buildMobileBody())),
                if (!keyboardOpen) ...[
                  if (hasTrack)
                    ListenableBuilder(
                      listenable: _playback,
                      builder: (context, _) => MobileMiniPlayer(
                        playback: _playback,
                        trackPresenter: _trackPresenter,
                        onOpen: () => setState(() => _mobilePlayerOpen = true),
                        onTogglePlayPause: _togglePlayPause,
                        onToggleLike: _toggleLikeCurrentTrack,
                        onOpenAddToPlaylist: (btnContext) {
                          final path = _playback.currentPlayingPath;
                          if (path != null) unawaited(_showAddCurrentPreviewToPlaylistMenu(btnContext, path));
                        },
                      ),
                    ),
                  MobileBottomNav(index: _mobileTab, onSelect: _selectMobileTab),
                ],
              ],
            ),
          ),
          if (_mobilePlayerOpen && hasTrack)
            Positioned.fill(
              child: ListenableBuilder(
                listenable: _playback,
                builder: (context, _) => _buildMobileNowPlayingPage(),
              ),
            ),
          if (_mobileSearchAddPlaylist != null)
            Positioned.fill(child: _buildMobileSearchToPlaylistPage()),
          if (_toastMessage != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: bottomInset + ((_mobilePlayerOpen || _mobileSearchAddPlaylist != null) ? 24 : 64 + (hasTrack ? 74 : 0) + 16),
              child: IgnorePointer(child: Center(child: _buildAppToast())),
            ),
        ],
      ),
    );
  }

  Widget _buildHomeView() => HomeView(
        library: _library,
        trackPresenter: _trackPresenter,
        onPlayTrack: (path) => _playbackController.playStandaloneTrack(path),
        onOpenPlaylist: _selectPlaylistFromSidebar,
        onViewArtist: _showArtistPage,
      );

  Widget _buildExplorerView() => ExplorerView(
        resultRowBuilder: _buildSearchResultRow,
        chartsState: _chartsState,
        onOpenGenre: _charts.openGenre,
        onOpenCountry: _charts.openCountry,
        onOpenRelease: _charts.openRelease,
        onOpenAllNewReleases: _charts.openAllNewReleases,
        onCloseDetail: _charts.closeDetail,
      );

  void _toggleTrackSelection(String path) {
    setState(() {
      if (_selection.selectedTrackPaths.contains(path)) {
        _selection.selectedTrackPaths.remove(path);
      } else {
        _selection.selectedTrackPaths.add(path);
      }
    });
  }

  void _selectOnlyTrack(String path) => setState(() => _selection.selectedTrackPaths = {path});

  void _clearTrackSelection() => setState(() => _selection.selectedTrackPaths.clear());

  void _setReorderDraggedPath(String? path) => setState(() => _selection.reorderDraggedPath = path);

  Future<void> _addFilesToPlaylist(String playlistName, List<String> tracks) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _audioExtensions.map((e) => e.substring(1)).toList(),
      allowMultiple: true,
    );
    if (result != null && mounted) {
      setState(() {
        for (var file in result.files) {
          if (file.path != null) {
            if (!_library.musicPaths.contains(file.path!)) {
              _library.musicPaths.add(file.path!);
            }
            if (!tracks.contains(file.path!)) {
              tracks.add(file.path!);
            }
          }
        }
        _playback.syncQueueWithPlaylistTracks(playlistName, tracks);
      });
      await _saveMedia();
    }
  }

  Widget _buildPlaylistDetailView(String playlistName) {
    final playlistData = _library.musicPlaylists[playlistName] ?? {'tracks': <String>[], 'image': null, 'description': ''};
    final tracks = playlistData['tracks'] as List<String>;
    final displayTracks = _displayTracksForPlaylist(playlistName, tracks);
    final bool isActivePlaylist = _playback.currentQueueSourcePlaylist == playlistName && _playback.currentPlayingPath != null;
    final bool canReorderTracks = _playlistView.sortCriterionFor(playlistName) == null &&
        _playlistView.searchQueryFor(playlistName).trim().isEmpty;

    return PlaylistDetailView(
      playlistName: playlistName,
      tracks: tracks,
      displayTracks: displayTracks,
      playlistImage: playlistData['image'],
      description: playlistData['description'] ?? '',
      isLiked: playlistData['isLiked'] == true,
      isLocalFiles: playlistData['isLocalFiles'] == true,
      isActivePlaylist: isActivePlaylist,
      canReorderTracks: canReorderTracks,
      library: _library,
      playback: _playback,
      selection: _selection,
      playlistView: _playlistView,
      trackPresenter: _trackPresenter,
      sortControlLayerLink: _sortControlLayerLink,
      trackDurationLabel: _trackDurationLabel,
      onToggleTrackSelection: _toggleTrackSelection,
      onSelectSingleTrack: _selectOnlyTrack,
      onClearSelection: _clearTrackSelection,
      onTrackTap: _onTrackTap,
      onShowAddToPlaylistMenu: _showAddToPlaylistMenu,
      onReorderStart: _setReorderDraggedPath,
      onReorderEnd: () => _setReorderDraggedPath(null),
      onReorder: (oldIndex, newIndex) => _handleTrackReorder(playlistName, tracks, oldIndex, newIndex),
      onEditPlaylist: ({bool autoPickImage = false}) =>
          _showEditPlaylistDialog(playlistName, autoPickImage: autoPickImage),
      onTogglePlayPause: _togglePlayPause,
      onStartQueue: _startQueue,
      onAddFilesToPlaylist: () => _addFilesToPlaylist(playlistName, tracks),
      onDownloadAllOnlineTracks: (context) => _confirmAndDownloadAllOnlineTracksInPlaylist(context, playlistName),
      showDownloadButton: widget.generalSettings.showLocalDownloadButtons,
      onViewArtist: _showArtistPage,
      onPlaylistSearchFocusChange: (hasFocus) => _playlistSearchFieldFocused = hasFocus,
      onToggleSortMenu: () {
        if (_sortMenuOverlayEntry != null) {
          _removeSortMenuOverlay();
        } else {
          _showSortMenu(playlistName);
        }
      },
    );
  }

  void _maybeAutoResumeLastSession() {
    if (!widget.generalSettings.autoResumeOnStartup) return;
    final queue = widget.generalSettings.lastSessionQueue;
    final index = widget.generalSettings.lastSessionQueueIndex;
    if (queue.isEmpty || index < 0 || index >= queue.length) return;
    unawaited(_playbackController.startQueue(
      queue,
      index,
      sourcePlaylist: widget.generalSettings.lastSessionSourcePlaylist,
      autoPlay: false,
    ));
  }

  ProfileSettingsDialog _buildProfileSettings({Key? key}) => ProfileSettingsDialog(
        key: key,
        themeState: widget.themeState,
        generalSettings: widget.generalSettings,
        initialName: _profileName,
        initialImagePath: _profileImagePath,
        initialDownloadDir: _customDownloadDir,
        initialCacheDir: _customCacheDir,
        defaultCacheBase: _defaultCacheBase,
        onComputeStorageUsage: _downloads.storageUsage,
        onClearCache: _downloads.clearOnlineCache,
        onSave: (name, imagePath, downloadDir, cacheDir) async {
          setState(() {
            _profileName = name;
            _profileImagePath = imagePath;
            _customDownloadDir = downloadDir;
            _customCacheDir = cacheDir;
          });
          await _saveProfileSettings();
        },
        onDataImported: () async {
          await _loadSavedMedia();
          unawaited(_restoreMissingAndroidDownloads());
          if (!mounted) return;
          widget.themeState.reloadFromPrefs();
          widget.generalSettings.reloadFromPrefs();
        },
      );

  void _showProfileSettingsDialog() {
    showDialog(context: context, builder: (context) => _buildProfileSettings());
  }

  Future<void> _saveEditedPlaylist(
    String playlistName, {
    required String newName,
    required String? imagePath,
    required String description,
  }) async {
    setState(() {
      if (newName != playlistName) {
        final rebuilt = <String, Map<String, dynamic>>{};
        for (final entry in _library.musicPlaylists.entries) {
          if (entry.key == playlistName) {
            rebuilt[newName] = {
              'tracks': entry.value['tracks'],
              'image': imagePath,
              'description': description,
              'isLiked': entry.value['isLiked'] ?? false,
              'isLocalFiles': entry.value['isLocalFiles'] ?? false,
            };
          } else {
            rebuilt[entry.key] = entry.value;
          }
        }
        _library.musicPlaylists = rebuilt;
        final createdDate = _library.playlistCreatedDates.remove(playlistName);
        if (createdDate != null) _library.playlistCreatedDates[newName] = createdDate;
        final playCount = _library.playlistPlayCounts.remove(playlistName);
        if (playCount != null) _library.playlistPlayCounts[newName] = playCount;
        _selection.selectedPlaylistFilter = newName;
        if (_playback.currentQueueSourcePlaylist == playlistName) {
          _playback.currentQueueSourcePlaylist = newName;
        }
      } else {
        _library.musicPlaylists[playlistName]!['image'] = imagePath;
        _library.musicPlaylists[playlistName]!['description'] = description;
      }
    });
    await _saveMedia();
  }

  void _showEditPlaylistDialog(String playlistName, {bool autoPickImage = false}) {
    final playlistData = _library.musicPlaylists[playlistName]!;
    if (isMobile) {
      showMobileEditPlaylistSheet(
        context,
        playlistName: playlistName,
        initialImage: playlistData['image'],
        initialDescription: playlistData['description'] ?? '',
        autoPickImage: autoPickImage,
        isNameTaken: (newName) => newName != playlistName && _library.musicPlaylists.containsKey(newName),
        onSave: (newName, imagePath, description) => _saveEditedPlaylist(
          playlistName,
          newName: newName,
          imagePath: imagePath,
          description: description,
        ),
        onDelete: () => _confirmAndDeletePlaylist(playlistName),
        canDelete: playlistData['isLiked'] != true && playlistData['isLocalFiles'] != true,
      );
      return;
    }
    showDialog(
      context: context,
      builder: (context) => EditPlaylistDialog(
        playlistName: playlistName,
        initialImage: playlistData['image'],
        initialDescription: playlistData['description'] ?? '',
        autoPickImage: autoPickImage,
        isNameTaken: (newName) => newName != playlistName && _library.musicPlaylists.containsKey(newName),
        onSave: (newName, imagePath, description) => _saveEditedPlaylist(
          playlistName,
          newName: newName,
          imagePath: imagePath,
          description: description,
        ),
      ),
    );
  }

  Future<void> _createPlaylist(String name, {Set<String>? pathsToAdd}) async {
    setState(() {
      _library.musicPlaylists[name] = {
        'tracks': <String>[...?pathsToAdd],
        'image': null,
        'description': '',
      };
      _library.playlistCreatedDates[name] = DateTime.now().toIso8601String();
    });
    await _saveMedia();
  }

  void _showCreatePlaylistDialog({Set<String>? pathsToAdd}) {
    showDialog(
      context: context,
      builder: (context) => CreatePlaylistDialog(
        library: _library,
        onCreate: (name) => _createPlaylist(name, pathsToAdd: pathsToAdd),
        onImportUrl: _importPlaylistFromUrl,
      ),
    );
  }

  void _importPlaylistFromUrl(String url) => _playlistImport.importFromUrl(url);

  String _libraryKeyForCurrentTrack(String currentPath) {
    final key = _likeKeyForPath(currentPath);
    final preview = _playback.previewVideo;
    if (isPreviewTrack(currentPath) && preview != null) {
      setState(() {
        _library.trackMetadata[key] = metadataMap(preview);
      });
    }
    return key;
  }

  Future<void> _showAddCurrentPreviewToPlaylistMenu(BuildContext btnContext, String currentPath) async {
    final key = _libraryKeyForCurrentTrack(currentPath);
    if (isMobile) {
      await showMobileTrackActionsSheet(
        btnContext,
        path: key,
        trackPresenter: _trackPresenter,
        playlists: _library.musicPlaylists,
        startAtPlaylistPicker: true,
        onCreatePlaylist: () => _showCreatePlaylistDialog(pathsToAdd: {key}),
        onToggleTracks: (playlistName, playlistTracks, isInPlaylist) =>
            _toggleTracksInPlaylist(playlistName, playlistTracks, {key}, isInPlaylist),
      );
      return;
    }
    final box = btnContext.findRenderObject() as RenderBox;
    final position = box.localToGlobal(box.size.center(Offset.zero));
    await _showDirectPlaylistPickerMenu(context, position, key);
  }

  void _setAudioBarHeight(double height) {
    if (mounted) setState(() => _audioBarHeight = height);
  }

  Widget _buildExpandedNowPlayingPanel() => ExpandedNowPlayingPanel(
        currentPlayingPath: _playback.currentPlayingPath,
        trackPresenter: _trackPresenter,
      );

  Widget _buildQueuePanel() => QueuePanel(
        playback: _playback,
        library: _library,
        trackPresenter: _trackPresenter,
        onClose: () => setState(() => _queuePanelOpen = false),
        onJumpToQueueIndex: _jumpToQueueIndex,
        onPlayRecentTrack: (path) => _playbackController.playStandaloneTrack(path),
        onClearCustomQueue: () => _playbackController.clearCustomQueue(),
        onRemoveFromCustomQueue: (index) => _playbackController.removeFromCustomQueue(index),
        onRemoveFromAutomaticQueue: (index) => _playbackController.removeFromAutomaticQueue(index),
        onReorderCustomQueue: _playbackController.reorderCustomQueue,
        onReorderUpcoming: _playbackController.reorderUpcoming,
        onViewArtist: _showArtistPage,
      );

  Future<void> _jumpToQueueIndex(int index) => _playbackController.jumpToAutomaticQueueIndex(index);

  Widget _buildSpotifyStyleAudioBar() => ListenableBuilder(
        listenable: _playback,
        builder: (context, child) => _buildSpotifyStyleAudioBarContent(),
      );

  Widget _buildSpotifyStyleAudioBarContent() => NowPlayingBar(
        playback: _playback,
        selection: _selection,
        trackPresenter: _trackPresenter,
        audioPlayer: _audioPlayer,
        audioBarKey: _audioBarKey,
        audioBarHeight: _audioBarHeight,
        nowPlayingExpanded: _nowPlayingExpanded,
        queuePanelOpen: _queuePanelOpen,
        downloadingTrackPath: _downloadingTrackPath,
        bulkDownloadInProgress: _bulkDownloadInProgress,
        showDownloadButton: widget.generalSettings.showLocalDownloadButtons,
        onHeightMeasured: _setAudioBarHeight,
        onToggleExpanded: () => setState(() => _nowPlayingExpanded = !_nowPlayingExpanded),
        onToggleQueuePanel: () => setState(() => _queuePanelOpen = !_queuePanelOpen),
        onShowAddCurrentToPlaylistMenu: _showAddCurrentPreviewToPlaylistMenu,
        onViewArtist: _showArtistPage,
        onToggleLikeCurrentTrack: _toggleLikeCurrentTrack,
        onToggleShuffle: _toggleShuffle,
        onPlayPrevious: _playPrevious,
        onTogglePlayPause: _togglePlayPause,
        onPlayNext: _playNext,
        onCycleRepeatMode: _cycleRepeatMode,
        onDownloadCurrentTrack: _downloadCurrentTrackToLibrary,
        onToggleMute: _toggleMute,
        onSetVolume: _setVolume,
      );

}
