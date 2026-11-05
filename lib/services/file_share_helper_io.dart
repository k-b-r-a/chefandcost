import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Native (IO) implementation for preparing files for sharing.
/// Writes the bytes to a dedicated temp file with the exact filename and extension
/// so that system file providers and receiving apps preserve the original name.
Future<XFile> prepareFileForShare({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
}) async {
  final tempDir = await getTemporaryDirectory();
  final shareDir = Directory('${tempDir.path}/shares');
  if (!await shareDir.exists()) {
    await shareDir.create(recursive: true);
  }
  final file = File('${shareDir.path}/$filename');
  await file.writeAsBytes(bytes, flush: true);
  return XFile(file.path, name: filename, mimeType: mimeType);
}
