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

  final isChefy = filename.toLowerCase().endsWith('.chefy') ||
      mimeType == 'application/vnd.chefandcost.recipe' ||
      mimeType == 'application/x-chefy';

  final resolvedFilename = isChefy && !filename.toLowerCase().endsWith('.chefy')
      ? '$filename.chefy'
      : (filename.isNotEmpty ? filename : (isChefy ? 'recipe.chefy' : 'file'));

  final resolvedMimeType =
      isChefy ? 'application/vnd.chefandcost.recipe' : mimeType;

  final file = File('${shareDir.path}/$resolvedFilename');
  await file.writeAsBytes(bytes, flush: true);
  return XFile(file.path, name: resolvedFilename, mimeType: resolvedMimeType);
}
