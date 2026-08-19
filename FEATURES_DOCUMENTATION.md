# One Link - Fitur Dokumentasi

## 1. Self-Update Feature

### Overview
Fitur self-update untuk aplikasi One Link. Pengguna dapat mendownload dan menginstall update APK secara langsung dari dalam aplikasi tanpa perlu download manual dari browser.

### Flow
```
App Launch → Check Version (GET /api/check_version)
                    ↓
            [Update Available?] → Show Update Dialog
                    ↓
            User clicks "Update Sekarang" → Download Progress
                    ↓
            Download APK to /storage/emulated/0/Download/
                    ↓
            Show Success + "Install Sekarang" button
                    ↓
            Copy APK to /data/local/tmp/
                    ↓
            Run: pm install -r /data/local/tmp/one_link_update.apk
```

### Files
- `lib/models/app_version.dart` - Model untuk response versi
- `lib/services/update_service.dart` - Service utama download & install
- `SELF_UPDATE_FEATURE.md` - Dokumentasi lengkap

### API Requirements
```json
GET /api/check_version
Response: {
  "success": true,
  "data": {
    "version": "1.0.5",
    "url": "https://erp.greenenergiutama.co.id/apk/one-link-v1.0.5.apk",
    "force_update": false,
    "release_notes": "Bug fixes"
  }
}
```

### Testing
Bypass version check di `lib/services/update_service.dart`:
```dart
// if (true) {
//   _showUpdateDialog(context, "99.0.0", "https://erp.greenenergiutama.co.id/apk/one-link-v1.0.5.apk", false, "Test update");
//   return;
// }
```

---

## 2. GPS Tracking Feature

### Overview
Fitur tracking GPS untuk memantau lokasi driver/karyawan secara real-time. Tracking berjalan di background dan mengirim data ke server secara periodik.

### Flow
```
User Login → Auto-start tracking (if consent given)
                ↓
       LocationService.startTracking()
                ↓
       Start position stream (100m filter)
                ↓
       Heartbeat timer (2 min interval)
                ↓
       Send to API: POST /driver_tracking/save_location
                ↓
User Logout → Stop tracking + clear consent
```

### Files
- `lib/services/location_tracking_service.dart` - Service utama tracking
- `lib/services/driver_tracking_service.dart` - Service untuk send ke API

### Auto-Start After Login
Di `lib/screens/dashboard_screen.dart`:
```dart
Future<void> _startLocationTracking() async {
  final hasConsent = await UserStorage.hasLocationTrackingConsent();
  if (hasConsent) {
    final hasPermission = await LocationTrackingService.instance.hasPermissions();
    if (hasPermission && !LocationTrackingService.instance.isTracking) {
      await LocationTrackingService.instance.startTrackingWithoutPermissionCheck();
    }
  }
}
```

### Stop on Logout
Di `lib/screens/dashboard_screen.dart` - logout function:
```dart
// Stop location tracking on logout
await LocationTrackingService.instance.stopTracking();
await UserStorage.setLocationTrackingConsent(false);
```

### API Endpoint
```
POST /driver_tracking/save_location
Headers: Authorization: Bearer {token}
Body: {
  "karyawan_id": "123",
  "email": "driver@example.com",
  "jabatan_name": "Driver",
  "latitude": -6.123,
  "longitude": 106.123,
  "accuracy": 10,
  "speed": 5.5,
  "heading": 180,
  "altitude": 50,
  "timestamp": "2026-04-16T10:00:00Z",
  "battery_level": 85,
  "device_info": "Samsung Galaxy A51",
  "timestamp_ms": 1713268800000
}
```

### Configuration
- **Distance Filter**: 100m (hanya kirim jika bergerak >100m)
- **Heartbeat**: 2 menit (paksa kirim lokasi jika tidak bergerak)
- **Background**: Support Android foreground service

### Android Permissions (AndroidManifest.xml)
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
```

---

## Catatan Penting

1. **Consent Required**: Tracking hanya dimulai jika user sudah memberikan consent di mandatory GPS consent screen
2. **Stop on Logout**: Tracking wajib dihentikan saat logout untuk privacy
3. **Periodic Sending**: Setiap 100m movement ATAU 2 menit (heartbeat)
4. **Background Capable**: Menggunakan Android foreground service dengan notification