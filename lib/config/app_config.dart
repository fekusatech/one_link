import 'package:package_info_plus/package_info_plus.dart';

class AppConfig {
  // Info Versi & Build Aplikasi
  static String appVersion = '1.0.0';
  static String buildNumber = '1';
  static const String buildDate = '2025.11.28';
  static const String appName = 'One Link - GEU';

  static Future<void> init() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      appVersion = packageInfo.version;
      buildNumber = packageInfo.buildNumber;
    } catch (e) {
      print('Gagal mendapatkan info aplikasi: $e');
    }
  }

  // Deskripsi Aplikasi
  static const String appDescription = 'Solusi Pengumpulan Minyak Jelantah';
  static const String appTagline =
      'Minyak Daur Ulang untuk Masa Depan Berkelanjutan';

  // Info Pengembang
  static const String developerName = 'Febri Kukuh Santoso';
  static const String developerRole = 'Pengembang Aplikasi Mobile';
  static const String developerEmail = 'santosofebrikukuh@gmail.com';

  // Info Perusahaan
  static const String companyName = 'Green Energi Utama';
  static const String companyWebsite = 'https://greenenergiutama.co.id';

  // Info Teknis
  static const String platform = 'Flutter';
  static const String language = 'Dart';
  static const String backend = 'REST API';
  static const String database = 'MySQL';

  // Konfigurasi API
  static const String serverDomain = 'https://erp.greenenergiutama.co.id';
  //  static const String serverDomain = 'https://greenenergiutama.cloud';
  //static const String serverDomain = 'http://localhost:8088';
  static const String baseUrl = '$serverDomain/api';
  static const String googleMapsApiKey =
      'AIzaSyDrojsCV5A1SB5v-WxK38upqLIdyEoYBYg';

  // Fitur Aplikasi
  static const List<String> appFeatures = [
    'Menjadwalkan penjemputan minyak jelantah',
    'Melacak lokasi pengumpulan terdekat',
    'Memantau riwayat kontribusi lingkungan',
    'Mendapatkan informasi edukasi tentang daur ulang',
  ];

  // Format String Versi
  static String get formattedVersion => 'Versi $appVersion';
  static String get fullVersionInfo => 'Versi $appVersion ($buildNumber)';
  static String get versionWithDate => 'Versi $appVersion - Build $buildDate';

  // Hak Cipta
  static String get copyright =>
      '© ${DateTime.now().year} Aplikasi $appName\nDikembangkan dengan ❤️ oleh $developerName';
}
