import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
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

/// Captures a camera-only proof photo, stamps it with the same watermark as
/// the web (erpmysql/crm-react) checkin/checkout flow - timestamp, GPS,
/// CHECK-IN/CHECK-OUT + supplier label, and the GEU logo - then normalizes
/// it before it can enter the offline queue. Images are WebP, max 720px on
/// the longest side, and repeatedly compressed until reaching the 150KB
/// product target.
class CheckinPhotoService {
  static const maxBytes = 150 * 1024;
  static const maxSide = 720;

  static Future<CapturedVisitPhoto> capture({
    String type = 'checkin',
    String? supplierName,
    double? latitude,
    double? longitude,
    ValueChanged<String>? onProgress,
  }) async {
    var stage = 'camera_open';
    final started = DateTime.now();
    _log('start type=$type');
    try {
      _log('stage=$stage begin');
      final picked = await ImagePicker().pickImage(source: ImageSource.camera);
      if (picked == null) {
        _log('stage=$stage cancelled');
        throw StateError('Foto check-in wajib diambil dari kamera.');
      }
      _log('stage=$stage complete');
      onProgress?.call('Menyiapkan foto...');

      stage = 'read_source';
      _log('stage=$stage begin');
      final source = await picked.readAsBytes();
      _log('stage=$stage complete bytes=${source.length}');
      onProgress?.call('Memproses foto...');

      stage = 'process_webp';
      final output = await _processAndCompress(
        source,
        type: type,
        supplierName: supplierName,
        latitude: latitude,
        longitude: longitude,
        onProgress: onProgress,
      );
      if (kIsWeb) {
        _log(
          'complete type=$type output_bytes=${output.length} elapsed_ms=${DateTime.now().difference(started).inMilliseconds}',
        );
        return CapturedVisitPhoto(
          file: File(picked.path),
          bytes: output.length,
        );
      }

      stage = 'save_webp';
      _log('stage=$stage begin bytes=${output.length}');
      onProgress?.call('Menyimpan foto...');
      final dir = await getApplicationDocumentsDirectory();
      final photosDir = Directory('${dir.path}/geu_visit_photos');
      await photosDir.create(recursive: true);
      final file = File(
        '${photosDir.path}/${type}_${DateTime.now().microsecondsSinceEpoch}.webp',
      );
      await file.writeAsBytes(Uint8List.fromList(output), flush: true);
      _log('stage=$stage complete bytes=${output.length}');
      _log(
        'complete type=$type output_bytes=${output.length} elapsed_ms=${DateTime.now().difference(started).inMilliseconds}',
      );
      return CapturedVisitPhoto(file: file, bytes: output.length);
    } catch (error, stack) {
      _log('failed stage=$stage type=$type error=$error\n$stack');
      rethrow;
    }
  }

  static Future<List<int>> compressForQueue(List<int> bytes) =>
      _compress(bytes);

  /// Decodes, resizes, stamps the watermark, then hands off to the same
  /// quality-reduction loop as the unwatermarked path.
  static Future<List<int>> _processAndCompress(
    List<int> bytes, {
    required String type,
    String? supplierName,
    double? latitude,
    double? longitude,
    ValueChanged<String>? onProgress,
  }) async {
    var stage = 'background_image_prepare';
    var stageStarted = DateTime.now();
    onProgress?.call('Menganalisis dan memberi watermark...');
    _log('stage=$stage begin input_bytes=${bytes.length}');
    Uint8List logo = Uint8List(0);
    try {
      final logoData = await rootBundle.load('assets/images/logo.png');
      logo = logoData.buffer.asUint8List(
        logoData.offsetInBytes,
        logoData.lengthInBytes,
      );
    } catch (_) {
      // The text watermark remains useful when the optional logo is missing.
    }
    final prepared = await compute(_prepareVisitPhoto, <String, Object?>{
      'bytes': Uint8List.fromList(bytes),
      'logo': logo,
      'type': type,
      'supplierName': supplierName,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': DateTime.now().toIso8601String(),
    });
    _log(
      'stage=$stage complete elapsed_ms=${DateTime.now().difference(stageStarted).inMilliseconds}',
    );
    if (prepared['error'] != null) {
      throw StateError('Pemrosesan gambar gagal: ${prepared['error']}');
    }
    if (prepared['invalid'] == true) {
      throw StateError('File kamera bukan gambar yang valid.');
    }
    if (prepared['tooDark'] == true) {
      throw StateError(
        'Foto terlalu gelap. Pastikan kamera tidak tertutup, lalu ambil ulang.',
      );
    }
    onProgress?.call('Mengubah foto ke WebP...');
    final png = prepared['png'] as Uint8List;
    final width = prepared['width'] as int;
    final height = prepared['height'] as int;
    stage = 'webp_encode';
    stageStarted = DateTime.now();
    _log(
      'stage=$stage begin width=$width height=$height png_bytes=${png.length}',
    );
    final output = await _encodeToTarget(
      png,
      width: width,
      height: height,
      onAttempt: (quality, bytes) =>
          _log('stage=$stage attempt quality=$quality output_bytes=$bytes'),
    );
    _log(
      'stage=$stage complete output_bytes=${output.length} elapsed_ms=${DateTime.now().difference(stageStarted).inMilliseconds}',
    );
    return output;
  }

  static (int, int) _targetSize(img.Image decoded) {
    final longest = decoded.width > decoded.height
        ? decoded.width
        : decoded.height;
    final scale = longest <= maxSide ? 1.0 : maxSide / longest;
    return ((decoded.width * scale).round(), (decoded.height * scale).round());
  }

  static Future<List<int>> _compress(List<int> bytes) async {
    final decoded = img.decodeImage(Uint8List.fromList(bytes));
    if (decoded == null)
      throw StateError('File kamera bukan gambar yang valid.');
    final (targetWidth, targetHeight) = _targetSize(decoded);
    return _encodeToTarget(
      Uint8List.fromList(bytes),
      width: targetWidth,
      height: targetHeight,
    );
  }

  static Future<List<int>> _encodeToTarget(
    Uint8List sourceBytes, {
    required int width,
    required int height,
    void Function(int quality, int outputBytes)? onAttempt,
  }) async {
    final started = DateTime.now();
    List<int> output = await FlutterImageCompress.compressWithList(
      sourceBytes,
      minWidth: width,
      minHeight: height,
      quality: 70,
      format: CompressFormat.webp,
      keepExif: false,
    );
    onAttempt?.call(70, output.length);
    for (final quality in [60, 50, 40, 30]) {
      if (output.length <= maxBytes) break;
      output = await FlutterImageCompress.compressWithList(
        sourceBytes,
        minWidth: width,
        minHeight: height,
        quality: quality,
        format: CompressFormat.webp,
        keepExif: false,
      );
      onAttempt?.call(quality, output.length);
    }
    _log(
      'stage=webp_encode encoder_elapsed_ms=${DateTime.now().difference(started).inMilliseconds} attempts_complete=true',
    );
    return output;
  }

  static void _log(String message) => debugPrint('[VISIT_PHOTO] $message');
}

/// Runs all CPU-heavy decode, brightness sampling, resize, watermark and PNG
/// preparation away from Flutter's UI isolate (large camera frames can be
/// tens of megapixels).
Map<String, Object?> _prepareVisitPhoto(Map<String, Object?> args) {
  try {
    final bytes = args['bytes'] as Uint8List;
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return {'invalid': true};

    final sampleScale =
        256 / (decoded.width > decoded.height ? decoded.width : decoded.height);
    final sampled = sampleScale < 1
        ? img.copyResize(
            decoded,
            width: (decoded.width * sampleScale).round().clamp(1, 256),
            height: (decoded.height * sampleScale).round().clamp(1, 256),
          )
        : decoded;
    var darkPixels = 0;
    final pixelCount = sampled.width * sampled.height;
    for (var y = 0; y < sampled.height; y++) {
      for (var x = 0; x < sampled.width; x++) {
        final pixel = sampled.getPixel(x, y);
        final luminance =
            0.2126 * pixel.r + 0.7152 * pixel.g + 0.0722 * pixel.b;
        if (luminance <= 45) darkPixels++;
      }
    }
    if (darkPixels / pixelCount >= 0.97) return {'tooDark': true};

    final longest = decoded.width > decoded.height
        ? decoded.width
        : decoded.height;
    final scale = longest <= CheckinPhotoService.maxSide
        ? 1.0
        : CheckinPhotoService.maxSide / longest;
    final width = (decoded.width * scale).round();
    final height = (decoded.height * scale).round();
    final image = img.copyResize(decoded, width: width, height: height);
    _stampVisitPhoto(image, args);
    return {
      'png': Uint8List.fromList(img.encodePng(image)),
      'width': width,
      'height': height,
    };
  } catch (error, stack) {
    return {'error': '$error\n$stack'};
  }
}

void _stampVisitPhoto(img.Image image, Map<String, Object?> args) {
  try {
    final isCheckout = args['type'] == 'checkout';
    final label = isCheckout ? 'CHECK-OUT' : 'CHECK-IN';
    final labelColor = isCheckout
        ? img.ColorRgba8(255, 152, 0, 255)
        : img.ColorRgba8(76, 175, 80, 255);
    final barHeight = (image.height * 0.22).clamp(64, 130).round();
    final barTop = image.height - barHeight;
    img.fillRect(
      image,
      x1: 0,
      y1: barTop,
      x2: image.width,
      y2: image.height,
      color: img.ColorRgba8(0, 0, 0, 145),
    );

    var textX = 10;
    final logoSize = (barHeight - 16).clamp(24, 64);
    try {
      final logoBytes = args['logo'] as Uint8List;
      final logo = logoBytes.isEmpty ? null : img.decodePng(logoBytes);
      if (logo != null) {
        img.compositeImage(
          image,
          img.copyResize(logo, width: logoSize, height: logoSize),
          dstX: 10,
          dstY: barTop + ((barHeight - logoSize) / 2).round(),
        );
        textX = 10 + logoSize + 8;
      }
    } catch (_) {}

    var y = barTop + 6;
    final supplierName = args['supplierName'] as String?;
    img.drawString(
      image,
      supplierName != null && supplierName.isNotEmpty
          ? '$label - $supplierName'
          : label,
      font: img.arial14,
      x: textX,
      y: y,
      color: labelColor,
    );
    y += 16;
    img.drawString(
      image,
      'Green Energi Utama · Mobile App',
      font: img.arial14,
      x: textX,
      y: y,
      color: img.ColorRgba8(255, 255, 255, 210),
    );
    y += 15;
    final timestamp =
        DateTime.tryParse(args['timestamp'] as String? ?? '')?.toLocal() ??
        DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    img.drawString(
      image,
      '${two(timestamp.day)}/${two(timestamp.month)}/${timestamp.year} ${two(timestamp.hour)}:${two(timestamp.minute)}:${two(timestamp.second)}',
      font: img.arial14,
      x: textX,
      y: y,
      color: img.ColorRgba8(255, 255, 255, 255),
    );
    final latitude = args['latitude'] as double?;
    final longitude = args['longitude'] as double?;
    if (latitude != null && longitude != null && barHeight >= 90) {
      y += 15;
      img.drawString(
        image,
        '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
        font: img.arial14,
        x: textX,
        y: y,
        color: img.ColorRgba8(255, 255, 255, 255),
      );
    }
  } catch (error, stack) {
    debugPrint('CheckinPhotoService: watermark failed: $error\n$stack');
  }
}
