import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;

/// Bakes the same GEU field-evidence watermark the web app draws on canvas
/// (application/views/surat-jalan/new_take.php: addWatermarkToCanvas —
/// logo, "Green Energi Utama", timestamp, photo label, SJ kode, bottom-right
/// corner) directly onto the bitmap, so proof photos look identical no
/// matter which client captured them. Also handles the WebP conversion the
/// Go backend requires for both photo and signature uploads
/// (surat_jalan_service_detail.go rejects anything that isn't image/webp).
class PhotoWatermarkService {
  static const _maxSide = 1280;
  static const _maxBytes = 400 * 1024;

  static img.Image? _logoCache;
  static bool _logoLoadFailed = false;

  static Future<img.Image?> _loadLogo() async {
    if (_logoCache != null || _logoLoadFailed) return _logoCache;
    try {
      final data = await rootBundle.load('assets/images/logo.png');
      _logoCache = img.decodePng(data.buffer.asUint8List());
    } catch (_) {
      _logoLoadFailed = true;
    }
    return _logoCache;
  }

  /// [label] is the photo type shown to the driver (e.g. "Bukti
  /// Pengambilan"). Returns WebP bytes ready for UploadDetailPhoto.
  static Future<Uint8List> applyAndEncode(
    List<int> sourceBytes, {
    required String label,
    required String suratJalanKode,
  }) async {
    final decoded = img.decodeImage(Uint8List.fromList(sourceBytes));
    if (decoded == null) {
      throw StateError('File foto tidak valid.');
    }

    var image = img.bakeOrientation(decoded);
    final longest = image.width > image.height ? image.width : image.height;
    if (longest > _maxSide) {
      final scale = _maxSide / longest;
      image = img.copyResize(
        image,
        width: (image.width * scale).round(),
        height: (image.height * scale).round(),
      );
    }

    final logo = await _loadLogo();
    final margin = (image.width * 0.02).round().clamp(8, 24);
    final logoWidth = (image.width * 0.16).round().clamp(70, 160);

    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final lines = <String>['Green Energi Utama', dateStr, label, suratJalanKode];
    final font = img.arial14;
    const lineHeight = 16;

    img.Image? resizedLogo;
    var logoHeight = 0;
    if (logo != null) {
      final aspect = logo.height / logo.width;
      logoHeight = (logoWidth * aspect).round();
      resizedLogo = img.copyResize(logo, width: logoWidth, height: logoHeight);
    }

    final textBlockHeight = lines.length * lineHeight;
    final boxWidth = logoWidth + margin * 2;
    final boxHeight = logoHeight + textBlockHeight + margin * 2;
    final boxX = (image.width - boxWidth - margin).clamp(0, image.width);
    final boxY = (image.height - boxHeight - margin).clamp(0, image.height);

    img.fillRect(
      image,
      x1: boxX,
      y1: boxY,
      x2: (boxX + boxWidth).clamp(0, image.width),
      y2: (boxY + boxHeight).clamp(0, image.height),
      color: img.ColorRgba8(0, 0, 0, 130),
    );

    if (resizedLogo != null) {
      img.compositeImage(image, resizedLogo, dstX: boxX + margin, dstY: boxY + margin);
    }

    var textY = boxY + margin + logoHeight + 2;
    for (final line in lines) {
      img.drawString(
        image,
        line,
        font: font,
        x: boxX + margin,
        y: textY,
        color: img.ColorRgb8(255, 255, 255),
      );
      textY += lineHeight;
    }

    // PNG (lossless) here, not JPEG — the watermark box has sharp
    // black/white edges (box border + text), and JPEG-then-WebP would
    // compress it twice, which shows up as yellow/green fringing right at
    // those edges once _compressToWebp has to drop quality to hit the size
    // budget. A single lossy pass (WebP only) keeps the watermark clean.
    final baked = img.encodePng(image);
    return _compressToWebp(baked);
  }

  static Future<Uint8List> _compressToWebp(List<int> bytes) async {
    final input = Uint8List.fromList(bytes);
    List<int> output = await FlutterImageCompress.compressWithList(
      input,
      quality: 82,
      format: CompressFormat.webp,
      keepExif: false,
    );
    for (final quality in [70, 60, 50, 40]) {
      if (output.length <= _maxBytes) break;
      output = await FlutterImageCompress.compressWithList(
        input,
        quality: quality,
        format: CompressFormat.webp,
        keepExif: false,
      );
    }
    return Uint8List.fromList(output);
  }

  /// Converts an already-final image (e.g. a signature PNG exported by the
  /// `signature` package) straight to WebP — no watermark, no resize.
  static Future<Uint8List> toWebp(Uint8List sourceBytes) async {
    final output = await FlutterImageCompress.compressWithList(
      sourceBytes,
      quality: 90,
      format: CompressFormat.webp,
      keepExif: false,
    );
    return Uint8List.fromList(output);
  }
}
