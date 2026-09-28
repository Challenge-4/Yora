import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/repeat_mode.dart';

const String _kAutoResumeOnStartupPrefsKey = 'autoResumeOnStartup';
const String _kMinimizeToTrayOnClosePrefsKey = 'minimizeToTrayOnClose';
const String _kTrayHintShownPrefsKey = 'trayHintShown';
const String _kCrossfadeEnabledPrefsKey = 'crossfadeEnabled';
const String _kCrossfadeDurationSecondsPrefsKey = 'crossfadeDurationSeconds';
const String _kSmoothPlaylistTransitionsPrefsKey = 'smoothPlaylistTransitions';
const String _kDiscordRichPresenceEnabledPrefsKey = 'discordRichPresenceEnabled';
const String _kShowLocalDownloadButtonsPrefsKey = 'showLocalDownloadButtons';
const String _kDownloadOnWifiOnlyPrefsKey = 'downloadOnWifiOnly';
const String _kLastDataExportAtPrefsKey = 'lastDataExportAt';
const String _kLanguageCodePrefsKey = 'languageCode';
const String _kLastSessionPathPrefsKey = 'lastSessionPath';
const String _kLastSessionQueuePrefsKey = 'lastSessionQueue';
const String _kLastSessionQueueIndexPrefsKey = 'lastSessionQueueIndex';
const String _kLastSessionSourcePlaylistPrefsKey = 'lastSessionSourcePlaylist';
const String _kShuffleEnabledPrefsKey = 'shuffleEnabled';
const String _kRepeatModePrefsKey = 'repeatMode';

class GeneralSettingsState extends ChangeNotifier {
  GeneralSettingsState._(
    this._prefs, {
    required this._autoResumeOnStartup,
    required this._minimizeToTrayOnClose,
    required this._trayHintShown,
    required this._crossfadeEnabled,
    required this._crossfadeDurationSeconds,
    required this._smoothPlaylistTransitions,
    required this._discordRichPresenceEnabled,
    required this._showLocalDownloadButtons,
    required this._downloadOnWifiOnly,
    required this._lastDataExportAt,
    required this._languageCode,
    required this._lastSessionPath,
    required this._lastSessionQueue,
    required this._lastSessionQueueIndex,
    required this._lastSessionSourcePlaylist,
    required this._shuffleEnabled,
    required this._repeatMode,
  });

  factory GeneralSettingsState.load(SharedPreferences prefs) {
    var queue = const <String>[];
    final rawQueue = prefs.getString(_kLastSessionQueuePrefsKey);
    if (rawQueue != null) {
      try {
        queue = (jsonDecode(rawQueue) as List).cast<String>();
      } catch (_) {
        queue = const [];
      }
    }
    return GeneralSettingsState._(
      prefs,
      autoResumeOnStartup: prefs.getBool(_kAutoResumeOnStartupPrefsKey) ?? false,
      minimizeToTrayOnClose: prefs.getBool(_kMinimizeToTrayOnClosePrefsKey) ?? false,
      trayHintShown: prefs.getBool(_kTrayHintShownPrefsKey) ?? false,
      crossfadeEnabled: prefs.getBool(_kCrossfadeEnabledPrefsKey) ?? false,
      crossfadeDurationSeconds: prefs.getDouble(_kCrossfadeDurationSecondsPrefsKey) ?? 4.0,
      smoothPlaylistTransitions: prefs.getBool(_kSmoothPlaylistTransitionsPrefsKey) ?? false,
      discordRichPresenceEnabled: prefs.getBool(_kDiscordRichPresenceEnabledPrefsKey) ?? true,
      showLocalDownloadButtons: prefs.getBool(_kShowLocalDownloadButtonsPrefsKey) ?? false,
      downloadOnWifiOnly: prefs.getBool(_kDownloadOnWifiOnlyPrefsKey) ?? false,
      lastDataExportAt: DateTime.tryParse(prefs.getString(_kLastDataExportAtPrefsKey) ?? ''),
      languageCode: prefs.getString(_kLanguageCodePrefsKey),
      lastSessionPath: prefs.getString(_kLastSessionPathPrefsKey),
      lastSessionQueue: queue,
      lastSessionQueueIndex: prefs.getInt(_kLastSessionQueueIndexPrefsKey) ?? -1,
      lastSessionSourcePlaylist: prefs.getString(_kLastSessionSourcePlaylistPrefsKey),
      shuffleEnabled: prefs.getBool(_kShuffleEnabledPrefsKey) ?? false,
      repeatMode: RepeatMode.values.firstWhere(
        (v) => v.name == prefs.getString(_kRepeatModePrefsKey),
        orElse: () => RepeatMode.off,
      ),
    );
  }

  final SharedPreferences _prefs;

  void reloadFromPrefs() {
    var queue = const <String>[];
    final rawQueue = _prefs.getString(_kLastSessionQueuePrefsKey);
    if (rawQueue != null) {
      try {
        queue = (jsonDecode(rawQueue) as List).cast<String>();
      } catch (_) {
        queue = const [];
      }
    }
    _autoResumeOnStartup = _prefs.getBool(_kAutoResumeOnStartupPrefsKey) ?? false;
    _minimizeToTrayOnClose = _prefs.getBool(_kMinimizeToTrayOnClosePrefsKey) ?? false;
    _trayHintShown = _prefs.getBool(_kTrayHintShownPrefsKey) ?? false;
    _crossfadeEnabled = _prefs.getBool(_kCrossfadeEnabledPrefsKey) ?? false;
    _crossfadeDurationSeconds = _prefs.getDouble(_kCrossfadeDurationSecondsPrefsKey) ?? 4.0;
    _smoothPlaylistTransitions = _prefs.getBool(_kSmoothPlaylistTransitionsPrefsKey) ?? false;
    _discordRichPresenceEnabled = _prefs.getBool(_kDiscordRichPresenceEnabledPrefsKey) ?? true;
    _showLocalDownloadButtons = _prefs.getBool(_kShowLocalDownloadButtonsPrefsKey) ?? false;
    _downloadOnWifiOnly = _prefs.getBool(_kDownloadOnWifiOnlyPrefsKey) ?? false;
    _lastDataExportAt = DateTime.tryParse(_prefs.getString(_kLastDataExportAtPrefsKey) ?? '');
    _languageCode = _prefs.getString(_kLanguageCodePrefsKey);
    _lastSessionPath = _prefs.getString(_kLastSessionPathPrefsKey);
    _lastSessionQueue = queue;
    _lastSessionQueueIndex = _prefs.getInt(_kLastSessionQueueIndexPrefsKey) ?? -1;
    _lastSessionSourcePlaylist = _prefs.getString(_kLastSessionSourcePlaylistPrefsKey);
    _shuffleEnabled = _prefs.getBool(_kShuffleEnabledPrefsKey) ?? false;
    _repeatMode = RepeatMode.values.firstWhere(
      (v) => v.name == _prefs.getString(_kRepeatModePrefsKey),
      orElse: () => RepeatMode.off,
    );
    notifyListeners();
  }

  bool _autoResumeOnStartup;
  bool get autoResumeOnStartup => _autoResumeOnStartup;
  set autoResumeOnStartup(bool value) {
    if (_autoResumeOnStartup == value) return;
    _autoResumeOnStartup = value;
    notifyListeners();
    unawaited(_prefs.setBool(_kAutoResumeOnStartupPrefsKey, value));
  }

  bool _minimizeToTrayOnClose;
  bool get minimizeToTrayOnClose => _minimizeToTrayOnClose;
  set minimizeToTrayOnClose(bool value) {
    if (_minimizeToTrayOnClose == value) return;
    _minimizeToTrayOnClose = value;
    notifyListeners();
    unawaited(_prefs.setBool(_kMinimizeToTrayOnClosePrefsKey, value));
  }

  bool _crossfadeEnabled;
  bool get crossfadeEnabled => _crossfadeEnabled;
  set crossfadeEnabled(bool value) {
    if (_crossfadeEnabled == value) return;
    _crossfadeEnabled = value;
    notifyListeners();
    unawaited(_prefs.setBool(_kCrossfadeEnabledPrefsKey, value));
  }

  double _crossfadeDurationSeconds;
  double get crossfadeDurationSeconds => _crossfadeDurationSeconds;
  set crossfadeDurationSeconds(double value) {
    if (_crossfadeDurationSeconds == value) return;
    _crossfadeDurationSeconds = value;
    notifyListeners();
    unawaited(_prefs.setDouble(_kCrossfadeDurationSecondsPrefsKey, value));
  }

  bool _shuffleEnabled;
  bool get shuffleEnabled => _shuffleEnabled;
  set shuffleEnabled(bool value) {
    if (_shuffleEnabled == value) return;
    _shuffleEnabled = value;
    unawaited(_prefs.setBool(_kShuffleEnabledPrefsKey, value));
  }

  RepeatMode _repeatMode;
  RepeatMode get repeatMode => _repeatMode;
  set repeatMode(RepeatMode value) {
    if (_repeatMode == value) return;
    _repeatMode = value;
    unawaited(_prefs.setString(_kRepeatModePrefsKey, value.name));
  }

  bool _smoothPlaylistTransitions;
  bool get smoothPlaylistTransitions => _smoothPlaylistTransitions;
  set smoothPlaylistTransitions(bool value) {
    if (_smoothPlaylistTransitions == value) return;
    _smoothPlaylistTransitions = value;
    notifyListeners();
    unawaited(_prefs.setBool(_kSmoothPlaylistTransitionsPrefsKey, value));
  }

  bool _discordRichPresenceEnabled;
  bool get discordRichPresenceEnabled => _discordRichPresenceEnabled;
  set discordRichPresenceEnabled(bool value) {
    if (_discordRichPresenceEnabled == value) return;
    _discordRichPresenceEnabled = value;
    notifyListeners();
    unawaited(_prefs.setBool(_kDiscordRichPresenceEnabledPrefsKey, value));
  }

  bool _showLocalDownloadButtons;
  bool get showLocalDownloadButtons => _showLocalDownloadButtons;
  set showLocalDownloadButtons(bool value) {
    if (_showLocalDownloadButtons == value) return;
    _showLocalDownloadButtons = value;
    notifyListeners();
    unawaited(_prefs.setBool(_kShowLocalDownloadButtonsPrefsKey, value));
  }

  bool _downloadOnWifiOnly;
  bool get downloadOnWifiOnly => _downloadOnWifiOnly;
  set downloadOnWifiOnly(bool value) {
    if (_downloadOnWifiOnly == value) return;
    _downloadOnWifiOnly = value;
    notifyListeners();
    unawaited(_prefs.setBool(_kDownloadOnWifiOnlyPrefsKey, value));
  }

  DateTime? _lastDataExportAt;
  DateTime? get lastDataExportAt => _lastDataExportAt;
  void markDataExported() {
    _lastDataExportAt = DateTime.now();
    notifyListeners();
    unawaited(_prefs.setString(_kLastDataExportAtPrefsKey, _lastDataExportAt!.toIso8601String()));
  }

  String? _languageCode;
  String? get languageCode => _languageCode;
  set languageCode(String? value) {
    if (_languageCode == value) return;
    _languageCode = value;
    notifyListeners();
    if (value == null) {
      unawaited(_prefs.remove(_kLanguageCodePrefsKey));
    } else {
      unawaited(_prefs.setString(_kLanguageCodePrefsKey, value));
    }
  }

  bool _launchAtStartupEnabled = false;
  bool get launchAtStartupEnabled => _launchAtStartupEnabled;

  void syncLaunchAtStartupEnabled(bool enabled) {
    if (_launchAtStartupEnabled == enabled) return;
    _launchAtStartupEnabled = enabled;
    notifyListeners();
  }

  Future<void> setLaunchAtStartupEnabled(bool value) async {
    if (value) {
      await launchAtStartup.enable();
    } else {
      await launchAtStartup.disable();
    }
    _launchAtStartupEnabled = value;
    notifyListeners();
  }

  bool _trayHintShown;
  bool get trayHintShown => _trayHintShown;
  void markTrayHintShown() {
    if (_trayHintShown) return;
    _trayHintShown = true;
    unawaited(_prefs.setBool(_kTrayHintShownPrefsKey, true));
  }

  String? _lastSessionPath;
  List<String> _lastSessionQueue;
  int _lastSessionQueueIndex;
  String? _lastSessionSourcePlaylist;

  String? get lastSessionPath => _lastSessionPath;
  List<String> get lastSessionQueue => _lastSessionQueue;
  int get lastSessionQueueIndex => _lastSessionQueueIndex;
  String? get lastSessionSourcePlaylist => _lastSessionSourcePlaylist;

  void recordSession({
    required String path,
    required List<String> queue,
    required int queueIndex,
    String? sourcePlaylist,
  }) {
    _lastSessionPath = path;
    _lastSessionQueue = queue;
    _lastSessionQueueIndex = queueIndex;
    _lastSessionSourcePlaylist = sourcePlaylist;
    unawaited(_prefs.setString(_kLastSessionPathPrefsKey, path));
    unawaited(_prefs.setString(_kLastSessionQueuePrefsKey, jsonEncode(queue)));
    unawaited(_prefs.setInt(_kLastSessionQueueIndexPrefsKey, queueIndex));
    if (sourcePlaylist != null) {
      unawaited(_prefs.setString(_kLastSessionSourcePlaylistPrefsKey, sourcePlaylist));
    } else {
      unawaited(_prefs.remove(_kLastSessionSourcePlaylistPrefsKey));
    }
  }
}
