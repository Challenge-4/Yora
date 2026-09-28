import 'package:file_picker/file_picker.dart';

Future<String?> pickSingleImagePath() async {
  final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false);
  return result?.files.single.path;
}
