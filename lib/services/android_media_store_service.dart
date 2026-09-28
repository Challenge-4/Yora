import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AndroidMediaStoreService {
  static const _channel = MethodChannel('yora/ytdlp');

  static Future<void> publishAudio({
    required String sourcePath,
    required String fileName,
    required String title,
    required String artist,
    String? album,
    String folder = 'Yora',
  }) async {
    try {
      await _channel.invokeMethod('publishAudio', {
        'sourcePath': sourcePath,
        'fileName': fileName,
        'title': title,
        'artist': artist,
        'album': album,
        'folder': folder,
      });
    } catch (e) {
      debugPrint('Publication MediaStore échouée ($e)');
    }
  }

  static Future<void> purgeLegacyCacheFolder() async {
    try {
      await _channel.invokeMethod('purgePublishedFolder', {'folder': 'YoraCache'});
    } catch (e) {
      debugPrint('Purge de Musique/YoraCache échouée ($e)');
    }
  }

  static Future<int> restoreDownloads(List<String> paths) async {
    try {
      return await _channel.invokeMethod<int>('restoreDownloads', {'paths': paths}) ?? 0;
    } catch (e) {
      debugPrint('Récupération depuis Musique/Yora échouée ($e)');
      return 0;
    }
  }

  static Future<bool> openMusicFolder({String folder = 'Yora'}) async {
    try {
      return await _channel.invokeMethod<bool>('openMusicFolder', {'folder': folder}) ?? false;
    } catch (e) {
      debugPrint('Ouverture du dossier Musique/$folder échouée ($e)');
      return false;
    }
  }
}
