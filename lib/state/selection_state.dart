import 'package:flutter/foundation.dart';
import '../models/playlist_undo_entry.dart';

class SelectionState extends ChangeNotifier {
  String? selectedPlaylistFilter;

  String? dragOverPlaylist;

  Set<String> selectedTrackPaths = {};

  String? reorderDraggedPath;

  List<String>? trackClipboard;

  final List<PlaylistUndoEntry> undoStack = [];
  final List<PlaylistUndoEntry> redoStack = [];
}
