import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:path/path.dart' as p;

class ImageCompressUtils {
  /// Kompresi file foto ke WebP / JPEG dengan target ukuran di bawah 1MB
  static Future<File> compressImage(File file, {int quality = 70, int minWidth = 1080}) async {
    try {
      final fileSize = await file.length();
      // Jika ukuran file sudah di bawah 800KB, kembalikan file asli
      if (fileSize < 800 * 1024) {
        return file;
      }

      final dir = await path_provider.getTemporaryDirectory();
      final targetPath = p.join(
        dir.path,
        'compressed_${DateTime.now().millisecondsSinceEpoch}.webp',
      );

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: quality,
        minWidth: minWidth,
        format: CompressFormat.webp,
      );

      if (result != null) {
        return File(result.path);
      }
      return file;
    } catch (e) {
      print('⚠️ Error during image compression: $e. Returning original file.');
      return file;
    }
  }
}
