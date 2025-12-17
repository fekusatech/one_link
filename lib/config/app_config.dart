class AppConfig {
  // App Version & Build Info
  static const String appVersion = '1.0.0';
  static const String buildNumber = '1';
  static const String buildDate = '2025.11.28';
  static const String appName = 'OneLink';

  // App Description
  static const String appDescription = 'Solusi Pengumpulan Minyak Jelantah';
  static const String appTagline =
      'Minyak Daur Ulang untuk Masa Depan Berkelanjutan';

  // Developer Info
  static const String developerName = 'Febri Kukuh Santoso';
  static const String developerRole = 'Mobile App Developer';
  static const String developerEmail = 'santosofebrikukuh@gmail.com';

  // Company Info
  static const String companyName = 'Green Energi Utama';
  static const String companyWebsite = 'https://greenenergiutama.co.id';

  // Technical Info
  static const String platform = 'Flutter';
  static const String language = 'Dart';
  static const String backend = 'REST API';
  static const String database = 'MySQL';

  // API Configuration
  static const String baseUrl = 'https://erp.greenenergiutama.co.id/api';

  // App Features
  static const List<String> appFeatures = [
    'Menjadwalkan penjemputan minyak jelantah',
    'Melacak lokasi pengumpulan terdekat',
    'Memantau riwayat kontribusi lingkungan',
    'Mendapatkan informasi edukasi tentang daur ulang',
  ];

  // Formatted version string
  static String get formattedVersion => 'Versi $appVersion';
  static String get fullVersionInfo => 'Versi $appVersion ($buildNumber)';
  static String get versionWithDate => 'Versi $appVersion - Build $buildDate';

  // Copyright
  static String get copyright =>
      '© ${DateTime.now().year} $appName App\nDikembangkan dengan ❤️ oleh $developerName';
}
