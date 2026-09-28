import 'dart:io';
import 'package:flutter/foundation.dart';

String _openCommand() {
  if (Platform.isWindows) return 'explorer';
  if (Platform.isMacOS) return 'open';
  return 'xdg-open';
}

Future<void> openFolder(String path) async {
  final dir = Directory(path);
  try {
    if (!await dir.exists()) await dir.create(recursive: true);
    await Process.run(_openCommand(), [dir.path]);
  } catch (e) {
    debugPrint('Impossible d\'ouvrir le dossier : $e');
  }
}
