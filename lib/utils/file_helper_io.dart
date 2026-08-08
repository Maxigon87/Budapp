import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_selector/file_selector.dart';

void saveFileBytes(Uint8List bytes, String fileName, String mimeType) async {
  if (Platform.isAndroid || Platform.isIOS) {
    try {
      final directory = await getTemporaryDirectory();
      final tempFilePath = '${directory.path}/$fileName';
      final file = File(tempFilePath);
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(tempFilePath)],
        subject: fileName,
      );
    } catch (e) {
      print("Error sharing file on mobile: $e");
    }
  } else {
    try {
      final ext = fileName.split('.').last;
      final typeGroup = XTypeGroup(
        label: ext.toUpperCase(),
        extensions: [ext],
        mimeTypes: [mimeType],
      );
      final saveLocation = await getSaveLocation(
        acceptedTypeGroups: [typeGroup],
        suggestedName: fileName,
      );
      if (saveLocation == null) return;
      final file = XFile.fromData(bytes, mimeType: mimeType, name: fileName);
      await file.saveTo(saveLocation.path);
    } catch (e) {
      print("Error saving file on desktop: $e");
    }
  }
}
