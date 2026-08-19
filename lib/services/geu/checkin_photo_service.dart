import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class CapturedVisitPhoto {
  final File file;
  final int bytes;

  const CapturedVisitPhoto({required this.file, required this.bytes});

  Future<String> asBase64() async => base64Encode(await file.readAsBytes());
}

/// Captures a camera-only proof photo and normalizes it before it can enter
/// the offline queue. Images are WebP, max 720px on the longest side, and
/// repeatedly compressed until reaching the 150KB product target.
class CheckinPhotoService {
  static const maxBytes = 150 * 1024;
  static const maxSide = 720;

  static Future<CapturedVisitPhoto> capture({String type = 'checkin'}) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.camera);
    if (picked == null) {
      throw StateError('Foto check-in wajib diambil dari kamera.');
    }
    final output = await _compress(await picked.readAsBytes());
    final dir = await getApplicationDocumentsDirectory();
    final photosDir = Directory('${dir.path}/geu_visit_photos');
    await photosDir.create(recursive: true);
    final file = File(
      '${photosDir.path}/${type}_${DateTime.now().microsecondsSinceEpoch}.webp',
    );
    await file.writeAsBytes(Uint8List.fromList(output), flush: true);
    return CapturedVisitPhoto(file: file, bytes: output.length);
  }

  static Future<List<int>> compressForQueue(List<int> bytes) =>
      _compress(bytes);

  static Future<List<int>> _compress(List<int> bytes) async {
    final decoded = img.decodeImage(Uint8List.fromList(bytes));
    if (decoded == null)
      throw StateError('File kamera bukan gambar yang valid.');
    final longest = decoded.width > decoded.height
        ? decoded.width
        : decoded.height;
    final scale = longest <= maxSide ? 1.0 : maxSide / longest;
    final targetWidth = (decoded.width * scale).round();
    final targetHeight = (decoded.height * scale).round();
    List<int> output = await FlutterImageCompress.compressWithList(
      Uint8List.fromList(bytes),
      minWidth: targetWidth,
      minHeight: targetHeight,
      quality: 70,
      format: CompressFormat.webp,
      keepExif: false,
    );
    for (final quality in [60, 50, 40, 30]) {
      if (output.length <= maxBytes) break;
      output = await FlutterImageCompress.compressWithList(
        Uint8List.fromList(bytes),
        minWidth: targetWidth,
        minHeight: targetHeight,
        quality: quality,
        format: CompressFormat.webp,
        keepExif: false,
      );
    }
    return output;
  }
}
