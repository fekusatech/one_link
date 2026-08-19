import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: AppColors.white,
        title: Text(
          'Kebijakan Privasi',
          style: AppTextStyles.h5.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection('Penggunaan Data Lokasi', [
              'Aplikasi One Link menggunakan data lokasi GPS Anda untuk:',
              '• Membantu navigasi rute pengantaran saat tugas aktif',
              '• Menampilkan supplier terdekat dari posisi Anda',
              '• Verifikasi kehadiran di lokasi penjemputan',
              '• Optimasi rute untuk efisiensi operasional',
              '• Laporan perjalanan dan analisis kinerja',
            ]),
            const SizedBox(height: 24),

            _buildSection('Keamanan Data', [
              'Kami melindungi data lokasi Anda dengan:',
              '• Enkripsi data saat transmisi dan penyimpanan',
              '• Akses terbatas hanya untuk operasional',
              '• Server aman dengan sertifikat SSL/TLS',
              '• Audit keamanan berkala',
            ]),
            const SizedBox(height: 24),

            _buildSection('Retensi Data', [
              'Data lokasi akan:',
              '• Disimpan maksimal 30 hari untuk keperluan operasional',
              '• Dihapus otomatis setelah periode tersebut',
              '• Dapat dihapus sewaktu-waktu atas permintaan Anda',
              '• Tidak dibagikan kepada pihak ketiga tanpa persetujuan',
            ]),
            const SizedBox(height: 24),

            _buildSection('Hak Pengguna', [
              'Anda memiliki hak untuk:',
              '• Menolak atau mencabut izin lokasi kapan saja',
              '• Meminta penghapusan data lokasi Anda',
              '• Mengakses data yang telah dikumpulkan',
              '• Mendapat informasi tentang penggunaan data',
            ]),
            const SizedBox(height: 24),

            _buildSection('Akses Lokasi Saat Aplikasi Tidak Dibuka', [
              'Aplikasi dapat menggunakan lokasi saat tidak dibuka hanya ketika:',
              '• Anda sedang dalam mode pengantaran aktif',
              '• Akses lokasi telah Anda setujui',
              '• Notifikasi penggunaan lokasi ditampilkan di status bar',
              '• Anda dapat mencabut izin lokasi kapan saja',
            ]),
            const SizedBox(height: 24),

            _buildSection('Transparansi', [
              'Kami berkomitmen untuk:',
              '• Memberikan informasi jelas tentang penggunaan data',
              '• Meminta persetujuan eksplisit sebelum menggunakan lokasi',
              '• Memberikan kontrol penuh kepada pengguna',
              '• Mematuhi regulasi perlindungan data',
            ]),
            const SizedBox(height: 24),

            _buildContactSection(),
            const SizedBox(height: 32),

            _buildLastUpdated(),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<String> content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.h6.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.primaryGreen,
          ),
        ),
        const SizedBox(height: 12),
        ...content.map(
          (text) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              text,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryGreen.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hubungi Kami',
            style: AppTextStyles.h6.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Jika Anda memiliki pertanyaan tentang kebijakan privasi ini atau ingin menggunakan hak Anda:',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Email: privacy@greenenergiutama.co.id\n'
            'Telepon: (021) 1234-5678\n'
            'Alamat: Jakarta, Indonesia',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastUpdated() {
    return Center(
      child: Text(
        'Terakhir diperbarui: ${DateTime.now().day} Desember 2025',
        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}
