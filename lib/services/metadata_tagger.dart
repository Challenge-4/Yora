import 'dart:io';
import 'package:http/http.dart' as http;

class MetadataTagger {
  final String ffmpegPath;
  MetadataTagger(this.ffmpegPath);

  Future<void> tagMp3({
    required String filePath,
    required String title,
    required String artist,
    String? album,
    String? year,
    String? genre,
    String? coverImageUrl,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) return;

    File? coverFile;
    if (coverImageUrl != null && coverImageUrl.isNotEmpty) {
      try {
        final response =
            await http.get(Uri.parse(coverImageUrl)).timeout(const Duration(seconds: 10));
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          coverFile = File('$filePath.cover.jpg');
          await coverFile.writeAsBytes(response.bodyBytes);
        }
      } catch (_) {
        coverFile = null;
      }
    }

    final outputFile = File('$filePath.tagged.mp3');
    final args = <String>['-y', '-i', filePath];
    if (coverFile != null) args.addAll(['-i', coverFile.path]);
    args.addAll(['-map', '0:a']);
    if (coverFile != null) args.addAll(['-map', '1:0']);
    args.addAll(['-c', 'copy', '-id3v2_version', '3']);
    args.addAll(['-metadata', 'title=$title']);
    args.addAll(['-metadata', 'artist=$artist']);
    if (album != null && album.isNotEmpty) args.addAll(['-metadata', 'album=$album']);
    if (year != null && year.isNotEmpty) args.addAll(['-metadata', 'date=$year']);
    if (genre != null && genre.isNotEmpty) args.addAll(['-metadata', 'genre=$genre']);
    if (coverFile != null) {
      args.addAll(['-metadata:s:v', 'title=Album cover']);
      args.addAll(['-metadata:s:v', 'comment=Cover (front)']);
    }
    args.add(outputFile.path);

    try {
      final result = await Process.run(ffmpegPath, args).timeout(const Duration(seconds: 30));
      if (result.exitCode == 0 && await outputFile.exists()) {
        await file.delete();
        await outputFile.rename(filePath);
      } else if (await outputFile.exists()) {
        await outputFile.delete();
      }
    } catch (_) {
      if (await outputFile.exists()) {
        try {
          await outputFile.delete();
        } catch (_) {}
      }
    } finally {
      if (coverFile != null) {
        try {
          await coverFile.delete();
        } catch (_) {}
      }
    }
  }
}
