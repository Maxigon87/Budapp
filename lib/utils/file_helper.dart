import 'dart:typed_data';
import 'file_helper_stub.dart'
    if (dart.library.html) 'file_helper_web.dart'
    if (dart.library.io) 'file_helper_io.dart';

void saveFile(Uint8List bytes, String fileName, String mimeType) {
  saveFileBytes(bytes, fileName, mimeType);
}
