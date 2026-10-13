import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';

/// Web stub for preparing files for sharing.
/// Returns an in-memory XFile.
Future<XFile> prepareFileForShare({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
}) async {
  return XFile.fromData(
    bytes,
    name: filename,
    mimeType: mimeType,
  );
}
