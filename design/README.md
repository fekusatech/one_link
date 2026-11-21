# One Link mobile redesign · Review 01

Rancangan visual di FigCraft 0.15.0, dibuat 12 November 2026. Ini tahap desain untuk review, belum implementasi Flutter. Semua nama, jumlah, jadwal, status GPS, serta data supplier di artboard merupakan contoh dan ditandai pada layar. Tidak menggunakan data API atau akun pengguna.

## File untuk review

- `figcraft/one-link-redesign.figcraft`: dokumen native, 10 artboard, 408 layer editable.
- `figcraft/overview.png`: seluruh artboard.
- `figcraft/01.png` sampai `10.png`: render individual 1.5x.
- `figcraft/verification.json`: hasil verifikasi mesin dan batas pengujian.

## Hasil pemeriksaan kode

- `lib/constants/app_colors.dart`: hijau utama #1B4D3E, oranye aksen #E87C1E. Semua fill desain memakai token warna yang sudah ada; tidak menambah palet baru.
- `lib/screens/sales_dashboard_screen.dart`: sapaan/statistik supplier, mission summary, statistik tambahan, lalu grid menu. Rancangan memindahkan mission ke prioritas pertama agar tujuan kerja segera terbaca.
- `lib/screens/sales_dashboard_screen.dart`: warna tambahan pada beberapa menu dan kombinasi gradien/bayangan menambah persaingan visual. Rancangan membatasi aksen pada progres dan aksi utama.
- `lib/widgets/shared_bottom_navbar.dart`: item mengikuti permission dan role. Mockup menampilkan kondisi Sales dengan semua izin terkait; implementasi harus mempertahankan gating dan tidak menganggap semua akun punya lima tab.
- `lib/screens/canvassing/tasks_hub_screen.dart`: Tugas Saya dan Self Assign tetap satu kelompok.
- `lib/screens/canvassing/visit_plan_screen.dart`: peta, mission, GPS, scan prospek, check-in/out, skip, dan registrasi supplier merupakan fungsi existing. Artboard Visit di sini hanya menunjukkan daftar mission; peta dan seluruh alur tersebut belum dirancang rinci.
- `lib/main.dart`: aplikasi saat ini dikunci pada light mode. Rancangan mengikuti light mode tersebut.
- Working tree memiliki banyak perubahan pengguna. Pekerjaan sesi ini hanya menambah folder `design/`; source Flutter tidak diubah.

Pemeriksaan ini berbasis kode, bukan audit aplikasi Flutter yang sedang berjalan.

## Arah visual dan alasannya

ENERGY 1 / RHYTHM 2 / MOTION 1: aplikasi operasional lapangan dengan hierarki tenang, komposisi berbeda sesuai konten, dan perpindahan langsung.

- Warna: mempertahankan identitas One Link dari AppColors.
- Layout: kunjungan berikutnya menjadi fokus Beranda; daftar menampilkan nama, konteks, dan status dalam urutan tetap untuk pemindaian cepat.
- Tipografi: Arial tersedia lokal dan menjaga file desain portabel; implementasi mengikuti font platform Flutter dengan hierarki ukuran yang sama.
- Spasi: margin 24 px dan ritme dasar 8 px memisahkan kelompok informasi.
- Kartu: dipakai untuk mengelompokkan satu tugas, supplier, atau kunjungan; ringkasan statistik memakai baris tanpa kartu terpisah.
- Ikon: bentuk rumah, pin lokasi, checklist, jam, dan profil menggambarkan tujuan navigasi existing; bukan hiasan.
- Aksen: oranye hanya untuk progres, urutan kunjungan berikutnya, indikator tab, dan CTA prioritas. Teks gelap di atas oranye memiliki kontras lebih baik daripada teks putih.
- Radius: 10–12 px untuk baris/kontrol; 16–18 px untuk area prioritas.
- Motif identitas: hijau dominan, penanda garis oranye, dan hierarki tujuan kerja yang berulang.

## Cakupan artboard

01 Beranda Sales; 02 Visit; 03 Tugas; 04 Supplier; 05 Detail kunjungan; 06 Work Order; 07 Profil; 08 Riwayat; 09 loading/kosong/error; 10 fondasi desain.

Detail Tugas, detail Work Order, formulir, Self Assign, autentikasi, permission/GPS consent, dan semua variasi permission belum dirancang lengkap. Beberapa link menuju artboard konsep untuk membahas pola visual, bukan representasi final alur bisnis. Pencarian, filter, formulir, GPS, check-in, dan API tidak dijalankan.

## Delivery gate untuk rancangan visual

- PASS · Identitas: kedua kode warna utama sama persis dengan AppColors; fill netral juga dari token existing.
- PASS · Sumber konten: struktur layar berasal dari file yang dicantumkan; data rekaan diberi label contoh.
- PASS · Hierarki dan alasan: satu fokus per layar operasional, alasan warna/layout/tipografi/spasi/kartu/ikon tercatat di atas.
- PASS · Layout statis: overview dan render individual diperiksa pada kanvas 390 × 844; tidak terlihat teks terpotong atau bertumpuk pada hasil akhir.
- PASS · Kontras: putih/hijau 9,64:1; gelap/oranye 5,62:1; abu gelap/background 9,63:1; hijau/backgroundGrey 8,85:1.
- PASS · State visual: contoh loading, hasil kosong, dan error tersedia pada artboard 09.
- PASS · Dokumen: create/edit/save/reopen/export roundtrip lolos; struktur tetap sama; tidak ada font hilang.
- PASS · Struktur tautan: 71 target navigate merujuk artboard yang ada.

Gate ini hanya menilai rancangan visual statis. Interaksi presenter belum lulus verifikasi: percobaan klik tidak menunjukkan perpindahan stabil. Belum ada klaim aksesibilitas runtime, perilaku keyboard, responsivitas, build Flutter, atau pengujian fungsional. Penerimaan prototipe interaktif dan implementasi memerlukan pemeriksaan terpisah.

## Reproduksi

Buka instance FigCraft dengan control port 7979 dan automation read/write root ke folder `design/`. Jalankan `python3 design/figcraft/build_design.py`, lalu `python3 design/figcraft/verify_design.py`. Script build membuat dokumen baru dan menulis ulang output desain yang dihasilkan sesi ini; salin file terlebih dahulu bila sudah diedit manual. Script tidak membaca `.env` dan tidak menyentuh API aplikasi.

## Implementasi setelah review awal

Beranda Sales/CRO di `lib/screens/sales_dashboard_screen.dart` telah disesuaikan dengan arah artboard 01: sapaan ringkas, mission card sebagai prioritas, ringkasan supplier yang datanya tetap dari `DashboardStatsService`, daftar akses kerja yang tetap memakai permission dan callback existing, serta navigasi bawah dengan indikator oranye. Nama dan angka contoh dari file FigCraft tidak dipindahkan ke aplikasi. `newThisMonth` dilabeli "Baru bulan ini" sesuai nama field. Layar Sales lain di FigCraft sudah mulai diterapkan: Visit, Tugas, Supplier, dan Work Order mendapat pembaruan visual. Detail formulir dan alur Sales lain masih menunggu implementasi berikutnya. Driver tidak termasuk cakupan redesign.

Validasi implementasi: `dart format` pada layar yang disentuh, `flutter analyze --no-pub` pada Sales Dashboard dan layar Tugas (0 issue), serta `flutter build apk --debug --no-pub` berhasil. Analyzer pada Visit dan Supplier masih melaporkan lint yang sudah ada pada bagian kode di luar redesign; tidak ada error build. `git diff --check` bersih untuk file Sales yang memakai LF; Supplier mempertahankan CRLF dan membuat Git melaporkan trailing whitespace pada baris yang berubah. Belum ada uji layar pada perangkat, data API nyata, atau penerimaan visual Flutter; build APK hanya memverifikasi kompilasi.
