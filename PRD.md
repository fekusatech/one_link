# Product Requirements Document (PRD)

## 1. Project Overview
**Product Name:** One Link - PT Green Energi Utama  
**Platform:** Mobile Application (Android/iOS) built with Flutter  
**Domain:** Waste Oil Collection Management System  
**Current Version:** 1.0.3+4  

### 1.1 Product Vision
One Link adalah aplikasi manajemen *waste oil collection* (pengumpulan minyak jelantah/limbah) yang dirancang untuk PT Green Energi Utama. Aplikasi ini bertujuan untuk mengotomatisasi dan memonitor proses operasional harian driver dan tim lapangan, mengintegrasikan fitur navigasi cerdas, manajemen "Surat Jalan" (Delivery/Pickup Orders), pelacakan armada secara real-time, serta pencatatan aset di lapangan melalui pemindaian QR Code.

### 1.2 Target Audience
- **Driver/Karyawan Lapangan:** Bertanggung jawab melakukan penjemputan barang (waste oil) berdasarkan jadwal dan rute.
- **Admin/Manajemen:** Melakukan pemantauan kinerja, lokasi driver, serta rekapan data penjemputan.

---

## 2. Technical Stack & Dependencies
- **Framework:** Flutter (SDK ^3.10.0)
- **State Management:** Provider (`provider: ^6.1.1`)
- **Networking:** HTTP (`http: ^1.6.0`), Dio (`dio: ^5.4.0`)
- **Maps & Location:** Google Maps Flutter, Geolocator (`geolocator: ^13.0.2`)
- **Hardware Integrations:** Mobile Scanner (QR Code), Battery Plus, Device Info Plus
- **Local Storage:** Shared Preferences

---

## 3. Core Features & Requirements

### 3.1. Authentication & User Management
**Deskripsi:** Sistem login dan manajemen profil pengguna untuk karyawan.
- **Login:** Menggunakan kombinasi Nomor Telepon dan OTP.
- **Token Management:** Membutuhkan fitur *Refresh Token* untuk mempertahankan sesi.
- **Profil:** Pengguna (Driver) dapat melihat profil, mengubah kata sandi, dan mengunggah foto profil.

*Status: Sebagian diimplementasikan (Login/OTP). Endpoints profil dan logout sedang dalam tahap pengembangan.*

### 3.2. Surat Jalan (Pickup Management)
**Deskripsi:** Modul utama untuk menangani proses penjemputan minyak jelantah.
- **Dashboard Surat Jalan:** Menampilkan daftar *Surat Jalan* berdasarkan status (pending, pickup, done) dan tanggal.
- **Informasi Card:** Memuat kode Surat Jalan, informasi Supplier (termasuk ikon dan nama), Nama Driver, Plat Nomor, Total Liter, Total Harga (Mata Uang Rp), serta Visual Progress Bar.
- **Status Warna:** Hijau (Selesai), Oranye (Sedang Pickup), Merah (Pending/Batal).
- **Aksi:** Memulai perjalanan, update lokasi GPS, update kuantitas terambil, unggah foto/dokumen/tanda tangan, dan menyelesaikan pickup.

*Status: Integrasi UI dan Dashboard Selesai. Beberapa API penjemputan mendalam perlu disempurnakan.*

### 3.3. Pelacakan GPS (Driver Tracking System)
**Deskripsi:** Pelacakan armada secara Real-Time dengan standar kebijakan privasi tinggi (Compliant dengan Google Play Store).
- **Background Location:** Merekam lat, long, akurasi, kecepatan, dan level baterai secara *background*.
- **Transparansi (Consent):** Memiliki *Privacy Policy* lengkap serta *Foreground Notification* yang jelas saat GPS berlari.
- **Baterai & Efisiensi:** Menangani optimalisasi baterai dan sinkronisasi *offline* saat koneksi hilang.

*Status: Production Ready (Memenuhi Standar GDPR dan Play Store).*

### 3.4. Pemindai QR (QR Scanner Feature)
**Deskripsi:** Pemindaian QR Code di lokasi penjemputan untuk proses check-in atau validasi lokasi.
- **Full-Screen Scanner:** Tampilan kamera penuh dengan *animated scanning overlay* dan indikator siku.
- **Fitur Opsional:** Tombol *Flashlight* dan input manual ID jika QR rusak.
- **Result Dialog:** Menampilkan detail lokasi (Nama warung/supplier, alamat, estimasi penjemputan volume minyak).

*Status: Selesai (UI/UX selesai, ready untuk integrasi final *camera logic*).*

---

## 4. Planned Features (Roadmap / Future Modules)

Berikut adalah modul yang telah direncanakan namun masih dalam fase desain/belum dikembangkan:

### 4.1. Calendar & Scheduling
- Fitur penjadwalan pickup harian/mingguan.
- Kemampuan *Reschedule* dan melihat ketersediaan slot waktu.

### 4.2. Notifikasi (Push Notifications)
- Peringatan real-time untuk penugasan baru.
- Integrasi FCM (Firebase Cloud Messaging) atau Push Notification Engine.

### 4.3. Navigasi Lanjutan
- Rute optimal (*Turn-by-turn directions*) yang memangkas waktu ambil.

### 4.4. Analytics & Reporting
- Laporan performa driver, total volume minyak mingguan, serta revenue insights.

---

## 5. Non-Functional Requirements
- **Performance:** Aplikasi harus dapat di-load secara cepat di berbagai gawai entry-level yang umumnya digunakan oleh driver. Data lokal disimpan via *Shared Preferences* untuk cache.
- **Offline Reliability:** Karena lokasi penjemputan mungkin memiliki sinyal lemah, GPS harus dapat melakukan *queueing data* (antrean data) dan sinkronisasi otomatis ketika kembali online.
- **Security & Privacy:** Akses kamera dan lokasi ditangani dengan *Permission Handler* yang valid; data sensitif terenkripsi saat pengiriman.
- **Accessibility:** UI konsisten dengan penanganan status kosong (*Empty State*), *Error Handling* (Timeout/Network Error), dan loading skeleton yang intuitif.

---

## 6. Implementation Priorities

1. **Phase 1 (MVP Critical):** 
   Penyelesaian API Pickup Process (Upload foto/tanda tangan), User Profile, dan File Uploads.
2. **Phase 2 (Enhancement):** 
   Kalender Jadwal Pickup, Notifikasi FCM lanjutan, Navigasi rute optimal.
3. **Phase 3 (Enterprise):** 
   Integrasi WhatsApp API, Google Maps Directions Advance, serta Analytics Dashboard untuk Admin.

---
*Document Generated Based on Internal Project Metadata.*
