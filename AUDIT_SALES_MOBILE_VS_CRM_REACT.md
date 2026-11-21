# Audit Sisi Sales (CRO/RO): crm-mobile vs crm-react

Dokumen ini membandingkan modul **Sales (CRO/RO)** di `crm-mobile` (Flutter) terhadap
`crm-react` (web CRM) — keduanya memakai backend Go yang sama
(`go-rest-api` @ `https://apipi.greenenergiutama.co.id`).

Tanggal audit: **22 Agustus 2026**

Sumber acuan:
- `crm-react/src/components/sidebar/app-sidebar.tsx` — definisi menu & filter permission
- `crm-react/SRS.md` — spesifikasi 14 modul + daftar 12 permission slug
- `crm-mobile/lib/screens/sales_dashboard_screen.dart` — menu & bottom nav mobile
- `go-rest-api/src/router/` — endpoint yang benar-benar ada
- Uji langsung ke production (login sebagai Developer/Super User) untuk memastikan
  endpoint hidup atau mati

---

## 1. Ringkasan Eksekutif

| Kategori | Status |
|---|---|
| Menu web yang **belum ada** di mobile | 6 (Broadcast, Assignation CRO/ROE, Chat Omnichannel, RO Area, User Management, RBAC Admin) + Analytics Dashboard |
| Menu mobile yang **rusak** (endpoint 404) | 1 — **Tambah Supplier** (form wizard). Daftar/list-nya sendiri jalan normal |
| Permission slug dipakai web | 12 |
| Permission slug dipakai mobile | 7 (5 dari 12 slug web tidak pernah dicek) |
| Menu mobile tanpa permission gate padahal web punya | 1 — **Daftar Supplier** (`crm-read-supplier`) |
| Proteksi level layar (route guard) | Web: ada (`enforcePermission()` → `/errors/forbidden`). **Mobile: tidak ada** |

**Tiga hal paling mendesak:**
1. 🔴 **Form Tambah Supplier tidak bisa menyimpan sama sekali** — `SupplierFormProvider`
   memanggil `/api-supplier/*` yang sudah dihapus dari server (semua 404). Lebih buruk:
   saat gagal, provider diam-diam memuat **data dummy** (`_loadDummyData()`), jadi
   dropdown-nya terlihat terisi dan form seolah normal, padahal tombol Simpan pasti gagal.
2. 🟠 **Daftar Supplier tidak dibatasi permission** — user tanpa `crm-read-supplier` tetap melihat menunya.
3. 🟠 **Tidak ada route guard di mobile** — menyembunyikan menu ≠ mengunci layar.

> **Koreksi revisi-2:** pada draf pertama saya menulis "Daftar Supplier rusak total".
> Itu **tidak benar** dan sudah diperbaiki di bawah. Layar daftar supplier memakai
> `SupplierListService` → `/api/suppliers/` yang **sehat**. Yang rusak adalah
> **form tambah supplier** (`SupplierFormProvider` → `SupplierApiService`).

---

## 2. Cara Kerja RBAC: Web vs Mobile

### 2.1 Web (crm-react)

Dua lapis proteksi:

**Lapis 1 — Sidebar** (`app-sidebar.tsx`):
```ts
function filterNav(items: NavItem[], permissions: string[]): NavItem[] {
  return items
    .filter((item) => !item.permission || permissions.includes(item.permission))
    .map((item) => ({
      ...item,
      children: item.children?.filter(
        (child) => !child.permission || permissions.includes(child.permission),
      ),
    }))
    .filter((item) => !item.children || item.children.length > 0)
}
```
Menu tanpa `permission` selalu tampil. Parent yang semua anaknya tersaring habis
ikut hilang.

**Lapis 2 — Route guard** (`src/routes/_auth/route.tsx`):
`enforcePermission()` dijalankan **sebelum komponen dirender**. Kalau tidak cocok →
redirect ke `/errors/forbidden`. Jadi walaupun user mengetik URL langsung, tetap ditolak.

### 2.2 Mobile (crm-mobile)

Hanya **satu lapis** — penyaringan kartu menu di dashboard:
```dart
bool _has(String slug) => _geuUser?.hasPermission(slug) ?? false;

final visible = _menuItems()
    .where((item) => item.permission == null || _has(item.permission!))
    .toList();
```

Polanya sudah benar dan sengaja meniru `filterNav()` web (ada komentarnya di kode).
Sumber permission juga sama: `GET /api-auth/login` / `/api-auth/me` → `permissions[]`.

**Perbedaan penting:**

| Aspek | Web | Mobile |
|---|---|---|
| Filter menu | ✅ | ✅ |
| Guard sebelum layar dibuka | ✅ `enforcePermission()` | ❌ tidak ada |
| Nested/child menu | ✅ (Dashboards, Visit Plan, Assignation, Chat, Master Data) | ❌ menu datar semua |
| Parent auto-hilang kalau anak kosong | ✅ | — (tidak relevan) |

**Konsekuensi tidak adanya route guard:** setiap layar yang bisa dicapai lewat jalur
lain (deep link, tombol di layar lain, drawer, bottom nav) tidak diperiksa ulang.
Contoh nyata: `VisitHistoryScreen` dan `TasksHubScreen` muncul sebagai tab bottom nav
yang dikontrol flag `hasVisitPlanner`/`showTasksTab`, tapi kelasnya sendiri tidak
memeriksa permission apa pun — kalau nanti ada yang push layar itu dari tempat lain,
tidak ada yang menahan.

### 2.3 Slug yang dipakai masing-masing

12 slug resmi menurut `SRS.md` §4.1:

| Slug | Web | Mobile | Catatan |
|---|:--:|:--:|---|
| `crm-read-task` | ✅ | ✅ | |
| `crm-read-work-order` | ✅ | ✅ | |
| `crm-read-pickup` | ✅ | ✅ | |
| `crm-read-self-assign` | ✅ | ✅ | |
| `crm-read-visit-planner` | ✅ | ✅ | |
| `crm-read-supplier` | ✅ | ❌ | **menu mobile ada tapi tanpa gate** |
| `crm-read-assignation` | ✅ | ❌ | modul belum ada di mobile |
| `crm-read-chat` | ✅ | ❌ | modul belum ada di mobile |
| `crm-read-broadcast` | ✅ | ❌ | modul belum ada di mobile |
| `crm-read-user` | ✅ | ❌ | modul belum ada di mobile |
| `crm-manage-ro-area` | ✅ | ❌ | modul belum ada di mobile |
| `crm-manage-permissions` | ✅ | ❌ | modul belum ada di mobile |

Mobile juga memakai 2 slug tambahan yang **tidak dipakai sidebar web**:
`crm-self-assign-cro` dan `crm-self-assign-ro` — dipakai untuk menentukan tab
default di layar Self Assign. Ini wajar (web memakainya di dalam halaman, bukan di sidebar).

---

## 3. Perbandingan Menu

### 3.1 Menu web yang sudah ada di mobile

| Menu web | Permission | Padanan di mobile | Catatan |
|---|---|---|---|
| My Tasks | `crm-read-task` | Tugas Saya (kartu + tab "Tugas") | ✅ |
| Work Order | `crm-read-work-order` | Daftar Work Order | ✅ |
| Pickup | `crm-read-pickup` | Pickup | ✅ |
| Self Assign | `crm-read-self-assign` | Self Assign | ✅ |
| Visit Plan → Mission | `crm-read-visit-planner` | Mission hari ini (tab "Visit") | ✅ |
| Visit Plan → Scan | `crm-read-visit-planner` | Scan Prospek | ✅ |
| Dashboards → My Statistic | — | Statistik Saya | ⚠️ cakupan API tipis (lihat §5) |
| Master Data → Suppliers | `crm-read-supplier` | Daftar Supplier | 🔴 **rusak + tanpa gate** |

Mobile juga punya menu yang tidak berdiri sendiri di web tapi masih dalam lingkup
visit planner, dan itu wajar untuk konteks lapangan:
- **Supplier Nearby** (`crm-read-visit-planner`)
- **Riwayat Kunjungan** (tab, `crm-read-visit-planner`)

### 3.2 Menu web yang BELUM ADA di mobile

| # | Menu web | Permission | Backend | Prioritas usulan |
|---|---|---|---|---|
| 1 | **Assignation → CRO** | `crm-read-assignation` | ✅ Go: `/api-crm/point-of-origin/*` (diuji: `200`) | Tinggi |
| 2 | **Assignation → ROE** | `crm-read-assignation` | ✅ Go: `/api-crm/point-of-origin/*` | Tinggi |
| 3 | **Dashboards → Analytics** | — | ✅ Go: `/api-crm/dashboard/analytics/*` | Sedang |
| 4 | **Chat Omnichannel** | `crm-read-chat` | ⚠️ **bukan di Go** — `/api-whatsapp/*` di service Node terpisah | Rendah (lihat §4.3) |
| 5 | **Broadcast** | `crm-read-broadcast` | ⚠️ **bukan di Go** — `/api-whatsapp/broadcast` | Rendah (lihat §4.3) |
| 6 | **Master Data → RO Area** | `crm-manage-ro-area` | ✅ Go: `/api/master-data/ro-gudang` | Rendah (admin desktop) |
| 7 | **Master Data → Users** | `crm-read-user` | ✅ Go: `/api-crm/users` | Rendah (admin desktop) |
| 8 | **RBAC Admin** | `crm-manage-permissions` | ✅ Go: `/api-admin/*` | Rendah (admin desktop) |
| 9 | **Settings** | — | — | Sudah tercakup Profil |

> Catatan: #6, #7, #8 adalah fungsi administratif yang lebih cocok di desktop.
> Kalau memang tidak akan dibuat di mobile, sebaiknya ditulis eksplisit sebagai
> keputusan desain supaya tidak dianggap "kelewatan" di audit berikutnya.

---

## 4. Temuan Kritis

### 4.1 🔴 Form Tambah Supplier rusak — endpoint `/api-supplier/*` sudah mati

`lib/services/api/supplier_api_service.dart` (15 method) masih memanggil prefix lama
`/api-supplier/*`. Prefix ini **tidak ada** di `go-rest-api/src/router/`, dan hasil uji
langsung ke production semuanya **404**:

```
404  /api-supplier/list?page=1&limit=2
404  /api-supplier/provinces
404  /api-supplier/detail/1
```

Ini pola yang sama dengan bug-bug sebelumnya (`/api/login`, `/driver_tracking/*`) —
sisa dari migrasi `apipi.greenenergiutama.co.id` ke Go API.

**Yang benar-benar terdampak** (hasil penelusuran ulang siapa memanggil siapa):

| Pemakai | Status | Dampak |
|---|---|---|
| `lib/providers/supplier_form_provider.dart` → `AddSupplierScreenSimple` | 🔴 **rusak** | Form tambah supplier: seluruh dropdown, cascading wilayah, validasi rekening, dan **simpan** |
| `lib/providers/supplier_list_provider.dart` | ⚪ **dead code** | Di-`create` di `sales_dashboard_screen.dart` tapi **tidak pernah dibaca** `SupplierListScreen`. Tidak berdampak ke user, tapi menyesatkan pembaca kode |
| `lib/screens/supplier_list_screen.dart` | ✅ **sehat** | Pakai `SupplierListService` → `/api/suppliers/` |
| `lib/services/dashboard_stats_service.dart` | ✅ **sehat** | Sudah dimigrasi ke `/api/suppliers/dashboard-stats` |

**Pemetaan ke endpoint Go yang benar** (`go-rest-api/src/router/shared/supplier_router.go`):

| Lama (404) | Baru (ada di Go) |
|---|---|
| `GET /api-supplier/list` | `GET /api/suppliers/` *(cursor-based, bukan page)* |
| `GET /api-supplier/detail/:id` | `GET /api/suppliers/:id` |
| `POST /api-supplier/create` | `POST /api/suppliers/` |
| `POST /api-supplier/update/:id` | `PUT /api/suppliers/:id` |
| `POST /api-supplier/toggle-status/:id` | `PUT /api/suppliers/:id/toggle-status` |
| `GET /api-supplier/dropdown-options` | `GET /api/suppliers/dropdowns` |
| `GET /api-supplier/cities/:provId` | `GET /api/suppliers/cities/:province_id` |
| `GET /api-supplier/districts/:cityId` | `GET /api/suppliers/districts/:city_id` |
| `GET /api-supplier/villages/:distId` | `GET /api/suppliers/villages/:district_id` |
| `GET /api-supplier/employees` | `GET /api/suppliers/employees` |
| `POST /api-supplier/validate-account` | `POST /api/suppliers/validate-account` |
| `GET /api-supplier/provinces` / `banks` / `satuan` / `jenis-supplier` / `kategori-supplier` | konsolidasi ke `GET /api/suppliers/dropdowns` |

Perlu diperhatikan: `SupplierApiService` memakai `ApiService` (paket `http` lama),
bukan `GeuApiClient` (Dio + cookie session + auto-refresh 401). Saat migrasi
sebaiknya sekalian pindah ke `GeuApiClient`, konsisten dengan
`lib/services/supplier_list_service.dart` yang sudah benar memakai `/api/suppliers/`.

> Catatan: di aplikasi ada **dua** service supplier. `supplier_list_service.dart`
> (dipakai layar lain) sudah benar dan hidup; `services/api/supplier_api_service.dart`
> yang mati. Sebaiknya digabung jadi satu supaya tidak membingungkan.

### 4.2 🟠 "Daftar Supplier" tidak punya permission gate

`sales_dashboard_screen.dart` — menu ini satu-satunya yang punya padanan web
ber-permission tapi di mobile tidak diberi `permission:`:

```dart
_CroMenuItem(
  title: 'Daftar Supplier',
  subtitle: 'Cari & perbarui data supplier',
  icon: Icons.edit_location,
  color: AppColors.accentOrange,
  // ← tidak ada `permission:`, padahal web pakai 'crm-read-supplier'
  onTap: ...
),
```

Sementara web:
```ts
{ title: 'navigation.suppliers', url: '/master-data/suppliers', permission: 'crm-read-supplier' }
```

**Perbaikan:** tambahkan `permission: 'crm-read-supplier'`.

### 4.3 ⚠️ Chat & Broadcast tidak tersedia dari host API mobile

Mobile menunjuk ke `https://apipi.greenenergiutama.co.id` (Go API, port 3001).
Chat & Broadcast **tidak** ada di sana — keduanya dilayani service Node terpisah
di port 3002, hanya terekspos lewat nginx domain web CRM
(`crm-react/nginx.conf`):

```nginx
location ~ ^/(api|api-auth|api-admin|api-crm|api-tms)(/|$) {
    proxy_pass http://172.17.0.1:3001;   # Go API
}
location ~ ^/api-whatsapp {
    proxy_pass http://172.17.0.1:3002;   # Node WhatsApp service
}
```

Uji langsung: `GET https://apipi.greenenergiutama.co.id/api-whatsapp/contacts` → **404**.

Jadi Chat/Broadcast di mobile bukan sekadar "bikin layar" — perlu keputusan
arsitektur dulu:
- **Opsi A:** tambahkan `location ~ ^/api-whatsapp` di nginx `apipi` juga (paling ringan)
- **Opsi B:** mobile pakai base URL kedua khusus WhatsApp
- **Opsi C:** pindahkan endpoint WhatsApp ke Go API

Perlu dicek juga apakah cookie session Go berlaku di service Node itu.

### 4.4 🟡 Tidak ada route guard di layar mobile

Web menolak akses di level route. Mobile hanya menyembunyikan kartu menu.
Untuk sekarang risikonya rendah (tidak ada deep link ke layar CRO), tapi begitu ada
notifikasi yang membuka layar langsung, gate-nya hilang.

**Usulan:** widget pembungkus sederhana, misalnya
`PermissionGate(slug: 'crm-read-task', child: TasksHubScreen())`, yang menampilkan
layar "Akses ditolak" kalau slug tidak dimiliki — setara `/errors/forbidden` di web.
Sekaligus jadi pertahanan berlapis kalau daftar menu dan daftar tab tidak sinkron.

---

## 5. Cakupan API per Modul (mobile vs SRS)

Endpoint di bawah **sudah ada dan hidup** di Go API tapi belum dipakai mobile
(status diuji langsung ke production).

### Module 2 — Dashboards
Mobile hanya memakai **4 dari 11** endpoint My Statistic:

| Endpoint | Mobile |
|---|:--:|
| `/my-statistic/assignment-performance` | ✅ |
| `/my-statistic/new-supplier` | ✅ |
| `/my-statistic/existing-supplier` | ✅ |
| `/my-statistic/daily-activity` | ✅ |
| `/my-statistic/overview` | ❌ (diuji: `200`) |
| `/my-statistic/poo-closed` | ❌ |
| `/my-statistic/acquisition` | ❌ |
| `/my-statistic/acquisition-detail` | ❌ |
| `/my-statistic/target-achievement` | ❌ ← relevan untuk sales |
| `/my-statistic/activity-summary` | ❌ |
| `/my-statistic/export` | ❌ |

Seluruh `/api-crm/dashboard/analytics/*` (7 endpoint): ❌ belum dipakai sama sekali.

### Module 13 — Task Management
| Endpoint | Mobile |
|---|:--:|
| `/tasks/progress` | ✅ |
| `/tasks/items` | ✅ |
| `/tasks/batches` | ❌ (diuji: `200`) |
| `/tasks/ro-area-items` | ❌ (diuji: `200`) |
| `/tasks/ro-area-items/:supplierId/claim` | ❌ |

Dua endpoint RO-Area terakhir khusus alur RO — perlu dicek apakah memang sengaja
dilewatkan atau tertinggal.

### Module 11 — Work Order
| Endpoint | Mobile |
|---|:--:|
| `GET /work-orders`, `GET /:id`, `GET /statuses`, `POST /` | ✅ |
| `PUT /work-orders/:id` (edit) | ❌ |
| `DELETE /work-orders/:id` | ❌ |
| `GET /visits/stats` | ❌ |

### Module 8 — Visit Planner
Cakupan paling lengkap. Yang belum:
| Endpoint | Mobile |
|---|:--:|
| `/visit-planner/mission/history` | ❌ (diuji: `200`) — padahal ada layar Riwayat Kunjungan, saat ini pakai `/api/visits/history` |
| `/visit-planner/prospect/check-duplicate` | ❌ — cek duplikat sebelum daftar prospek |
| `/visit-planner/scan/monitor` | ❌ (admin) |
| `/visit-planner/scan/token-stats` | ❌ (admin) |
| `/visit-planner/scan/quota/:roId` | ❌ (admin) |

`prospect/check-duplicate` layak ditambahkan: mencegah RO mendaftarkan prospek
yang sudah ada di database.

### Module 7 — Self Assign
✅ Lengkap (7 dari 7 endpoint terpakai).

### Module 12 — Pickup
✅ Lengkap, bahkan lebih (`/pickups/supplier-zona/:id` dipakai mobile tapi tidak
tercatat di SRS — SRS-nya yang perlu diperbarui).

### Module 6 — Assignation
❌ Belum ada sama sekali (6 endpoint).

---

## 6. Rekomendasi Prioritas

### P0 — Memperbaiki yang rusak
1. **Migrasi `SupplierApiService` dari `/api-supplier/*` ke `/api/suppliers/*`**
   sekaligus pindah ke `GeuApiClient`, dan **hapus fallback `_loadDummyData()`**.
   Tanpa ini form tambah supplier tidak bisa menyimpan sama sekali.
   → Langkah detailnya ada di **`PANDUAN_PERBAIKAN_SALES_MOBILE.md`**
2. **Tambahkan `permission: 'crm-read-supplier'`** pada menu Daftar Supplier.

### P1 — Menyamakan perilaku dengan web
3. **`PermissionGate`** untuk layar CRO/RO, setara `enforcePermission()` di web.
4. **Modul Assignation (CRO + ROE)** — backend sudah siap, ini modul sales
   terbesar yang hilang.
5. **Lengkapi My Statistic** — minimal `overview` dan `target-achievement`, keduanya
   langsung berguna untuk sales di lapangan.

### P2 — Pengayaan
6. **`prospect/check-duplicate`** sebelum registrasi prospek.
7. **Edit & hapus Work Order** (`PUT`/`DELETE`).
8. **Dashboard Analytics** (versi ringkas untuk mobile).
9. **Task batches & RO-area items**.

### P3 — Perlu keputusan dulu
10. **Chat & Broadcast** — tentukan opsi arsitektur di §4.3 sebelum mulai koding.
11. **RO Area / Users / RBAC Admin** — putuskan apakah memang khusus desktop; kalau
    ya, catat sebagai keputusan sadar.

### Kebersihan kode
12. Gabungkan dua service supplier (`services/api/supplier_api_service.dart` vs
    `services/supplier_list_service.dart`) jadi satu.
13. Perbarui `SRS.md` untuk endpoint yang sudah ada tapi belum tercatat
    (`/api-crm/pickups/supplier-zona/:id`, `/api/suppliers/:id` beserta field
    riwayat order yang baru ditambahkan).

---

## Lampiran — Hasil Uji Endpoint (production, 22 Agu 2026)

Login sebagai `Developer` + `Super User` (punya seluruh permission), lalu:

```
200  /api-crm/tasks/batches
200  /api-crm/tasks/ro-area-items
200  /api/visit-planner/mission/history
200  /api-crm/dashboard/my-statistic/overview
200  /api-crm/point-of-origin/cro-users
404  /api-supplier/list?page=1&limit=2
404  /api-supplier/provinces
404  /api-supplier/detail/1
404  /api-whatsapp/contacts
```

Artinya: yang `200` = backend siap, tinggal dipakai mobile.
Yang `404` = harus diperbaiki (`/api-supplier/*`) atau butuh keputusan
arsitektur (`/api-whatsapp/*`).
