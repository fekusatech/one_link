# Self-Update Feature Documentation

## Overview
Fitur self-update untuk aplikasi One Link - PT Green Energi Utama. Pengguna dapat mendownload dan menginstall update APK secara langsung dari dalam aplikasi tanpa perlu download manual dari browser.

## Flow

```
┌─────────────────┐
│  App Launch     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Check Version   │ ──► GET /api/check_version
│ from Server     │
└────────┬────────┘
         │
    ┌────┴────┐
    ▼         ▼
 No Update  Update
            Available
    │         │
    ▼         ▼
 Continue  Show Update Dialog
             (version, notes, force_update)
             │
             ▼
      User clicks "Update Sekarang"
             │
             ▼
      Show Download Progress
             │
             ▼
      Download APK to
      /storage/emulated/0/Download/
      one_link_update.apk
             │
             ▼
      Show Success Dialog
      with "Install Sekarang" button
             │
             ▼
      User clicks "Install Sekarang"
             │
             ▼
      Copy APK to /data/local/tmp/
             │
             ▼
      Run: pm install -r /data/local/tmp/one_link_update.apk
             │
             ▼
      Show result (success/fail)
```

## Files

### Created
- `lib/models/app_version.dart` - Model untuk response versi dari API

### Modified
- `lib/services/update_service.dart` - Service utama untuk:
  - Pengecekan versi dari server
  - Download APK ke Downloads folder
  - Copy APK ke temp folder
  - Install APK via pm command
  
- `android/app/src/main/AndroidManifest.xml` - Sudah ada:
  - `REQUEST_INSTALL_PACKAGES` permission
  - FileProvider configuration

## API Requirements

Server perlu menyediakan endpoint:

```json
GET /api/check_version

Response:
{
  "success": true,
  "data": {
    "version": "1.0.5",
    "url": "https://erp.greenenergiutama.co.id/apk/one-link-v1.0.5.apk",
    "force_update": false,
    "release_notes": "Bug fixes and performance improvements"
  }
}
```

## Testing

Untuk testing, bisa bypass version check dengan uncomment di `lib/services/update_service.dart`:

```dart
// if (true) {
//   _showUpdateDialog(context, "99.0.0", "https://erp.greenenergiutama.co.id/apk/one-link-v1.0.5.apk", false, "Test update");
//   return;
// }
```

## Notes

- Download menggunakan Dio ke `/storage/emulated/0/Download/`
- Install menggunakan `pm install` yang butuh copy ke `/data/local/tmp/` dulu
- Untuk Android 10+ tidak butuh storage permission karena pakai Downloads folder
- Jika pm install gagal (biasanya butuh root), user bisa install manual dari file manager