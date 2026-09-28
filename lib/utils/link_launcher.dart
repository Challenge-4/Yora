import 'dart:io';
import 'package:flutter/foundation.dart';

String _openCommand() {
  if (Platform.isWindows) return 'explorer';
  if (Platform.isMacOS) return 'open';
  return 'xdg-open';
}

Future<void> openLink(String url) async {
  try {
    await Process.run(_openCommand(), [url]);
  } catch (e) {
    debugPrint('Impossible d\'ouvrir le lien : $e');
  }
}
