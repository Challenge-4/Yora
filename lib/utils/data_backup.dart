import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'platform_paths.dart';

const int _kBackupFormatVersion = 1;

enum DataImportOutcome { success, cancelled, invalidFile }

Future<String?> exportUserData() async {
  final prefs = await SharedPreferences.getInstance();
  final data = <String, dynamic>{for (final key in prefs.getKeys()) key: prefs.get(key)};
  final envelope = {
    'yoraBackupVersion': _kBackupFormatVersion,
    'exportedAt': DateTime.now().toIso8601String(),
    'preferences': data,
  };
  final jsonString = const JsonEncoder.withIndent('  ').convert(envelope);

  if (Platform.isAndroid || Platform.isIOS) {
    return FilePicker.platform.saveFile(
      dialogTitle: 'Exporter les données Yora',
      fileName: 'yora_backup.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: Uint8List.fromList(utf8.encode(jsonString)),
    );
  }

  final documentsDir = defaultDocumentsPath();
  final chosenPath = await FilePicker.platform.saveFile(
    dialogTitle: 'Exporter les données Yora',
    fileName: 'yora_backup.json',
    initialDirectory: documentsDir,
    type: FileType.custom,
    allowedExtensions: ['json'],
  );
  if (chosenPath == null) return null;

  final path = chosenPath.toLowerCase().endsWith('.json') ? chosenPath : '$chosenPath.json';
  await File(path).writeAsString(jsonString);
  return path;
}

Future<DataImportOutcome> importUserData() async {
  final result = await FilePicker.platform.pickFiles(
    dialogTitle: 'Importer des données Yora',
    type: FileType.custom,
    allowedExtensions: ['json'],
  );
  final path = result?.files.single.path;
  if (path == null) return DataImportOutcome.cancelled;

  try {
    final content = await File(path).readAsString();
    final decoded = jsonDecode(content);
    if (decoded is! Map || decoded['preferences'] is! Map) {
      return DataImportOutcome.invalidFile;
    }
    final preferences = Map<String, dynamic>.from(decoded['preferences'] as Map);
    final prefs = await SharedPreferences.getInstance();
    for (final entry in preferences.entries) {
      final value = entry.value;
      if (value is bool) {
        await prefs.setBool(entry.key, value);
      } else if (value is int) {
        await prefs.setInt(entry.key, value);
      } else if (value is double) {
        await prefs.setDouble(entry.key, value);
      } else if (value is String) {
        await prefs.setString(entry.key, value);
      } else if (value is List) {
        await prefs.setStringList(entry.key, value.cast<String>());
      }
    }
    if (Platform.isAndroid) await rewriteLegacyAndroidDownloadPaths();
    return DataImportOutcome.success;
  } catch (_) {
    return DataImportOutcome.invalidFile;
  }
}
