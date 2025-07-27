import 'package:file_picker/file_picker.dart';

// Test helper class to create mock FilePickerResults
class TestFilePickerHelper {
  static FilePickerResult createMockResult({
    required String fileName,
    required String filePath,
    int fileSize = 0,
  }) {
    return FilePickerResult([
      PlatformFile(
        name: fileName,
        size: fileSize,
        path: filePath,
      )
    ]);
  }
}
