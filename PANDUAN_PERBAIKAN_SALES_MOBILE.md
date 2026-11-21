# Panduan Perbaikan Modul Sales — crm-mobile

Dokumen eksekusi untuk memperbaiki temuan di `AUDIT_SALES_MOBILE_VS_CRM_REACT.md`.
Ditulis supaya bisa dikerjakan langsung (oleh manusia maupun AI lain) **tanpa perlu
menebak** kontrak API atau menerka-nerka desain.

Tanggal: **22 Agustus 2026**
Baseline commit: `a7d1d19`

---

## ATURAN MAIN (baca dulu sebelum menyentuh kode)

### 1. UI/UX yang ada WAJIB dipertahankan
Semua perbaikan di bagian **A–C** adalah perbaikan *data layer*. **Jangan** mengubah:
- Susunan halaman wizard form supplier (3 halaman: Informasi Dasar → Lokasi → Informasi Keuangan)
- Indikator progres titik-titik di atas wizard
- Tombol navigasi (`Kembali` / `Selanjutnya` / `Simpan`)
- Layout `SupplierListScreen`: AppBar, search field (`'Cari supplier atau kontak person...'`),
  dua dropdown filter, kartu supplier, FAB tambah, empty state
- Warna, `AppColors`, `AppTextStyles`, radius, spacing

Usulan UI/UX baru **dipisah** di bagian **D**, dan itu opsional — kerjakan hanya
setelah A–C selesai dan diuji.

### 2. Dilarang membuat data palsu sebagai fallback
Ini aturan keras di proyek ini. Sudah dua kali kejadian: skor driver hardcoded, dan
`_loadDummyData()` di form supplier. Efeknya sama-sama buruk — **fitur terlihat jalan
padahal rusak**, dan bug-nya baru ketahuan berminggu-minggu kemudian.

Kalau API gagal: tampilkan **error state yang jujur + tombol Coba Lagi**. Jangan pernah
menambal dengan angka/daftar karangan.

### 3. Verifikasi sebelum klaim selesai
- `flutter analyze` harus bersih untuk file yang disentuh
- Uji langsung ke API (contoh perintah `curl` ada di Lampiran A) — jangan berasumsi
  endpoint berjalan hanya karena ada di router
- Kalau tidak sempat menguji di device, **katakan apa adanya**, jangan tulis "sudah dites"

### 4. Jangan hardcode kredensial
Termasuk untuk keperluan tes. Ambil dari sesi yang sedang login.

---

## PETA MASALAH SINGKAT

```
┌─ SupplierListScreen (Daftar Supplier)          ✅ SEHAT
│    └─ SupplierListService → /api/suppliers/         (Go, 200)
│
├─ AddSupplierScreenSimple (FAB "+" tambah)      🔴 RUSAK
│    └─ SupplierFormProvider
│         └─ SupplierApiService → /api-supplier/*     (404 semua)
│              └─ gagal → _loadDummyData()            ← menyamarkan kerusakan
│
└─ SupplierListProvider                          ⚪ DEAD CODE
     (di-create di sales_dashboard_screen, tak pernah dibaca)
```

---

# BAGIAN A — Perbaiki Form Tambah Supplier (P0)

## A.0 Kenapa ini tidak bisa sekadar ganti URL

Empat jebakan. Kalau hanya prefix URL yang diganti, aplikasi tetap crash:

**Jebakan 1 — envelope `status` beda tipe.**
`lib/models/api_response.dart`:
```dart
final bool status;
...
status: json['status'] ?? false,
```
Go mengembalikan `"status": "success"` — sebuah **String**. Memasukkan String ke
parameter `bool` → `TypeError` saat runtime.

**Jebakan 2 — `City`/`District`/`Village` menuntut field yang tidak dikirim Go.**
`lib/models/geographic_models.dart`:
```dart
idProvinsi: int.parse(json['id_provinsi'].toString()),   // City
idKota:     int.parse(json['id_kota'].toString()),       // District
idKecamatan:int.parse(json['id_kecamatan'].toString()),  // Village
```
Go hanya mengirim `{id, name}`. `int.parse('null')` → **FormatException**.

**Jebakan 3 — `employees` sekarang terpaginasi.**
Lama: satu list utuh. Sekarang `/api/suppliers/dropdowns` mengembalikan
`employees: null`, dan datanya pindah ke `/api/suppliers/employees` yang
**terpaginasi** (`total_records: 1658`, default per halaman kecil). Memuat semuanya
sekaligus itu boros dan lambat.

**Jebakan 4 — nama field payload simpan berbeda.**
`Supplier.toJson()` mengirim `pic`, `kategori`, `bank_rek`, dan `price` sebagai
**String**. Go `CreateSupplierRequest` menuntut `pic_id`, `kategori_id`,
`bank_rek_id`, dan `price` sebagai **angka**.

## A.1 Kontrak API tujuan (sudah diverifikasi live, 22 Agu 2026)

Semua di bawah `https://apipi.greenenergiutama.co.id`, butuh cookie sesi
(otomatis kalau pakai `GeuApiClient`). Envelope selalu:
```json
{ "status": "success", "code": 200, "message": "...", "data": <payload>, "timestamp": "..." }
```

### `GET /api/suppliers/dropdowns`
Satu panggilan untuk hampir semua dropdown:
```json
{ "data": {
  "jenis_supplier":    [{ "id": 2,  "name": "POO B2B CONTRACT", "prefix": "2" }],   // 4 item
  "kategori_supplier": [{ "id": 25, "name": "Amartha" }],                            // 57 item
  "satuan":            [{ "id": 7,  "name": "Botol 1,5L" }],                         // 10 item
  "kemasan":           [{ "id": 6,  "name": "UCO Kaleng (18 Liter)" }],              // 5 item
  "provinces":         [{ "id": 11, "name": "ACEH", "name_en": "Aceh" }],            // 34 item
  "banks":             [{ "id": 81, "nama_bank": "Allo Bank", "kode_bank": "567" }], // 91 item
  "employees":         null,                                                          // ← selalu null
  "gudang":            [{ "id": 40, "name": "Aeropolis" }]                           // 17 item
}}
```
> 🎉 **Kabar baik:** nama key-nya **persis sama** dengan yang sudah dibaca
> `SupplierFormProvider.loadMasterData()` sekarang (`data['jenis_supplier']`,
> `data['banks']`, dst). Dan `dropdown_models.dart` juga sudah cocok
> (`nama_bank`, `kode_bank`, `prefix`). Jadi bagian ini nyaris tanpa perubahan
> logika — hanya URL dan penanganan `employees`.

### Cascading wilayah — semua mengembalikan `data: [{id, name}]`
| Endpoint | Contoh | Hasil |
|---|---|---|
| `GET /api/suppliers/cities/:province_id` | `/cities/35` | 38 item |
| `GET /api/suppliers/districts/:city_id` | `/districts/3573` | 5 item |
| `GET /api/suppliers/villages/:district_id` | `/villages/3573030` | 11 item |

### `GET /api/suppliers/employees?search=&page=&limit=`
**Terpaginasi**:
```json
{ "data": {
  "data": [{ "id": 159012, "name": "AFIIFAH DURROTUL HIKMAH" }],
  "pagination": { "current_page": 1, "per_page": 2, "total_records": 1658,
                  "total_pages": 829, "has_next": true, "has_prev": false }
}}
```

### `POST /api/suppliers/` — buat supplier
Wajib: `jenis`, `name`, `phone`, `jabatan`, `karyawan`, `nama_rek`, `nomor_rek`.
Opsional: `pic_id`, `kategori_id`, `provinsi_id`, `kota_id`, `kecamatan_id`,
`desa_id`, `alamat`, `gps`, `bank_rek_id`, `status_id`, `price` (angka),
`price_satuan`, `jenis_uco`, `siklus`, `poin`, `gudang_terdekat_id`.

Balasan `201` + objek supplier lengkap. Konflik duplikat → `409`.

### `PUT /api/suppliers/:id` — ubah supplier
Semua field opsional (partial update). Tambahan `active`.
Untuk user non-superuser, server bisa membalas `200` dengan pesan
*"Edit submitted for approval"* — **bukan** perubahan langsung. UI harus
membedakan dua kondisi ini (lihat A.5).

### `POST /api/suppliers/validate-account`
### `PUT /api/suppliers/:id/toggle-status`

## A.2 Langkah 1 — perbaiki `ApiResponse` agar menerima envelope Go

`lib/models/api_response.dart`. Terima **dua-duanya** (bool lama & string Go) supaya
pemanggil lain yang masih memakai model ini tidak ikut rusak:

```dart
factory ApiResponse.fromJson(
  Map<String, dynamic> json,
  T Function(dynamic)? fromJsonT,
) {
  // Go REST API mengirim status berupa string ("success"/"error"), sementara
  // API PHP lama mengirim boolean. Terima keduanya supaya pemanggil lama
  // tidak ikut rusak saat endpoint dimigrasi satu per satu.
  final rawStatus = json['status'];
  final ok = rawStatus is bool
      ? rawStatus
      : rawStatus.toString().toLowerCase() == 'success';

  return ApiResponse<T>(
    status: ok,
    message: json['message']?.toString() ?? '',
    data: json['data'] != null && fromJsonT != null
        ? fromJsonT(json['data'])
        : json['data'],
    errors: json['errors'] is Map<String, dynamic> ? json['errors'] : null,
  );
}
```

## A.3 Langkah 2 — longgarkan model geografis

`lib/models/geographic_models.dart`. Ubah `idProvinsi`/`idKota`/`idKecamatan` jadi
**nullable** dan berhenti memakai `int.parse` langsung:

```dart
// Endpoint Go /api/suppliers/cities|districts|villages hanya mengirim {id, name} —
// relasi ke induknya sudah tersirat dari parameter path yang kita minta, jadi
// field ini opsional. int.parse() sebelumnya membuat parsing gagal total.
idProvinsi: json['id_provinsi'] == null
    ? null
    : int.tryParse(json['id_provinsi'].toString()),
```
Terapkan pola yang sama untuk `City.idProvinsi`, `District.idKota`,
`Village.idKecamatan`. Ubah juga deklarasi field jadi `final int? idProvinsi;` dst,
lalu perbaiki pemakaiannya kalau ada yang error saat `flutter analyze`.

## A.4 Langkah 3 — tulis ulang `SupplierApiService` di atas `GeuApiClient`

File: `lib/services/api/supplier_api_service.dart`

**Kenapa pindah ke `GeuApiClient`:** service ini masih memakai paket `http` + `ApiService`
lama yang tidak membawa cookie sesi dan tidak punya auto-refresh saat `401`.
`GeuApiClient` (Dio) sudah menangani keduanya, dan itu yang dipakai semua service
GEU yang sehat. Contoh acuan yang sudah benar: `lib/services/supplier_list_service.dart`.

Pola per method:
```dart
import '../geu/geu_api_client.dart';

static Future<ApiResponse<List<City>>> getCities(int provinceId) async {
  try {
    final dio = await GeuApiClient.instance;
    final res = await dio.get('/api/suppliers/cities/$provinceId');
    final body = res.data as Map<String, dynamic>;
    if (body['status'] != 'success') {
      return ApiResponse(status: false, message: body['message']?.toString() ?? 'Gagal memuat kota');
    }
    final list = (body['data'] as List? ?? [])
        .map((e) => City.fromJson(e as Map<String, dynamic>))
        .toList();
    return ApiResponse(status: true, message: '', data: list);
  } catch (e) {
    return ApiResponse(status: false, message: _friendlyError(e));
  }
}
```

Tabel pemetaan lengkap:

| Method | Lama (404) | Baru |
|---|---|---|
| `getDropdownOptions()` | `GET /api-supplier/dropdown-options` | `GET /api/suppliers/dropdowns` |
| `getProvinces()` | `GET /api-supplier/provinces` | **hapus** — ambil dari `dropdowns.provinces` |
| `getJenisSupplier()` | `GET /api-supplier/jenis-supplier` | **hapus** — dari `dropdowns.jenis_supplier` |
| `getKategoriSupplier()` | `GET /api-supplier/kategori-supplier` | **hapus** — dari `dropdowns.kategori_supplier` |
| `getBanks()` | `GET /api-supplier/banks` | **hapus** — dari `dropdowns.banks` |
| `getSatuan()` | `GET /api-supplier/satuan` | **hapus** — dari `dropdowns.satuan` |
| `getCities(id)` | `GET /api-supplier/cities/:id` | `GET /api/suppliers/cities/:province_id` |
| `getDistricts(id)` | `GET /api-supplier/districts/:id` | `GET /api/suppliers/districts/:city_id` |
| `getVillages(id)` | `GET /api-supplier/villages/:id` | `GET /api/suppliers/villages/:district_id` |
| `getEmployees()` | `GET /api-supplier/employees` | `GET /api/suppliers/employees?search=&page=&limit=` **(tanda tangan berubah)** |
| `createSupplier()` | `POST /api-supplier/create` | `POST /api/suppliers/` |
| `updateSupplier(id)` | `POST /api-supplier/update/:id` | `PUT /api/suppliers/:id` |
| `toggleSupplierStatus(id)` | `PUT /api-supplier/toggle-status/:id` | `PUT /api/suppliers/:id/toggle-status` |
| `validateAccount()` | `POST /api-supplier/validate-account` | `POST /api/suppliers/validate-account` |
| `getSupplierDetail(id)` | `GET /api-supplier/detail/:id` | `GET /api/suppliers/:id` |
| `getSupplierList()` | `GET /api-supplier/list` | **hapus** — sudah ada di `SupplierListService` |

> Lima method yang ditandai "hapus" itu redundan: satu panggilan `dropdowns` sudah
> memuat semuanya, dan itu memang yang dipakai `loadMasterData()` sekarang.
> Menghapusnya mengurangi 5 request jaringan saat form dibuka.

Pesan error ramah (jangan tampilkan exception mentah ke user lapangan):
```dart
static String _friendlyError(Object e) {
  final s = e.toString().toLowerCase();
  if (s.contains('socket') || s.contains('connection')) return 'Tidak ada koneksi internet.';
  if (s.contains('timeout')) return 'Koneksi lambat, coba lagi.';
  if (s.contains('401')) return 'Sesi berakhir. Silakan masuk kembali.';
  if (s.contains('403')) return 'Anda tidak punya akses untuk data ini.';
  if (s.contains('409')) return 'Data supplier sudah terdaftar (duplikat).';
  return 'Gagal memuat data. Coba lagi.';
}
```

## A.5 Langkah 4 — perbaiki payload simpan

`lib/models/supplier_model.dart`. `toJson()` harus mengikuti nama field Go:

```dart
Map<String, dynamic> toJson() {
  return {
    'jenis': jenis,
    'name': name,
    'phone': phone,
    'jabatan': jabatan,
    'karyawan': karyawan,
    'nama_rek': namaRek,
    'nomor_rek': nomorRek,
    // Go memakai akhiran _id dan menerima angka, bukan string.
    'pic_id': picId,
    'kategori_id': kategoriId,
    'bank_rek_id': bankRekId,
    'provinsi_id': provinsiId,
    'kota_id': kotaId,
    'kecamatan_id': kecamatanId,
    'desa_id': desaId,
    'alamat': alamat,
    'gps': gps,
    'price': price,              // angka, JANGAN .toString()
    'price_satuan': priceSatuanId,
    'jenis_uco': jenisUco,
    'siklus': siklus,
    'poin': poin,
  }..removeWhere((_, v) => v == null);
}
```

`fromJson()` juga perlu disesuaikan — Go memakai `pic_id`/`kategori_id`/`bank_rek_id`,
dan yang penting **jangan** `int.parse` non-nullable untuk field yang bisa kosong:
```dart
picId: int.tryParse(json['pic_id']?.toString() ?? '') ?? 0,
kategoriId: json['kategori_id'] == null ? null : int.tryParse(json['kategori_id'].toString()),
bankRekId: int.tryParse(json['bank_rek_id']?.toString() ?? '') ?? 0,
```

**Tangani balasan "butuh approval".** Untuk `PUT`, server bisa membalas `200` dengan
`message: "Edit submitted for approval"` dan `data: null` — artinya perubahan
**belum** tersimpan, masih menunggu persetujuan. UI harus bilang jujur:
> "Perubahan dikirim untuk persetujuan atasan." (bukan "Berhasil disimpan")

## A.6 Langkah 5 — buang `_loadDummyData()`

`lib/providers/supplier_form_provider.dart`, sekitar baris 118–131 dan definisinya
di baris ~134.

Hapus seluruh method `_loadDummyData()` dan kedua pemanggilnya. Ganti jadi:
```dart
} else {
  _errorMessage = response.message;   // apa adanya, tanpa data karangan
}
} catch (e) {
  _errorMessage = 'Gagal memuat data master. Periksa koneksi lalu coba lagi.';
}
```

Tambahkan getter supaya UI bisa membedakan "kosong karena gagal" vs "kosong karena
memang tidak ada":
```dart
bool get masterDataFailed => _errorMessage != null && _jenisSupplier.isEmpty;
```

## A.7 Langkah 6 — `employees` yang terpaginasi

1658 karyawan tidak boleh dimuat sekaligus ke `DropdownButton`.

**Perubahan UI minimal** (tetap terasa seperti dropdown yang ada sekarang):
ganti `DropdownButtonFormField` untuk PIC menjadi `InkWell` + `InputDecorator` yang
tampilannya **identik** (border, label, ikon panah bawah sama), tapi saat ditekan
membuka bottom sheet pencarian:

```
┌─────────────────────────────────┐
│  Pilih PIC                   ✕  │
│  ┌───────────────────────────┐  │
│  │ 🔍 Cari nama karyawan...  │  │  ← debounce 400 ms → ?search=
│  └───────────────────────────┘  │
│  ─────────────────────────────  │
│  ○  AFIIFAH DURROTUL HIKMAH     │
│  ○  AGUS SETIAWAN               │
│  ●  DICKY ALLEN            ✓    │  ← terpilih
│  ○  ...                          │
│         (scroll → load next)     │  ← infinite scroll, page++
└─────────────────────────────────┘
```
- Debounce 400 ms sebelum memanggil API
- `limit: 20` per halaman, muat berikutnya saat scroll mendekati bawah
- Saat memuat: 3 baris skeleton (pola yang sama seperti sheet Detail Supplier
  yang sudah ada di `visit_plan_screen.dart`)
- Kosong: "Karyawan tidak ditemukan."
- Gagal: pesan + tombol "Coba Lagi"

Kalau ingin perubahan **paling minim**, alternatif yang dapat diterima: muat 1 halaman
pertama (limit 50) ke dropdown biasa dan tambahkan item terakhir *"Cari karyawan
lain…"* yang membuka sheet di atas. Tapi opsi bottom sheet lebih baik dan tetap
mempertahankan bentuk visual field-nya.

## A.8 Langkah 7 — bersihkan dead code

`lib/screens/sales_dashboard_screen.dart`, menu "Daftar Supplier":
```dart
onTap: () => Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => ChangeNotifierProvider(
      create: (_) => SupplierListProvider(),   // ← tidak pernah dibaca
      child: const SupplierListScreen(),
    ),
  ),
),
```
`SupplierListScreen` memakai `SupplierListService` langsung. Sederhanakan:
```dart
onTap: () => Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const SupplierListScreen()),
),
```
Lalu hapus `lib/providers/supplier_list_provider.dart` **setelah** memastikan
tidak ada pemakai lain (`grep -rn "SupplierListProvider" lib`).

## A.9 Uji terima Bagian A

- [ ] Buka form tambah supplier → semua dropdown terisi **dari server** (matikan
      internet sebentar untuk memastikan tidak ada lagi data dummy yang muncul)
- [ ] Provinsi → Kota → Kecamatan → Desa berjenjang tanpa crash
- [ ] Pencarian PIC menemukan karyawan di luar 20 pertama
- [ ] Simpan supplier baru → muncul di Daftar Supplier setelah refresh
- [ ] Mode pesawat → pesan "Tidak ada koneksi internet." + tombol Coba Lagi,
      **bukan** dropdown terisi data karangan
- [ ] `flutter analyze` bersih untuk semua file yang disentuh
- [ ] Verifikasi lewat `curl` bahwa supplier benar-benar masuk database

---

# BAGIAN B — Permission Gate untuk Daftar Supplier (P0)

Satu baris di `lib/screens/sales_dashboard_screen.dart`:
```dart
_CroMenuItem(
  title: 'Daftar Supplier',
  subtitle: 'Cari & perbarui data supplier',
  icon: Icons.edit_location,
  color: AppColors.accentOrange,
  permission: 'crm-read-supplier',   // ← TAMBAHKAN (menyamai sidebar web)
  onTap: ...
),
```

**Perlu diperhatikan:** ini akan **menyembunyikan** menu tersebut dari user yang tidak
punya `crm-read-supplier`. Sebelum rilis, cek dulu ke DB siapa saja yang terdampak:

```sql
-- Akun sales yang akan kehilangan menu Daftar Supplier
SELECT DISTINCT u.id, u.email, g.name AS jabatan
FROM s_users u
JOIN s_users_groups ug ON ug.user_id = u.id
JOIN s_groups g ON g.id = ug.group_id
WHERE ug.group_id IN (
  SELECT gp.ID_GROUP FROM s_group_permissions gp
  JOIN s_permission p ON p.ID_PERMISSION = gp.ID_PERMISSION
  WHERE p.SLUG IN ('mobile-access-sales')
)
AND ug.group_id NOT IN (
  SELECT gp.ID_GROUP FROM s_group_permissions gp
  JOIN s_permission p ON p.ID_PERMISSION = gp.ID_PERMISSION
  WHERE p.SLUG = 'crm-read-supplier'
);
```
Kalau ternyata banyak CRO/RO yang selama ini memakai menu itu tanpa punya slug-nya,
solusinya **bukan** membatalkan gate — tapi memberikan `crm-read-supplier` ke grup
mereka lewat RBAC Admin, supaya mobile dan web konsisten.

---

# BAGIAN C — Permission Gate Tingkat Layar (P1)

Menyamai `enforcePermission()` milik web. Buat berkas baru
`lib/widgets/permission_gate.dart`:

```dart
/// Padanan mobile untuk enforcePermission() di crm-react
/// (src/routes/_auth/route.tsx). Menyembunyikan kartu menu saja tidak cukup —
/// begitu sebuah layar bisa dicapai lewat deep link, notifikasi, atau tombol
/// di layar lain, tidak ada lagi yang memeriksa izinnya.
class PermissionGate extends StatelessWidget {
  final String slug;
  final Widget child;
  const PermissionGate({super.key, required this.slug, required this.child});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GeuUser?>(
      // getCachedUser() membaca profil dari penyimpanan lokal (tidak memanggil
      // jaringan) — sama seperti yang dipakai _loadPermissions() di
      // sales_dashboard_screen.dart. Jangan ganti dengan /api-auth/me: lambat
      // dan boros kuota kalau dipanggil tiap kali layar dibuka.
      future: GeuAuthService.getCachedUser(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)),
          );
        }
        if (snap.data?.hasPermission(slug) ?? false) return child;
        return const _AccessDeniedScreen();
      },
    );
  }
}
```

`_AccessDeniedScreen` — setara `/errors/forbidden` di web:
```
        🔒  (ikon lock_outline, 56px, AppColors.textSecondary)

        Akses Ditolak
        (AppTextStyles.h6, bold)

  Anda tidak memiliki izin untuk membuka
  halaman ini. Hubungi admin bila menurut
  Anda ini keliru.
        (bodyMedium, textSecondary, rata tengah)

        [ Kembali ]   (OutlinedButton → Navigator.pop)
```

Pasang di layar-layar berpermission:
| Layar | Slug |
|---|---|
| `TasksHubScreen` | `crm-read-task` |
| `SelfAssignScreen` | `crm-read-self-assign` |
| `PickupListScreen` | `crm-read-pickup` |
| `WorkOrderListScreen` | `crm-read-work-order` |
| `VisitPlanScreen`, `VisitHistoryScreen`, `NearbySupplierScreen`, `ScanProspectScreen` | `crm-read-visit-planner` |
| `SupplierListScreen` | `crm-read-supplier` |

`GeuAuthService.getCachedUser()` sudah ada (dipakai `_loadPermissions()` di
`sales_dashboard_screen.dart`), jadi tidak perlu menambah apa pun di service.

---

# BAGIAN D — Usulan UI/UX Baru (opsional, kerjakan setelah A–C)

Bagian ini **menambah**, bukan mengganti. Semua tetap memakai `AppColors` dan
`AppTextStyles` yang ada.

## D.1 Modul Assignation (menu web yang belum ada di mobile)

Backend siap: `/api-crm/point-of-origin/*` (diuji `200`).
Permission: `crm-read-assignation`.

Web punya dua tab (CRO & ROE). Untuk mobile, tab yang sama tetap masuk akal:

```
┌───────────────────────────────────┐
│ ←  Assignation                    │
├───────────────────────────────────┤
│   [  CRO  ]  [  ROE  ]            │  ← TabBar, indikator hijau AppColors.primaryGreen
├───────────────────────────────────┤
│  ┌─────────────────────────────┐  │
│  │ Kuota lead        [  50  ]  │  │  ← input angka
│  │ Jenis    [Semua ▾]          │  │
│  │ Rentang  [30 hari ▾]        │  │
│  └─────────────────────────────┘  │
│                                   │
│  Pratinjau Pembagian              │  ← hasil GET .../assign (belum eksekusi)
│  ┌─────────────────────────────┐  │
│  │ ● Dicky Allen         18    │  │
│  │ ● Indra Juwardi       17    │  │
│  │ ● Yadi Suryadi        15    │  │
│  └─────────────────────────────┘  │
│                                   │
│  [    Distribusikan Lead    ]     │  ← POST, FilledButton hijau
└───────────────────────────────────┘
```

Aturan penting:
- `GET /assign` = **pratinjau saja**, tidak mengubah apa pun. Selalu tampilkan
  pratinjau dulu; jangan pernah langsung `POST`.
- Sebelum `POST`, munculkan dialog konfirmasi menyebut **jumlah dan nama CRO**:
  *"Distribusikan 50 lead ke 3 CRO?"* — ini aksi yang sulit dibatalkan.
- Setelah sukses: SnackBar hijau + kembali ke pratinjau kosong.

Tab ROE serupa, memakai `roe-eligible-suppliers` (list dengan checkbox + pencarian)
lalu `POST /assign-roe`.

## D.2 Melengkapi Statistik Saya

Sekarang baru 4 dari 11 endpoint terpakai. Dua yang paling berguna untuk sales:

**`target-achievement`** — taruh sebagai kartu paling atas, gaya progress ring yang
sudah dipakai `driver_score_screen.dart` (konsisten dengan yang ada):
```
┌─────────────────────────────────┐
│  Target Bulan Ini               │
│         ╭───────╮               │
│         │  72%  │   18 / 25     │
│         ╰───────╯   supplier    │
│  ▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░             │
│  Sisa 7 hari                    │
└─────────────────────────────────┘
```
Warna: ≥90% `AppColors.success`, 70–89% `AppColors.accentOrange`, <70% `AppColors.error`
— aturan ambang yang sama dengan skor driver, supaya bahasa visualnya seragam.

**`overview`** — deretan KPI ringkas di bawahnya, memakai `_metricCard` yang sudah ada.

## D.3 Cek duplikat sebelum daftar prospek

`GET /api/visit-planner/prospect/check-duplicate?name=`

Di form registrasi prospek, panggil saat field nama kehilangan fokus (bukan tiap
ketikan). Kalau ada kemiripan, tampilkan peringatan **inline** — jangan dialog yang
memblokir:
```
┌─────────────────────────────────────┐
│ Nama Usaha                          │
│ ┌─────────────────────────────────┐ │
│ │ Siomay Bandung Yes              │ │
│ └─────────────────────────────────┘ │
│ ⚠ Mirip dengan supplier yang sudah  │  ← accentOrange, caption
│   ada: "Siomay bandung yes          │
│   kalpataru" (0,2 km)               │
│   [Lihat]        [Tetap Daftarkan]  │
└─────────────────────────────────────┘
```
Peringatan, bukan larangan — RO tetap boleh melanjutkan (bisa saja memang cabang
berbeda). Ini mencegah duplikat tanpa menghalangi kerja lapangan.

## D.4 Riwayat setor supplier — perluas ke Daftar Supplier

`GET /api/suppliers/:id` sekarang sudah mengembalikan `total_order_count`,
`total_order_nominal`, `last_order_date`, dan `recent_orders`
(ditambahkan 22 Agu 2026, dipakai sheet Detail Supplier di peta).

Data yang sama bisa memperkaya kartu di `SupplierListScreen` tanpa mengubah layout:
tambahkan satu baris kecil di bawah alamat —
`Terakhir setor 28/03/2026 · Rp1.700.000` — atau *"Belum pernah setor"*
(`AppColors.textSecondary`, `caption`).

⚠️ **Jangan** memanggil `/api/suppliers/:id` untuk setiap baris daftar (N+1 request).
Kalau ingin ditampilkan di list, minta backend menambahkan field ringkasnya ke
`GET /api/suppliers/` dulu.

## D.5 Penanda status data yang seragam

Sekarang tiap layar menangani loading/kosong/gagal dengan caranya sendiri.
Sarankan tiga widget bersama di `lib/widgets/`:
- `AppSkeletonBox` — sudah ada versinya di `visit_plan_screen.dart`
  (`_SkeletonBox`); angkat jadi widget bersama, jangan duplikasi
- `AppEmptyState(icon, title, message)`
- `AppErrorState(message, onRetry)` — **selalu** dengan tombol Coba Lagi

Ini yang membuat aturan "dilarang data palsu" jadi mudah dipatuhi: kalau menampilkan
kegagalan itu gampang dan seragam, tidak ada godaan menambalnya dengan dummy.

---

# URUTAN KERJA & COMMIT

Kerjakan berurutan, satu commit per langkah, `flutter analyze` bersih tiap kali:

| # | Pekerjaan | Berkas utama |
|---|---|---|
| 1 | `ApiResponse` menerima envelope Go | `models/api_response.dart` |
| 2 | Model geografis nullable | `models/geographic_models.dart` |
| 3 | `Supplier.toJson/fromJson` ikut nama field Go | `models/supplier_model.dart` |
| 4 | `SupplierApiService` → `GeuApiClient` + `/api/suppliers/*` | `services/api/supplier_api_service.dart` |
| 5 | Buang `_loadDummyData()`, tambah error state | `providers/supplier_form_provider.dart` |
| 6 | Pemilih PIC dengan pencarian | `screens/add_supplier_screen_simple.dart` |
| 7 | Bersihkan `SupplierListProvider` | `screens/sales_dashboard_screen.dart` |
| 8 | Permission gate Daftar Supplier | `screens/sales_dashboard_screen.dart` |
| 9 | `PermissionGate` + pasang di layar | `widgets/permission_gate.dart` |
| 10+ | Bagian D (opsional) | — |

Format pesan commit mengikuti kebiasaan repo:
```
fix(supplier): migrate form provider off dead /api-supplier endpoints

<jelaskan KENAPA, bukan cuma APA — sebutkan gejala yang dialami user>

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
```

Sebelum `git push`: `git fetch origin` lalu `git merge origin/main --no-edit`
kalau ada divergensi. **Jangan** rebase atau force-push — ada beberapa agen/orang
yang bekerja di repo ini bersamaan.

---

## Lampiran A — Perintah verifikasi

Login dulu (pakai akun yang sedang Anda pegang; **jangan tulis kredensial ke berkas**):
```bash
COOKIE=/tmp/geu_cj.txt
curl -s -c $COOKIE -X POST https://apipi.greenenergiutama.co.id/api-auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"<email>","password":"<password>"}' -o /dev/null -w "login=%{http_code}\n"
```

Cek endpoint:
```bash
for p in \
  "/api/suppliers/dropdowns" \
  "/api/suppliers/cities/35" \
  "/api/suppliers/districts/3573" \
  "/api/suppliers/villages/3573030" \
  "/api/suppliers/employees?limit=2&search=dicky" \
  "/api/suppliers/24468" ; do
  echo "$(curl -s -o /dev/null -w '%{http_code}' -b $COOKIE "https://apipi.greenenergiutama.co.id$p")  $p"
done
```

Jangan lupa hapus berkas cookie setelah selesai: `rm -f $COOKIE`

## Lampiran B — Ringkasan status endpoint (22 Agu 2026)

```
200  /api/suppliers/dropdowns
200  /api/suppliers/cities/:province_id
200  /api/suppliers/districts/:city_id
200  /api/suppliers/villages/:district_id
200  /api/suppliers/employees          (terpaginasi, 1658 baris)
200  /api/suppliers/:id                (sudah termasuk riwayat order)
200  /api-crm/point-of-origin/cro-users
200  /api-crm/dashboard/my-statistic/overview
200  /api-crm/tasks/batches
200  /api-crm/tasks/ro-area-items
200  /api/visit-planner/mission/history

404  /api-supplier/*                   ← seluruh prefix, sudah dihapus dari server
404  /api-whatsapp/*                   ← ada di service Node lain, bukan di host ini
```
