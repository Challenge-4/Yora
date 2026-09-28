import 'package:flutter/foundation.dart';

class PlaylistViewState extends ChangeNotifier {
  final Map<String, String?> _sortCriterion = {};
  final Map<String, bool> _sortAscending = {};
  final Map<String, String> _searchQuery = {};
  final Set<String> _searchActive = {};

  String? sortCriterionFor(String playlistName) => _sortCriterion[playlistName];
  bool sortAscendingFor(String playlistName) => _sortAscending[playlistName] ?? true;
  String searchQueryFor(String playlistName) => _searchQuery[playlistName] ?? '';
  bool isSearchActiveFor(String playlistName) => _searchActive.contains(playlistName);

  void handleColumnSortTap(String playlistName, String? criterion) {
    if (criterion == null) {
      _sortCriterion[playlistName] = null;
      _sortAscending.remove(playlistName);
    } else if (_sortCriterion[playlistName] == criterion) {
      if (_sortAscending[playlistName] ?? true) {
        _sortAscending[playlistName] = false;
      } else {
        _sortCriterion[playlistName] = null;
        _sortAscending.remove(playlistName);
      }
    } else {
      _sortCriterion[playlistName] = criterion;
      _sortAscending[playlistName] = true;
    }
    notifyListeners();
  }

  void applySortSelection(String playlistName, String? selected) {
    if (selected == null) return;
    final isReset = selected == '__reset__' || selected == '__default__';
    _sortCriterion[playlistName] = isReset ? null : selected;
    if (isReset) {
      _sortAscending.remove(playlistName);
    } else {
      _sortAscending[playlistName] = true;
    }
    notifyListeners();
  }

  void setSearchQuery(String playlistName, String query) {
    _searchQuery[playlistName] = query;
    notifyListeners();
  }

  void openSearch(String playlistName) {
    _searchActive.add(playlistName);
    notifyListeners();
  }

  void closeSearch(String playlistName) {
    _searchActive.remove(playlistName);
    _searchQuery.remove(playlistName);
    notifyListeners();
  }

  void toggleSearch(String playlistName) {
    if (_searchActive.contains(playlistName)) {
      closeSearch(playlistName);
    } else {
      openSearch(playlistName);
    }
  }

  void resetFor(String playlistName) {
    _sortCriterion.remove(playlistName);
    _sortAscending.remove(playlistName);
    _searchQuery.remove(playlistName);
    _searchActive.remove(playlistName);
    notifyListeners();
  }
}
