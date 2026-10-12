import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

/// Web implementation for sharing or downloading files.
Future<bool> webShareOrDownloadFile({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
  String? subject,
}) async {
  // 1. Attempt native Web Share API if supported by user agent (e.g., mobile Safari / Chrome)
  try {
    final webFile = web.File(
      [bytes.toJS].toJS,
      filename,
      web.FilePropertyBag(type: mimeType),
    );

    final shareData = web.ShareData(
      files: [webFile].toJS,
      title: subject ?? filename,
    );

    if (web.window.navigator.canShare(shareData)) {
      await web.window.navigator.share(shareData).toDart;
      return true;
    }
  } catch (_) {
    // If Web Share API fails or is aborted/unsupported, fall through to browser download
  }

  // 2. Direct browser download fallback via Blob and anchor click
  try {
    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: mimeType),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement
      ..href = url
      ..download = filename
      ..style.display = 'none';

    web.document.body?.appendChild(anchor);
    anchor.click();
    anchor.remove();
    web.URL.revokeObjectURL(url);
    return true;
  } catch (e) {
    return false;
  }
}
