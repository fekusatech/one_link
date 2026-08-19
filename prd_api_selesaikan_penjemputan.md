# PRD – API Selesaikan Penjemputan (Pickup Completion)

## 1. Overview

Fitur **Selesaikan Penjemputan** memungkinkan Driver untuk menyelesaikan proses pengambilan minyak jelantah di lokasi supplier. Proses ini mencakup:
1. Memasukkan volume aktual yang diterima (`qty_real`)
2. Mengambil foto bukti penjemputan (jerigen/wadah)
3. Mengambil tanda tangan digital dari pemilik toko/supplier
4. Submit semua data ke server → server menyimpan file gambar dan memperbarui status

Saat ini frontend sudah mengimplementasikan semua UI + logika upload. Backend perlu menyediakan **1 endpoint POST** untuk menerima dan menyimpan data tersebut.

---

## 2. Objectives

- Driver dapat menyelesaikan penjemputan langsung dari aplikasi mobile
- Foto dan tanda tangan disimpan di server dan dapat diakses kembali via URL
- Status `surat_jalan_detail` diperbarui menjadi `done` setelah submit berhasil
- Data `qty_real` diperbarui agar laporan volume akurat

---

## 3. Current Frontend Behavior

Frontend mengirimkan request sebagai berikut:

```
POST https://greenenergiutama.cloud/api/surat_jalan_detail/update
Content-Type: multipart/form-data
Authorization: Bearer <token>
```

**Fields yang dikirim:**

| Field | Tipe | Keterangan |
|-------|------|------------|
| `surat_jalan_detail_id` | string | ID detail yang diselesaikan |
| `qty_real` | string (number) | Volume aktual yang diterima (liter) |
| `status` | string | Selalu `"done"` saat submit |
| `foto` | file (image/jpeg) | File foto bukti penjemputan |
| `ttd` | file (image/png) | File gambar tanda tangan digital |

**Cara foto ditampilkan di app (existing logic):**
- `foto` → `https://greenenergiutama.cloud/filemanager/foto-pengambilan/{filename}`
- `ttd` → `https://greenenergiutama.cloud/filemanager/ttd/{filename}`

---

## 4. API Endpoint Specification

### `POST /api/surat_jalan_detail/update`

#### Request Headers

```
Authorization: Bearer <token>
Content-Type: multipart/form-data
Accept: application/json
```

#### Request Body (form-data)

| Field | Tipe | Required | Validasi |
|-------|------|----------|----------|
| `surat_jalan_detail_id` | integer | ✅ | Harus ada di DB |
| `qty_real` | numeric | ✅ | > 0 |
| `status` | string | ✅ | `"done"` atau `"cancel"` |
| `alasan_batal` | string | ❌ | Wajib jika status=`"cancel"` |
| `foto` | file | ✅ jika status=done | JPEG/PNG, maks 5MB |
| `ttd` | file | ✅ jika status=done | PNG, maks 2MB |

---

#### Response – Sukses (200 OK)

```json
{
  "status": "success",
  "code": 200,
  "message": "Pickup berhasil diselesaikan",
  "data": {
    "surat_jalan_detail_id": "5767",
    "status": "done",
    "qty_real": "19",
    "alasan_batal": null,
    "foto": "filemanager/foto-pengambilan/SJ5767_20260410_083000.jpg",
    "ttd": "filemanager/ttd/SJ5767_20260410_083000.png",
    "foto_at": "2026-04-10 08:30:00",
    "ttd_at": "2026-04-10 08:30:00",
    "updated_at": "2026-04-10 08:30:00"
  }
}
```

> **PENTING:** Field `foto` dan `ttd` di response harus mengembalikan **path relatif**
> (contoh: `filemanager/foto-pengambilan/filename.jpg`), bukan URL absolut.
> Frontend sudah handle penambahan domain secara otomatis.

---

#### Response – Error Validasi (422)

```json
{
  "status": "error",
  "code": 422,
  "message": "Validasi gagal",
  "errors": {
    "foto": ["File foto wajib diisi saat status done"],
    "qty_real": ["Qty real harus lebih dari 0"]
  }
}
```

#### Response – Not Found (404)

```json
{
  "status": "error",
  "code": 404,
  "message": "Surat jalan detail tidak ditemukan"
}
```

#### Response – Unauthorized (401)

```json
{
  "status": "error",
  "code": 401,
  "message": "Token tidak valid atau sudah expired"
}
```

#### Response – Forbidden (403)

```json
{
  "status": "error",
  "code": 403,
  "message": "Anda tidak memiliki akses untuk menyelesaikan pickup ini"
}
```

---

## 5. Backend Technical Requirements

### 5.1 File Storage

Penamaan file harus unik untuk menghindari konflik. Format nama file yang direkomendasikan:

```
foto : SJ{detail_id}_{YYYYMMDD}_{HHmmss}.jpg
ttd  : SJ{detail_id}_{YYYYMMDD}_{HHmmss}.png
```

Simpan file di:

```
public/filemanager/foto-pengambilan/   ← untuk foto
public/filemanager/ttd/                ← untuk tanda tangan
```

---

### 5.2 Database Update

Saat request masuk dan berhasil, update tabel `surat_jalan_detail`:

```sql
UPDATE surat_jalan_detail
SET
  qty_real   = :qty_real,
  status     = :status,        -- 'done'
  foto       = :foto_path,     -- relative path, e.g. filemanager/foto-pengambilan/SJ5767_...jpg
  ttd        = :ttd_path,      -- relative path, e.g. filemanager/ttd/SJ5767_...png
  foto_at    = NOW(),
  ttd_at     = NOW(),
  updated_at = NOW()
WHERE surat_jalan_detail_id = :id;
```

---

### 5.3 Auto-update Status Surat Jalan Header

Setelah semua `surat_jalan_detail` pada satu `surat_jalan` berstatus `done` atau `cancel`,
sistem harus **otomatis** mengupdate status `surat_jalan` header menjadi `done`.

```sql
-- Cek apakah masih ada detail yang belum selesai
SELECT COUNT(*) as pending_count
FROM surat_jalan_detail
WHERE surat_jalan_id = :surat_jalan_id
  AND status NOT IN ('done', 'cancel');

-- Jika pending_count = 0, update status header
UPDATE surat_jalan
SET status = 'done', updated_at = NOW()
WHERE surat_jalan_id = :surat_jalan_id;
```

---

### 5.4 Authorization

- Ambil `surat_jalan_id` dari `surat_jalan_detail` yang dikirim
- Cek bahwa `surat_jalan.user_id` = user dari token yang login
- Jika tidak cocok → return **403 Forbidden**

---

## 6. Request-Response Flow

```
Driver App                             Backend Server
    │                                       │
    │── POST /api/surat_jalan_detail/update │
    │   (multipart/form-data)  ──────────►  │
    │   - surat_jalan_detail_id             │── 1. Validasi token
    │   - qty_real                          │── 2. Cek ownership (403 jika bukan miliknya)
    │   - status = "done"                   │── 3. Validasi field & file
    │   - foto (JPEG file)                  │── 4. Simpan foto ke storage
    │   - ttd (PNG file)                    │── 5. Simpan ttd ke storage
    │                                       │── 6. UPDATE surat_jalan_detail
    │                                       │── 7. Cek auto-complete SJ header
    │◄──────────────────────────────────────│
    │   { status: "success",                │
    │     data: { foto, ttd, ... } }        │
    │                                       │
    │── Tampilkan dialog "Pickup Berhasil!" │
    │── Navigasi kembali ke Dashboard       │
```

---

## 7. Testing Checklist

| # | Test Case | Expected Result |
|---|-----------|-----------------|
| 1 | Submit dengan semua field lengkap | 200 OK, file tersimpan di server |
| 2 | Submit tanpa foto | 422, error pada field foto |
| 3 | Submit tanpa TTD | 422, error pada field ttd |
| 4 | Submit qty_real = 0 | 422, error pada field qty_real |
| 5 | Submit dengan detail_id tidak valid | 404 |
| 6 | Submit tanpa token | 401 |
| 7 | Submit dengan token driver lain | 403 |
| 8 | Akses foto via URL setelah submit | 200, gambar tampil |
| 9 | Akses TTD via URL setelah submit | 200, gambar tampil |
| 10 | Submit item terakhir dari satu SJ | Status SJ header otomatis = `done` |

---

## 8. Integration Notes (Frontend – No Changes Needed)

Frontend sudah dikonfigurasi dan siap. Tidak ada perubahan kode Flutter yang diperlukan
selama backend mengikuti spesifikasi response di atas.

**Konfigurasi di `surat_jalan_service.dart`:**

```dart
// Method: submitPickupDetail()
// URL : POST https://greenenergiutama.cloud/api/surat_jalan_detail/update
// Type: multipart/form-data

request.fields['surat_jalan_detail_id'] = detailId;
request.fields['qty_real']              = qtyReal;
request.fields['status']                = 'done';
request.files.add(foto);   // key: 'foto'
request.files.add(ttd);    // key: 'ttd'
```

**URL builder untuk foto di `surat_jalan.dart`:**

```dart
// fotoUrl getter
'${AppConfig.serverDomain}/filemanager/foto-pengambilan/$foto'

// ttdUrl getter
'${AppConfig.serverDomain}/filemanager/ttd/$ttd'
```
