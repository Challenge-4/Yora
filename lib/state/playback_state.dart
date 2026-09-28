import 'package:flutter/foundation.dart';
import '../models/repeat_mode.dart';
import '../services/yt_dlp_service.dart';

class PlaybackState extends ChangeNotifier {
  String? currentPlayingPath;
  bool isPlaying = false;

  bool userPaused = false;

  Duration duration = Duration.zero;
  Duration position = Duration.zero;

  void setPosition(Duration newPosition) {
    position = newPosition;
    notifyListeners();
  }

  void notifyChanged() => notifyListeners();

  List<String> queue = [];
  int queueIndex = -1;
  bool shuffle = false;
  RepeatMode repeatMode = RepeatMode.off;
  List<int> shuffleIndices = [];
  int shufflePos = -1;

  List<String> customQueue = [];

  double volume = 50.0;
  double? volumeBeforeMute;

  String? currentQueueSourcePlaylist;

  YtSearchResult? previewVideo;
  String? previewTempPath;

  bool previewClaimed = false;

  String? loadingPreviewId;

  int previewRequestId = 0;

  String? loadingQueuePath;

  void generateShuffleOrder({bool keepCurrent = true}) {
    final indices = List<int>.generate(queue.length, (i) => i);
    indices.shuffle();
    if (keepCurrent && queueIndex >= 0) {
      indices.remove(queueIndex);
      indices.insert(0, queueIndex);
    }
    shuffleIndices = indices;
    shufflePos = 0;
  }

  void toggleShuffle() {
    shuffle = !shuffle;
    if (shuffle && queue.isNotEmpty) generateShuffleOrder(keepCurrent: true);
  }

  void syncQueueWithPlaylistTracks(String playlistName, List<String> updatedTracks) {
    if (currentQueueSourcePlaylist != playlistName) return;
    final currentPath = queueIndex >= 0 && queueIndex < queue.length ? queue[queueIndex] : null;
    queue = List<String>.from(updatedTracks);
    if (queue.isEmpty) {
      queueIndex = -1;
    } else {
      final newIndex = currentPath != null ? queue.indexOf(currentPath) : -1;
      queueIndex = newIndex >= 0 ? newIndex : 0;
    }
    if (shuffle && queue.isNotEmpty) generateShuffleOrder(keepCurrent: true);
  }

  void cycleRepeatMode() {
    repeatMode = switch (repeatMode) {
      RepeatMode.off => RepeatMode.all,
      RepeatMode.all => RepeatMode.one,
      RepeatMode.one => RepeatMode.off,
    };
  }
}
