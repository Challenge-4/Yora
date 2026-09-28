import 'package:flutter/foundation.dart';

class LibraryState extends ChangeNotifier {
  final Map<String, String> trackAddedDates = {};

  final Map<String, String> trackLastPlayedDates = {};

  final Map<String, String> playlistCreatedDates = {};

  final Map<String, int> playlistPlayCounts = {};

  final Set<String> importingPlaylists = {};

  final Set<String> cachingTracks = {};

  final Map<String, Map<String, String>> trackMetadata = {};

  final Map<String, Duration> trackDurations = {};

  final Set<String> durationProbeInFlight = {};

  final Set<String> trackMetadataCompletedOrFailed = {};
  final Set<String> trackMetadataCompletionInFlight = {};

  final List<String> musicPaths = [];

  Map<String, Map<String, dynamic>> musicPlaylists = {
    'Titres likés': {'tracks': <String>[], 'image': null, 'description': '', 'isLiked': true},
    'Fichiers locaux': {'tracks': <String>[], 'image': null, 'description': '', 'isLocalFiles': true},
  };
}
