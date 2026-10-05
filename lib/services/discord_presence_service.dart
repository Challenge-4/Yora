import 'dart:async';
import 'package:dart_discord_presence/dart_discord_presence.dart';
import 'package:flutter/foundation.dart';
import '../api_keys.dart';

class DiscordPresenceService {
  DiscordRPC? _rpc;
  bool _connecting = false;

  static const _retryInterval = Duration(seconds: 30);
  Timer? _retryTimer;
  bool _hasLoggedFailure = false;

  bool get isConnected => _rpc?.isConnected ?? false;

  Future<void> connect() async {
    if (discordApplicationId.isEmpty || !DiscordRPC.isAvailable) return;
    if (_rpc != null || _connecting) return;
    _connecting = true;
    try {
      final rpc = DiscordRPC();
      await rpc.initialize(discordApplicationId);
      _rpc = rpc;
      _hasLoggedFailure = false;
      _retryTimer?.cancel();
      _retryTimer = null;
    } catch (e) {
      if (!_hasLoggedFailure) {
        _hasLoggedFailure = true;
        debugPrint('Discord Rich Presence : connexion impossible ($e) — nouvelle tentative toutes les ${_retryInterval.inSeconds}s tant que Discord reste injoignable.');
      }
      _retryTimer ??= Timer.periodic(_retryInterval, (_) => connect());
    } finally {
      _connecting = false;
    }
  }

  Future<void> disconnect() async {
    _retryTimer?.cancel();
    _retryTimer = null;
    _hasLoggedFailure = false;
    final rpc = _rpc;
    _rpc = null;
    if (rpc == null) return;
    try {
      await rpc.dispose();
    } catch (_) {}
  }

  Future<void> updateNowPlaying({
    required String title,
    required String artist,
    String? thumbnailUrl,
    required Duration position,
    required Duration duration,
    required bool isPaused,
  }) async {
    final rpc = _rpc;
    if (rpc == null || !rpc.isConnected) return;
    final largeAsset = thumbnailUrl != null && thumbnailUrl.isNotEmpty ? DiscordAsset.fromUrl(thumbnailUrl) : null;
    final now = DateTime.now();
    final timestamps = (!isPaused && duration > Duration.zero)
        ? DiscordTimestamps.range(now.subtract(position), now.subtract(position).add(duration))
        : null;
    try {
      await rpc.setPresence(DiscordPresence(
        type: DiscordActivityType.listening,
        details: _clamp(title),
        state: isPaused ? _clamp('$artist (paused)') : _clamp(artist),
        timestamps: timestamps,
        largeAsset: largeAsset,
      ));
    } catch (e) {
      debugPrint('Discord Rich Presence : mise à jour impossible ($e)');
    }
  }

  Future<void> clear() async {
    final rpc = _rpc;
    if (rpc == null || !rpc.isConnected) return;
    try {
      await rpc.clearPresence();
    } catch (_) {}
  }

  String _clamp(String value) => value.length > 128 ? value.substring(0, 128) : value;
}
