sealed class PlaylistUndoEntry {
  const PlaylistUndoEntry();
}

final class TrackListSnapshot extends PlaylistUndoEntry {
  final String playlistName;
  final List<String> tracks;
  const TrackListSnapshot(this.playlistName, this.tracks);
}

final class PlaylistDeletionSnapshot extends PlaylistUndoEntry {
  final String playlistName;
  final Map<String, dynamic> data;
  final int index;
  const PlaylistDeletionSnapshot(this.playlistName, this.data, this.index);
}
