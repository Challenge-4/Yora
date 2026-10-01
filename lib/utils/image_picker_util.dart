import 'package:file_picker/file_picker.dart';
import 'image_store.dart';
import 'platform_paths.dart';

Future<String?> pickSingleImagePath() async {
  final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false);
  final path = result?.files.single.path;
  if (path == null || !isMobile) return path;
  try {
    return await keepPermanentImageCopy(path);
  } catch (_) {
    return path;
  }
}
