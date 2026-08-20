import 'package:url_launcher/url_launcher.dart';

class WaFormat {
  /// Smart convert any phone input to clean 628xxx format
  /// Handles: 08xx -> 628xx, 8xx -> 628xx, +628xx -> 628xx, formatting with spaces/dashes
  static String formatTo62(String phone) {
    if (phone.isEmpty) return '';

    // Clean all non-digit characters (+, -, space, parens)
    String digits = phone.replaceAll(RegExp(r'\D'), '');

    if (digits.isEmpty) return '';

    if (digits.startsWith('62')) {
      return digits;
    } else if (digits.startsWith('0')) {
      return '62${digits.substring(1)}';
    } else if (digits.startsWith('8')) {
      return '62$digits';
    }

    return digits;
  }

  /// Launch WhatsApp with smart converted phone & encoded message
  static Future<bool> launchWhatsApp({
    required String phone,
    required String message,
  }) async {
    final cleanPhone = formatTo62(phone);
    if (cleanPhone.isEmpty) return false;

    final encodedMsg = Uri.encodeComponent(message);
    final waUri = Uri.parse('https://wa.me/$cleanPhone?text=$encodedMsg');

    try {
      if (await canLaunchUrl(waUri)) {
        return await launchUrl(waUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
    return false;
  }

  /// Generate default proximity notification message for supplier
  static String generateProximityMessage({
    required String supplierName,
    required String driverName,
    required String noSuratJalan,
  }) {
    return 'Halo $supplierName, saya $driverName (Driver GEU One Link). '
        'Saya sudah mendekati lokasi Anda untuk penjemputan barang (Surat Jalan: $noSuratJalan). '
        'Mohon siapkan dokumen & muatan. Terima kasih!';
  }
}

/// Top-level helper dipakai oleh canvassing screens (mission_today, tasks,
/// work_order_list, my_claims, work_order_detail_sheet).
/// Build wa.me URL dengan smart convert 08xx -> 628xx.
String waUrl(String phone, {String? text}) {
  final cleanPhone = WaFormat.formatTo62(phone);
  if (cleanPhone.isEmpty) return '';
  final base = 'https://wa.me/$cleanPhone';
  if (text != null && text.isNotEmpty) {
    return '$base?text=${Uri.encodeComponent(text)}';
  }
  return base;
}
