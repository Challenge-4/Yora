import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

String _openCommand() {
  if (Platform.isWindows) return 'explorer';
  if (Platform.isMacOS) return 'open';
  return 'xdg-open';
}

Future<void> openLink(String url) async {
  try {
    if (Platform.isAndroid) {
      await const MethodChannel('yora/ytdlp').invokeMethod('openUrl', {'url': url});
      return;
    }
    if (Platform.isIOS) {
      await const MethodChannel('yora/ios').invokeMethod('openUrl', url);
      return;
    }
    await Process.run(_openCommand(), [url]);
  } catch (e) {
    debugPrint('Impossible d\'ouvrir le lien : $e');
  }
}
