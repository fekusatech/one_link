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
| `status` | string | `online` (≤5 menit) / `idle` (≤15 menit) / `offline` (>15 menit) — threshold persis dari `v_driver_latest_position` di DB (`CASE WHEN minutes_ago<=5 THEN 'online' WHEN minutes_ago<=15 THEN 'idle' ELSE 'offline'`), ikuti yang sama |
| `battery_level` | int\|null | |
| `app_version` | string\|null | |
| `minutes_ago` | int | |
| `is_monitoring` | bool | Lagi dipantau foto dual-camera atau gak (lihat 4.6 soal scope fitur monitoring) |
| `vehicle_plat`, `vehicle_jenis`, `vehicle_merk` | string\|null | Kendaraan terakhir dipakai (dari `t_pickup.fleet_id` terbaru) |
| `address` | string\|null | Alamat hasil reverse-geocode posisi terkini — ditampilkan di popup marker web ("Location: ..."), reverse-geocode di-throttle server (cuma dipanggil ulang kalau pindah >100m atau >10 menit sejak terakhir, biar gak boros API), jangan hitung ulang per-request di FE |

### 4.2 Riwayat rute + estimasi tujuan (Show Route / My Route)

**Endpoint kandidat:** `GET /api-tms/tracking/history` (rute GPS aktual) + `GET /api-tms/mapping/data` (surat jalan/tujuan hari itu — **kemungkinan ini yang setara** dengan fitur "pending deliveries" di web).

Params yang dibutuhkan: `driver_id` (admin only — driver biasa gak kirim ini, backend infer dari token), `date_from`, `date_to`.

**Rute GPS aktual** — per titik butuh: `lat`, `lng`, `timestamp`, `speed`, `heading`, `address`. Dipakai buat garis biru + klik-titik-lihat-jam (lihat 4.5.3).

**Idle stops (titik berhenti umum, TERPISAH dari dwell-time di 4.5.4)** — ini gampang ketuker jadi tegasin: `idle_stops` dihitung dari clustering titik GPS di sepanjang rute yang jaraknya <35 meter dan durasinya ≥3 menit — **di MANAPUN** dia berhenti, bukan cuma di titik tujuan surat jalan (misal berhenti buat isi bensin, istirahat, macet). Beda konsep dari 4.5.4 yang khusus ngecek "berapa lama di titik tujuan yang SUDAH DIKETAHUI". Web nampilin ini sebagai marker oranye ⏱️ terpisah dari pin tujuan (ungu/hijau/dst), plus toast ringkasan pas rute selesai dimuat ("Total Titik Berhenti: N Lokasi, Total Waktu Ngetem: Y"). Per item butuh: `lat`, `lng`, `address`, `start_time`, `end_time`, `duration_minutes`, `formatted_duration`. Referensi algoritma clustering-nya di `DriverMapService::getFormattedRouteData()` (bagian `$cluster`/`haversineMeters` di kode PHP, radius 35m beda dari radius dwell-time yang 150m — jangan disamain).

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

### 4.6 Monitoring foto dual-camera — KEPUTUSAN SCOPE, belum diputuskan

Di web, `driver_map` juga jadi tempat admin **menyalakan/mematikan monitoring foto** (dual-camera + screenshot HP driver, interval bisa diatur) dan **melihat galeri foto** hasil monitoring (`openMonitoringModal`, `saveMonitoringCommand`, `openMonitoringLogs` di `map_tracking.php`). Badge `is_monitoring` di section 4.1 nunjukkin status ini, tapi cuma nunjukkin — gak termasuk kontrolnya.

**Ini fitur terpisah secara konsep** (monitoring privacy-sensitive driver, bukan sekadar lihat posisi) — putuskan dulu ke user apakah:
- (a) Ikut di-port ke mobile juga (admin bisa nyalain/liat galeri dari HP), atau
- (b) Di luar scope task ini, cukup tampilkan badge status aja (read-only), kontrolnya tetep cuma via web.

**Jangan asumsikan salah satu** — ini keputusan produk (siapa yang boleh trigger monitoring dari HP, bukan cuma dari komputer kantor), bukan keputusan teknis semata.

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
- Badge merah kecil berkedip (pulsing) di marker yang `is_monitoring == true` (lihat 4.6 soal scope kontrolnya).
- **Live breadcrumb trail** — garis biru tipis (`#007bff`, weight 3, opacity 0.6, beda dari garis rute historis yang lebih tebal) yang otomatis nambah ngikutin driver yang lagi gerak, dibangun dari histori posisi tiap kali polling (bukan minta data baru ke server — murni olah data yang udah di-fetch). Reset/hilang kalau driver-nya offline atau ke-filter keluar dari tampilan. Ini fitur web yang sengaja dibuat biar admin gak perlu buka detail rute cuma buat lihat "dia baru aja dari mana" — port juga ke mobile, gratis (gak nambah beban API).
- **Filter bar** (di atas map atau di list panel): kategori (Driver/Armada, Sales/RO/CRO, Warehouse & Logistik, Admin/Management — dicocokkan dari substring nama jabatan, lihat `getFilteredDrivers()` di web buat aturan persisnya), platform (Mobile App Only / Web Only — beda dari ada-tidaknya `battery`/`app_version`), search text (nama/email/jabatan), toggle "Hide Offline". Semua filter ini murni client-side di atas data yang sudah di-fetch, gak query ulang ke server.
- **Legend** (collapsible): warna status driver, arti badge monitoring, arti garis biru live trail — biar user baru ngerti tanpa nanya.
- List/bottom sheet: daftar driver (nama, jabatan, kendaraan, status, speed, battery), ikut ter-filter sesuai filter bar di atas. Tap item atau marker → push ke `DriverRouteDetailView(driverId: ...)`.
- Kontrol refresh: toggle auto-refresh on/off + tombol refresh manual (jangan cuma auto-polling tanpa kontrol user, samain UX-nya kayak web).
- Polling: refresh tiap **15-20 detik** (lebih longgar dari web yang 10 detik — pertimbangan baterai/data HP), **pause polling saat screen gak visible** (pakai `WidgetsBindingObserver` / route-aware, jangan polling terus di background).
- *(Opsional/nice-to-have, bukan prioritas)*: web ada toggle tampilan Peta/Tabel (data table semua driver). Di mobile, layar kecil bikin tabel penuh kolom kurang ergonomis — kalau mau di-port, pertimbangkan versi ringkas (list card yang lebih detail) daripada tabel literal. Boleh di-skip di iterasi pertama.

**`DriverRouteDetailView`** (dipakai admin lihat driver lain, ATAU driver lihat dirinya sendiri):
- Date range picker (default: hari ini) — kirim `date_from`/`date_to` ke endpoint 4.2.
- Map, beberapa layer sekaligus (jangan sampai ketuker pas implementasi):
  - Garis **biru solid** = rute GPS aktual (weight lebih tebal dari live trail di admin view), titik bisa di-tap → popup jam/speed/address (lihat 4.5.3).
  - Marker **hijau "S"** di titik awal rute, **merah "E"** di titik akhir (start/end hari itu).
  - Marker **oranye ⏱️** di tiap idle stop (lihat 4.2) — beda dari pin tujuan surat jalan, ini titik berhenti UMUM di sepanjang rute.
  - Garis **merah dashed** estimasi (cuma stop `is_own && pending`, lihat 4.5.3).
  - Pin bernomor ungu/berwarna per tujuan surat jalan (warna ikut status per 4.5.2).
- Toast/banner ringkasan begitu rute selesai dimuat: total idle stop + total waktu berhenti (dari `idle_stops`, section 4.2) — bukan dwell-time per tujuan, ini ringkasan keseluruhan hari itu.
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
| 11 | Driver berhenti >3 menit di lokasi yang BUKAN tujuan surat jalan (misal istirahat) | Muncul marker oranye idle stop, beda dari pin tujuan surat jalan |
| 12 | Terapkan filter kategori/platform/search/hide-offline di Admin Map View | List & marker ke-filter sesuai, gak ada request baru ke server (murni client-side) |
| 13 | Driver A jalan terus di Admin Map View tanpa buka detail rutenya | Garis biru tipis (live trail) otomatis nambah ngikutin dia, tanpa perlu tap apapun |
| 14 | Filter/search diterapkan lalu driver yang lagi difokuskan (kalau ada state serupa) ke-exclude oleh filter | Pastikan behavior didefinisikan — jangan sampai state fokus rusak diam-diam gara-gara filter (bug serupa pernah kejadian di versi web, sudah diperbaiki di sana — lihat `onFilterChange()` yang bypass filter biasa saat mode fokus aktif) |

---

## 8. Out of Scope / Perlu Dikonfirmasi ke User Sebelum Mulai

- Migrasi jalur KIRIM GPS (`LocationTrackingService`) ke `/api-tms/tracking/update` — lihat section 2, ini keputusan terpisah karena menyentuh jalur production yang sudah jalan buat semua driver aktif.
- Apakah butuh mode offline (lihat peta tanpa internet, data cache terakhir) — belum dibahas, defaultnya asumsi selalu online.
- True road-based routing (rute mengikuti jalan asli, bukan garis lurus) buat garis estimasi merah — versi web pakai garis lurus (straight-line) karena gak ada API routing berbayar terpasang. Kalau mobile mau lebih akurat, perlu keputusan pakai layanan apa (OSRM self-hosted / Google Directions berbayar / tetap garis lurus).
