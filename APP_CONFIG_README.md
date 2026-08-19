# AppConfig - Konfigurasi Aplikasi Dinamis

File `lib/config/app_config.dart` berisi semua konfigurasi aplikasi yang dapat diubah dengan mudah:

## 📱 **Informasi Aplikasi**
```dart
static const String appVersion = '1.0.0';      // Versi aplikasi
static const String buildNumber = '1';          // Build number
static const String buildDate = '2025.11.28';   // Tanggal build
static const String appName = 'OneLink';        // Nama aplikasi
```

## 👨‍💻 **Informasi Developer**
```dart
static const String developerName = 'Febri Kukuh Santoso';
static const String developerRole = 'Mobile App Developer';
static const String developerEmail = 'febri.kukuh@email.com';
```

## 🏢 **Informasi Perusahaan**
```dart
static const String companyName = 'Green Energi Utama';
static const String companyWebsite = 'https://greenenergiutama.co.id';
```

## ⚙️ **Informasi Teknis**
```dart
static const String platform = 'Flutter';
static const String language = 'Dart';
static const String backend = 'REST API';
static const String database = 'MySQL';
static const String baseUrl = 'https://greenenergiutama.co.id/api';
```

## 📋 **Fitur Aplikasi**
```dart
static const List<String> appFeatures = [
  'Menjadwalkan penjemputan minyak jelantah',
  'Melacak lokasi pengumpulan terdekat',
  'Memantau riwayat kontribusi lingkungan',
  'Mendapatkan informasi edukasi tentang daur ulang',
];
```

## 🔧 **Formatted Strings**
```dart
static String get formattedVersion => 'Versi $appVersion';           // "Versi 1.0.0"
static String get fullVersionInfo => 'Versi $appVersion ($buildNumber)'; // "Versi 1.0.0 (1)"
static String get versionWithDate => 'Versi $appVersion - Build $buildDate'; // "Versi 1.0.0 - Build 2025.11.28"
static String get copyright => '© ${DateTime.now().year} $appName App\nDikembangkan dengan ❤️ oleh $developerName';
```

## 🎯 **Penggunaan:**

### Login Screen:
```dart
Text(AppConfig.appName)           // "OneLink" 
Text(AppConfig.formattedVersion)  // "Versi 1.0.0"
```

### About Screen:
```dart
Text(AppConfig.appName)           // "OneLink"
Text(AppConfig.appDescription)    // "Solusi Pengumpulan Minyak Jelantah"
Text(AppConfig.formattedVersion)  // "Versi 1.0.0"
Text(AppConfig.developerName)     // "Febri Kukuh Santoso"
Text(AppConfig.developerRole)     // "Mobile App Developer"
Text(AppConfig.copyright)         // Copyright dengan tahun dinamis
```

### Technical Info:
```dart
_buildInfoRow('Platform', AppConfig.platform)  // "Flutter"
_buildInfoRow('Versi', AppConfig.appVersion)   // "1.0.0"
_buildInfoRow('Build', AppConfig.buildDate)    // "2025.11.28"
_buildInfoRow('Bahasa', AppConfig.language)    // "Dart"
_buildInfoRow('Backend', AppConfig.backend)    // "REST API"
_buildInfoRow('Database', AppConfig.database)  // "MySQL"
```

## ✅ **Keuntungan:**
- **Single Source of Truth** - Semua info app di satu tempat
- **Easy Maintenance** - Update versi/info hanya di 1 file
- **Consistent** - Semua screen menggunakan data yang sama
- **Professional** - Tidak ada hardcoded strings
- **Future-proof** - Mudah ditambah field baru

## 🔄 **Untuk Update Versi:**
Cukup ubah di `app_config.dart`:
```dart
static const String appVersion = '1.0.1';  // Update versi
static const String buildDate = '2025.12.01';  // Update build date
```

Semua screen akan otomatis menampilkan versi terbaru! 🎉