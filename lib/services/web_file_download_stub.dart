import 'dart:typed_data';

/// Stub implementation for non-web platforms.
Future<bool> webShareOrDownloadFile({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
  String? subject,
}) async {
  return false;
}
