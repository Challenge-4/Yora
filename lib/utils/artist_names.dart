List<String> splitArtistNames(String raw) =>
    raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
