# PRD – Driver Map & Tracking (Mobile App)

## 0. TL;DR untuk yang eksekusi (baca ini dulu)

Fitur ini **kemungkinan besar backend-nya sudah ada** di Go API (`apipi.greenenergiutama.co.id`), lihat `doc.md` baris 380-386:

```
POST /api-tms/tracking/update    UpdateLocation      tms-update-tracking   Update lokasi GPS user (tracking berkelanjutan)
GET  /api-tms/tracking/live      GetLiveTracking     auth                  Lokasi live semua user aktif
GET  /api-tms/tracking/history   GetRouteHistory     auth                  Histori rute GPS user tertentu per tanggal
GET  /api-tms/mapping/data       GetData             tms-read-mapping      Data peta (filter tanggal/gudang/driver/status)
GET  /api-tms/mapping/statistics GetStatistics       tms-read-mapping      Statistik mapping
POST /api-tms/mapping/calculate-route CalculateRoute tms-read-mapping      Hitung rute
POST /api-tms/mapping/routes     SaveRoute           tms-create-mapping    Simpan rute
```

`doc.md` cuma daftar route (Method/Path/Handler/Guard/Purpose), **bukan** spesifikasi request/response body. Jadi **Step 0 wajib**: buka source Go API (`internal/adapter/handler/tracking_handler.go` dan `mapping_handler.go`, atau nama filenya bisa beda — cari di router), baca beneran struct request/response-nya, ATAU hit endpoint live pakai token valid buat lihat shape response asli. Jangan asal nebak field name dari dokumen ini — bagian 4 di bawah cuma **referensi/ekspektasi** berdasarkan fitur yang sudah terbukti jalan di versi web (`erpmysql`), dipakai buat validasi apakah endpoint Go yang ada sudah cukup atau perlu ditambah field.

**Kalau setelah dicek endpoint Go-nya ternyata sudah pas** → skip section 4.2-4.4, langsung ke section 5 (Flutter). **Kalau ada gap** (field kurang, business logic beda) → section 4.5 kasih algoritma & SQL referensi yang sudah tervalidasi jalan di web, tinggal di-port ke Go.

Konteks: ini port dari fitur **Driver Tracking Map** yang sudah dibangun & dites di web admin (`erpmysql/application/controllers/Driver_map.php` + `application/views/driver/map_tracking.php`). Semua keputusan desain (warna, algoritma dwell-time, aturan akses) di bawah ini **sudah divalidasi jalan** terhadap data production asli — bukan spekulasi.

---

## 1. Overview

Dua tampilan dalam satu fitur, role-based (auto, gak perlu switch manual):

- **Admin/Dispatcher** (role Developer, Super User, Koordinator Logistik — sama persis dengan yang boleh akses `driver_map` di web): live map semua driver, tap satu driver → lihat rute historis + surat jalan hari itu + estimasi rute + berapa lama dia di tiap lokasi.
- **Driver biasa**: buka app, langsung lihat peta dirinya sendiri + daftar surat jalan yang harus dia kunjungi hari itu (atau tanggal lain), tanpa perlu pilih driver (karena dia cuma boleh lihat dirinya sendiri).

Role determination: reuse `RoleManagementService.analyzeUserRole()` / `DashboardAccessService` yang sudah ada — **jangan bikin role-check baru**. Untuk membedakan "admin driver-map" dari admin generik, lihat section 3.

---

## 2. Kenapa gak pakai endpoint lama `driver_tracking/save_location`

Endpoint itu (`DriverTrackingService.sendLocationUpdate` di `lib/services/driver_tracking_service.dart`) **tanpa autentikasi** — cuma percaya `karyawan_id`/`email` yang dikirim client, siapapun bisa POST data GPS palsu buat ID manapun. `POST /api-tms/tracking/update` (guard `tms-update-tracking`) adalah pengganti yang proper — auth via cookie session yang sudah ada di `GeuApiClient`.

**Scope pertanyaan:** apakah migrasi `LocationTrackingService`/`DriverTrackingService` yang SUDAH JALAN sekarang (kirim heartbeat GPS tiap 30-100m/60 detik) ke endpoint baru ini termasuk scope task ini, atau cuma fitur BARU (lihat peta) yang dikerjakan dan kirim-GPS lama dibiarkan jalan seperti sekarang? **Konfirmasi ke user dulu sebelum ubah jalur kirim GPS yang sudah production** — itu jalur kritis, jangan diubah tanpa tahu dampaknya ke semua driver aktif.

---

## 3. Role & Access Gating

### 3.1 Sisi mobile (UI gating — bukan security boundary, cuma UX)

Tambah field baru di `DashboardAccess` (`lib/services/dashboard_access_service.dart`) kalau backend `GET /api-auth/my-dashboard-access` sudah/bisa expose flag baru, atau — kalau gak mau ubah endpoint itu — cek role name langsung dari `UserStorage.getUser()['groups']` mirip cara `RoleManagementService` fallback, cocokkan ke whitelist:

```dart
const kDriverMapAdminRoles = ['developer', 'super user', 'koordinator logistik'];
```

(daftar ini **harus sama** dengan `$allowed_roles` di `erpmysql/application/controllers/Driver_map.php` — kalau nanti ada role baru ditambah di web, update juga di sini)

- Kalau role user ada di `kDriverMapAdminRoles` → tampilkan **Admin Map View** (semua driver).
- Kalau role-nya "driver" (cek pola yang sama kayak `RoleType.driver` di `role_management_service.dart`) → tampilkan **My Route View** (diri sendiri).
- Selain itu → sembunyikan menu ini sama sekali.

### 3.2 Sisi backend (real security boundary)

**WAJIB dicek** saat baca source Go handler: apakah `GET /api-tms/tracking/live` (guard cuma `auth`, bukan permission spesifik) benar-benar membatasi hasil berdasarkan role, atau literally return SEMUA user aktif ke SIAPAPUN yang login (termasuk driver biasa)? Kalau iya yang kedua — itu bug keamanan (driver A bisa lihat lokasi live driver B, C, dst tanpa harus admin). Kalau ternyata begitu, minta tambahkan permission guard (mis. `tms-read-tracking-all` atau reuse `tms-read-mapping`) di endpoint itu sebelum dipakai di app, atau filter di FE aja sebagai mitigasi sementara (tidak ideal, endpoint publiknya tetap bocor kalau di-hit langsung).

Sama buat `GET /api-tms/tracking/history` — pastikan kalau driver biasa manggil dengan `user_id` bukan dirinya sendiri, backend nolak (403), bukan cuma percaya param dari client.

---

## 4. Data yang Dibutuhkan

### 4.1 Peta live semua driver (Admin View)

**Endpoint kandidat:** `GET /api-tms/tracking/live`

**Field yang DIBUTUHKAN per driver** (cocokkan sama field kunci di sini, kalau Go API belum punya sebagian, catat sebagai gap):

| Field | Tipe | Keterangan |
|---|---|---|
| `karyawan_id` / `id` | string/int | ID user |
| `name` | string | **Nama asli**, bukan email (di web sempat ada bug field ini isinya email — pastikan Go API sudah bener) |
| `jabatan` | string | Nama role/jabatan |
| `lat`, `lng` | float | Posisi terkini |
| `speed` | float | km/h, dibulatkan 1 desimal di server (jangan kirim raw float panjang kayak `5.7757` — ada bug serupa pernah terjadi di web) |
| `heading` | float\|null | 0-360°, buat rotasi icon arrow kalau lagi gerak |
| `status` | string | `online` (<5 menit) / `idle` (5-15 menit) / `offline` (>15 menit) — threshold ini dari `v_driver_latest_position` di DB, ikuti yang sama |
| `battery_level` | int\|null | |
| `app_version` | string\|null | |
| `minutes_ago` | int | |
| `is_monitoring` | bool | Lagi dipantau foto dual-camera atau gak |
| `vehicle_plat`, `vehicle_jenis`, `vehicle_merk` | string\|null | Kendaraan terakhir dipakai (dari `t_pickup.fleet_id` terbaru) |

### 4.2 Riwayat rute + estimasi tujuan (Show Route / My Route)

**Endpoint kandidat:** `GET /api-tms/tracking/history` (rute GPS aktual) + `GET /api-tms/mapping/data` (surat jalan/tujuan hari itu — **kemungkinan ini yang setara** dengan fitur "pending deliveries" di web).

Params yang dibutuhkan: `driver_id` (admin only — driver biasa gak kirim ini, backend infer dari token), `date_from`, `date_to`.

**Rute GPS aktual** — per titik butuh: `lat`, `lng`, `timestamp`, `speed`, `heading`, `address`. Dipakai buat garis biru + klik-titik-lihat-jam (lihat 4.5.3).

**Surat jalan / tujuan** — per item butuh:

| Field | Keterangan |
|---|---|
| `surat_jalan_kode`, `pickup_kode` | |
| `status` | `progress` \| `pickup` \| `done` \| `cancel` — **tampilkan SEMUA status**, jangan cuma yang pending (lihat 4.5.2) |
| `supplier_name`, `alamat` | |
| `lat`, `lng` | Koordinat tujuan (parse dari `m_supplier.gps` kalau backend belum expose sebagai number — field itu string bebas `"lat,lng"`, kadang ada spasi, kadang cuma `"-"`, kadang malah link Google Maps — **backend harus parse defensif**, jangan asumsikan selalu valid) |
| `driver_id`, `driver_name` | Siapa pemilik job ini (penting kalau scope-nya gudang, bukan cuma driver ini — lihat 4.5.1) |
| `dwell_minutes`, `dwell_formatted` | Lihat 4.5.4 — kemungkinan besar `/api-tms/mapping/data` BELUM punya ini, perlu ditambah |

### 4.3 Kirim lokasi (kalau migrasi jalur kirim disepakati — lihat section 2)

`POST /api-tms/tracking/update` — body kemungkinan mirip payload lama di `driver_tracking_service.dart::_buildLocationPayload()`: `latitude`, `longitude`, `accuracy`, `speed`, `heading`, `altitude`, `battery_level`, `app_version`, `device_info`, `timestamp`. Konfirmasi field exact dari source Go, jangan asumsi sama persis.

### 4.4 Auth header

Pakai `GeuApiClient.instance` (`lib/services/geu/geu_api_client.dart`) untuk semua call baru — itu sudah handle cookie session + auto-refresh-on-401 + response envelope. **Jangan** pakai `http.post` mentah kayak `driver_tracking_service.dart` (pola lama, gak ada auth).

### 4.5 Business logic referensi (dari implementasi web yang sudah tervalidasi)

Ini bukan wajib dipakai persis — cuma acuan supaya perilaku mobile & web konsisten. Kalau `/api-tms/mapping/data` sudah handle semua ini dengan caranya sendiri, cukup verifikasi hasilnya konsisten (terutama 4.5.1, itu aturan bisnis yang gampang salah kalau reinvent).

#### 4.5.1 Aturan siapa lihat surat jalan siapa (PENTING, gampang salah)

Role "driver" di app ini **TIDAK** dibatasi ke pickup miliknya sendiri — tapi ke **semua surat jalan gudang tempat dia jadi anggota** (`m_gudang.member_ids`), sama persis kayak kalau dia login sendiri & buka halaman `/surat_jalan` di web. Ini sudah diverifikasi ke data real: driver "Anata Tri Hardiansyah" (anggota Gudang Malang) yang buka rute-nya sendiri bakal lihat juga job driver lain se-gudang (mis. "Bagus Aditya"), bukan cuma job dia.

Urutan pengecekan (replika dari `Surat_jalan::getAccessFilters()` di web, sudah di-port ke `M_driver_map::getDriverAccessScope()`):
1. Kalau user punya permission `read-all-surat-jalan` → lihat semua, gak difilter.
2. Kalau role dia alias `driver` → filter ke `gudang_id IN (gudang tempat dia member)`.
3. Kalau dia PIC gudang (`m_gudang.pic_id = user_id`) → filter ke gudang yang dia PIC-in.
4. Fallback → filter ke `driver_id` miliknya sendiri.

**Kalau job itu BUKAN miliknya sendiri** (driver lain di gudang yang sama), tandai `is_own: false` di response, dan di UI jangan masukkan ke estimasi rute (lihat 4.5.3) — cukup tampil sebagai pin konteks, dilabeli nama driver aslinya.

#### 4.5.2 Tampilkan semua status, bukan cuma pending

Awalnya fitur web ini cuma nampilin status `progress`/`pickup` (query `sjd.status NOT IN ('done','cancel')`). User minta diubah supaya `done` dan `cancel` juga ikut tampil, dikasih warna beda, biar kelihatan histori lengkap hari itu:

| Status | Warna |
|---|---|
| `progress` | Ungu `#8b5cf6` |
| `pickup` | Teal `#17a2b8` |
| `done` | Hijau `#28a745` |
| `cancel` | Abu-abu `#6c757d` |

#### 4.5.3 Estimasi rute (garis merah)

Garis putus-putus merah (`#dc3545`, dashed) dari posisi terkini driver → tiap titik tujuan, **cuma untuk stop yang**:
- `is_own == true` (bukan job driver lain di gudang yang sama), DAN
- `status` masih `progress` atau `pickup` (bukan `done`/`cancel` — gak masuk akal narik estimasi rute ke tempat yang udah kelar atau dibatalkan).

Garis biru historis (`#007bff`, solid, weight lebih tebal dari estimasi) = rute GPS aktual, terpisah dari garis merah.

**Titik pada garis biru bisa di-tap** → cari titik terdekat dari lokasi tap, tampilkan `timestamp`, `speed`, `address` di titik itu (fitur "jam berapa dia di situ" — sudah ada di web, `onRouteLineClick()` di `map_tracking.php`).

#### 4.5.4 Dwell time — berapa lama driver di satu lokasi

Buat tiap stop miliknya sendiri (`is_own: true`) yang punya koordinat valid: cocokkan titik-titik GPS historis driver (dari 4.2) yang jaraknya ≤150 meter (radius toleransi buat akurasi GPS HP yang kadang meleset 100-200m) dari koordinat tujuan itu. Total-kan durasi (`max_timestamp - min_timestamp` dari titik-titik yang match), dengan aturan: kalau ada jeda >10 menit antar titik yang match (driver sempat pergi & balik lagi), hitung sebagai kunjungan terpisah lalu **dijumlah** (bukan diambil yang terpanjang aja).

Referensi implementasi PHP (`DriverMapService::computeDwellMinutes()`), port logic-nya kalau mau dipindah ke Go/dihitung di client:

```php
private function computeDwellMinutes($trackPoints, $targetLat, $targetLng, $radiusMeters = 150) {
    $timestamps = [];
    foreach ($trackPoints as $p) {
        $dist = haversineMeters($targetLat, $targetLng, $p['latitude'], $p['longitude']);
        if ($dist <= $radiusMeters) $timestamps[] = strtotime($p['created_at']);
    }
    if (count($timestamps) < 2) return 0;
    sort($timestamps);
    $maxGapSeconds = 10 * 60;
    $totalSeconds = 0;
    $clusterStart = $timestamps[0];
    $prev = $timestamps[0];
    for ($i = 1; $i < count($timestamps); $i++) {
        $gap = $timestamps[$i] - $prev;
        if ($gap > $maxGapSeconds) {
            $totalSeconds += ($prev - $clusterStart);
            $clusterStart = $timestamps[$i];
        }
        $prev = $timestamps[$i];
    }
    $totalSeconds += ($prev - $clusterStart);
    return (int) round($totalSeconds / 60);
}
```

Sudah divalidasi ke data real: driver `badasexp123@gmail.com` dapat 30 menit di "Ramen Ya! X Sushiya Royal Plaza" — cocok sama posisi live dia saat itu.

**Kalau memilih hitung ini di CLIENT (Flutter) daripada backend**, butuh raw GPS points dikirim ke device (data lebih besar) — pertimbangkan hitung di backend saja dan cuma kirim hasil `dwell_minutes` per stop, lebih hemat bandwidth & battery.

---

## 5. Flutter Implementation

### 5.1 Dependencies (sudah ada di `pubspec.yaml`, gak perlu nambah)

```yaml
flutter_map: ^8.3.1   # pakai ini, BUKAN google_maps_flutter — biar visual konsisten sama web (Leaflet + basemap gray) & gak butuh API key/billing
http: ^1.6.0           # tapi pakai GeuApiClient (dio-based), bukan http package langsung
geolocator: ^13.0.2
```

Basemap: samakan sama web — CARTO Positron (gray, minimalis):
```dart
TileLayer(
  urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
  subdomains: const ['a', 'b', 'c', 'd'],
  userAgentPackageName: 'com.geu.onelink', // sesuaikan package name app
)
```

### 5.2 Screens

**`DriverMapScreen`** (entry point, role-gated sesuai section 3.1):
- Kalau admin role → render `AdminDriverMapView`.
- Kalau driver role → langsung render `DriverRouteDetailView(driverId: self)`, skip pemilihan driver.

**`AdminDriverMapView`**:
- `flutter_map` full-screen, marker per driver (warna status: online `#28a745` / idle `#ffc107` / offline `#dc3545`, sama kayak web).
- Marker yang `speed > 0` (lagi gerak): ganti icon jadi panah navigasi di-rotate sesuai `heading` (asset sama kayak web: `https://geu.fekusa.com/assets/icon/icon-navigation.png`, arrow default menghadap atas/utara, `heading` derajat searah jarum jam dari utara — di Flutter pakai `Transform.rotate(angle: heading * pi / 180)`).
- Badge merah kecil berkedip (pulsing) di marker yang `is_monitoring == true`.
- Bottom sheet / list scrollable: daftar semua driver (nama, jabatan, kendaraan, status, speed, battery). Tap item atau marker → push ke `DriverRouteDetailView(driverId: ...)`.
- Polling: refresh tiap **15-20 detik** (lebih longgar dari web yang 10 detik — pertimbangan baterai/data HP), **pause polling saat screen gak visible** (pakai `WidgetsBindingObserver` / route-aware, jangan polling terus di background).

**`DriverRouteDetailView`** (dipakai admin lihat driver lain, ATAU driver lihat dirinya sendiri):
- Date range picker (default: hari ini) — kirim `date_from`/`date_to` ke endpoint 4.2.
- Map: garis biru rute aktual (klik titik → popup jam/speed/address, lihat 4.5.3), garis merah dashed estimasi (cuma stop `is_own && pending`), pin bernomor per tujuan (warna ikut status per 4.5.2).
- List di bawah/sebelah map: tiap surat jalan — nomor urut kalau `is_own`, icon "orang" kalau bukan (job driver lain segudang) + nama drivernya, badge status berwarna, badge dwell time (`⏱️ Terpantau X Menit di lokasi`) kalau ada.
- Kalau admin: tombol "Keluar" balik ke `AdminDriverMapView`. Kalau driver liat diri sendiri: gak perlu tombol keluar (ini home-nya).

### 5.3 State management

Ikuti pola yang sudah dipakai di project ini (cek screen lain yang mirip kompleksitasnya, misal `visit_plan_screen.dart` atau provider pattern yang ada di `promptintegrate.txt`) — jangan introduce state management baru (Bloc/Riverpod) kalau project ini sudah konsisten pakai Provider.

---

## 6. Non-Functional Requirements

- **Battery/data**: polling admin view 15-20 detik, berhenti total saat app di background (`AppLifecycleState.paused`) atau pindah screen.
- **Permission**: fitur ini cuma BACA lokasi driver lain (admin) atau lokasi sendiri (driver) — gak perlu request location permission baru di sisi FE untuk MENAMPILKAN peta (beda dari permission GPS buat MENGIRIM lokasi yang sudah ada). Driver view tetap butuh location permission existing kalau mau nampilin "posisi saya sekarang" real-time, tapi itu udah di-handle `LocationTrackingService`.
- **Empty/error states**: driver tanpa surat jalan hari itu → tampilkan state kosong yang jelas ("Tidak ada surat jalan hari ini"), bukan spinner nyangkut. Endpoint gagal/network error → retry button, jangan silent fail.
- **Konsistensi visual**: warna & style HARUS sama kayak web (lihat 4.5.2 & section 5.2) — supaya admin yang biasa lihat web gak bingung pas buka versi mobile.

---

## 7. Testing Checklist

| # | Test Case | Expected |
|---|-----------|----------|
| 1 | Login sebagai Developer/Super User/Koordinator Logistik | Lihat Admin Map View, semua driver muncul |
| 2 | Login sebagai driver biasa | Langsung ke My Route View, cuma data sendiri (+ tim gudang kalau ada) |
| 3 | Login sebagai role lain (bukan admin/driver) | Menu ini gak muncul sama sekali |
| 4 | Tap driver yang lagi bergerak | Icon arrow ter-rotate sesuai heading, update posisi live |
| 5 | Buka rute driver dengan surat jalan campur status (progress+done+cancel) | Semua tampil, warna beda per status |
| 6 | Buka rute driver dengan surat jalan job driver lain segudang | Pin/list item itu muncul, dilabeli nama driver asli, TIDAK masuk garis estimasi merah |
| 7 | Tap titik di garis rute biru | Popup jam + speed + address |
| 8 | Driver B coba akses riwayat rute Driver A lewat API langsung (bukan lewat UI) | Backend tolak 403 kalau Driver B bukan admin (verifikasi ini bukan cuma dicegah di UI) |
| 9 | Sinyal HP hilang saat admin lagi lihat live map | Gak crash, tampilkan indikator "gagal update", retry otomatis pas sinyal balik |
| 10 | Driver tanpa surat jalan hari itu | Empty state jelas, bukan loading nyangkut |

---

## 8. Out of Scope / Perlu Dikonfirmasi ke User Sebelum Mulai

- Migrasi jalur KIRIM GPS (`LocationTrackingService`) ke `/api-tms/tracking/update` — lihat section 2, ini keputusan terpisah karena menyentuh jalur production yang sudah jalan buat semua driver aktif.
- Apakah butuh mode offline (lihat peta tanpa internet, data cache terakhir) — belum dibahas, defaultnya asumsi selalu online.
- True road-based routing (rute mengikuti jalan asli, bukan garis lurus) buat garis estimasi merah — versi web pakai garis lurus (straight-line) karena gak ada API routing berbayar terpasang. Kalau mobile mau lebih akurat, perlu keputusan pakai layanan apa (OSRM self-hosted / Google Directions berbayar / tetap garis lurus).
