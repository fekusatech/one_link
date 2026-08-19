import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/surat_jalan.dart';
import 'navigation_screen.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

class SuratJalanDetailScreen extends StatelessWidget {
  final SuratJalan suratJalan;

  const SuratJalanDetailScreen({Key? key, required this.suratJalan})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: Text(
          'Detail ${suratJalan.kode}',
          style: AppTextStyles.h4.copyWith(
            color: AppColors.primaryGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.primaryGreen),
        actions: [
          if (suratJalan.status == 'progress')
            IconButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      NavigationScreen(suratJalan: suratJalan),
                ),
              ),
              icon: const Icon(Icons.map, color: AppColors.primaryGreen),
              tooltip: 'Buka Navigation',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 16),
            _buildDriverInfoCard(),
            const SizedBox(height: 16),
            _buildOrderInfoCard(),
            const SizedBox(height: 16),
            _buildProgressCard(),
            const SizedBox(height: 16),
            _buildSuppliersCard(),
            const SizedBox(height: 16),
            _buildPhotosSection(),
            const SizedBox(height: 16),
            _buildSignatureSection(),
          ],
        ),
      ),
    );
  }

  // Helper method for standardizing cards
  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }

  Widget _buildHeaderCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  suratJalan.kode,
                  style: AppTextStyles.h6.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor(),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _getStatusText(),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(
                suratJalan.tanggalFormatted,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.receipt, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(
                'Kode Pickup: ${suratJalan.kodePickup}',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDriverInfoCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Informasi Driver & Kendaraan',
            style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.person, 'Driver', suratJalan.driverName),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.directions_car, 'Plat Nomor', suratJalan.plat),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.location_on, 'Gudang', suratJalan.gudangName),
        ],
      ),
    );
  }

  Widget _buildOrderInfoCard() {
    double totalLiterDouble = double.tryParse(suratJalan.totalLiter) ?? 0.0;
    double totalKg = totalLiterDouble * 0.9;

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Informasi Pesanan',
            style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.inventory, 'Total Qty', '${suratJalan.totalQty} item'),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.check_circle, 'Qty Terealisasi', '${suratJalan.totalQtyReal} item'),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.local_gas_station, 'Total Volume', '${suratJalan.totalLiter} liter'),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.scale, 'Total Berat', '${totalKg.toStringAsFixed(1)} kg'),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.attach_money, 'Total Harga', 'Rp ${_formatCurrency(suratJalan.totalHarga)}'),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.business, 'Total Supplier', '${suratJalan.totalSuppliers} supplier'),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Progress Pengambilan',
            style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: suratJalan.progress.percentage / 100,
              backgroundColor: AppColors.lightGrey,
              valueColor: AlwaysStoppedAnimation<Color>(_getStatusColor()),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${suratJalan.progress.percentage}% Selesai',
            style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildProgressItem('Selesai', suratJalan.progress.statusSummary.done, AppColors.success),
              ),
              Expanded(
                child: _buildProgressItem('Pickup', suratJalan.progress.statusSummary.pickup, AppColors.warning),
              ),
              Expanded(
                child: _buildProgressItem('Pending', '${suratJalan.progress.statusSummary.pending}', AppColors.grey),
              ),
              Expanded(
                child: _buildProgressItem('Batal', suratJalan.progress.statusSummary.cancelled, AppColors.error),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuppliersCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Detail Supplier',
            style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (suratJalan.suratJalanDetail.isEmpty)
            Text(
              'Tidak ada detail supplier',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            )
          else
            ...suratJalan.suratJalanDetail.map((detail) => _buildSupplierItem(detail)),
        ],
      ),
    );
  }

  Widget _buildSupplierItem(SuratJalanDetail detail) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundGrey,
        border: Border.all(color: AppColors.borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            detail.supplierName,
            style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            detail.supplierAlamat,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildDetailInfo('Qty Order', '${detail.qtyOrder} ${detail.satuan}'),
                    ),
                    Expanded(
                      child: _buildDetailInfo('Qty Real', '${detail.qtyReal} ${detail.satuan}'),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _buildDetailInfo('Harga', 'Rp ${_formatCurrency(detail.harga)}'),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getDetailStatusColor(detail.status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _getDetailStatusColor(detail.status).withOpacity(0.5),
                            ),
                          ),
                          child: Text(
                            detail.status.toUpperCase(),
                            style: AppTextStyles.caption.copyWith(
                              color: _getDetailStatusColor(detail.status),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotosSection() {
    List<String> allPhotos = [];
    for (var detail in suratJalan.suratJalanDetail) {
      if (detail.fotoUrl != null && detail.fotoUrl!.isNotEmpty) {
        allPhotos.add(detail.fotoUrl!);
      }
    }

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dokumentasi Foto',
            style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (allPhotos.isEmpty)
            Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.backgroundGrey,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.photo_camera, size: 48, color: AppColors.grey),
                  const SizedBox(height: 8),
                  Text(
                    'Belum ada foto pickup',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 160,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: allPhotos.length,
                itemBuilder: (context, index) {
                  return Container(
                    width: 160,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderColor),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => Dialog(
                              backgroundColor: Colors.transparent,
                              insetPadding: const EdgeInsets.all(10),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  InteractiveViewer(
                                    panEnabled: true,
                                    minScale: 0.5,
                                    maxScale: 4,
                                    child: Image.network(
                                      allPhotos[index],
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  Positioned(
                                    top: 10,
                                    right: 10,
                                    child: IconButton(
                                      icon: const Icon(Icons.close, color: Colors.white, size: 30),
                                      onPressed: () => Navigator.of(context).pop(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        child: Image.network(
                          allPhotos[index],
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: AppColors.backgroundGrey,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.error, color: AppColors.error),
                                  Text('Gagal memuat', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSignatureSection() {
    List<String> allSignatures = [];
    for (var detail in suratJalan.suratJalanDetail) {
      if (detail.ttdUrl != null && detail.ttdUrl!.isNotEmpty) {
        allSignatures.add(detail.ttdUrl!);
      }
    }

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tanda Tangan Digital',
            style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (allSignatures.isEmpty)
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.backgroundGrey,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.draw, size: 48, color: AppColors.grey),
                  const SizedBox(height: 8),
                  Text(
                    'Belum ada tanda tangan',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 150,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: allSignatures.length,
                itemBuilder: (context, index) {
                  return Container(
                    width: 200,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderColor),
                      color: AppColors.white,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => Dialog(
                              backgroundColor: Colors.transparent,
                              insetPadding: const EdgeInsets.all(10),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  InteractiveViewer(
                                    panEnabled: true,
                                    minScale: 0.5,
                                    maxScale: 4,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.all(8),
                                      child: Image.network(
                                        allSignatures[index],
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 10,
                                    right: 10,
                                    child: IconButton(
                                      icon: const Icon(Icons.close, color: Colors.white, size: 30),
                                      onPressed: () => Navigator.of(context).pop(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        child: Image.network(
                          allSignatures[index],
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: AppColors.backgroundGrey,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.error, color: AppColors.error),
                                  Text('Gagal memuat', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
              children: [
                TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: AppTextStyles.h6.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildDetailInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text(value, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Color _getStatusColor() {
    switch (suratJalan.status.toLowerCase()) {
      case 'done':
        return AppColors.success;
      case 'progress':
        return AppColors.warning;
      case 'pending':
        return AppColors.grey;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.grey;
    }
  }

  String _getStatusText() {
    switch (suratJalan.status.toLowerCase()) {
      case 'done':
        return 'SELESAI';
      case 'progress':
        return 'PROSES';
      case 'pending':
        return 'PENDING';
      case 'cancelled':
        return 'BATAL';
      default:
        return suratJalan.status.toUpperCase();
    }
  }

  Color _getDetailStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'done':
        return AppColors.success;
      case 'progress':
      case 'pickup':
        return AppColors.warning;
      case 'pending':
        return AppColors.grey;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.grey;
    }
  }

  String _formatCurrency(String amount) {
    try {
      double value = double.parse(amount);
      return value
          .toStringAsFixed(0)
          .replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match match) => '${match[1]}.',
          );
    } catch (e) {
      return amount;
    }
  }

  void _openGoogleMaps() async {
    if (suratJalan.gudangGps.isNotEmpty) {
      try {
        // Parse GPS coordinates
        List<String> coords = suratJalan.gudangGps.split(',');
        if (coords.length == 2) {
          String lat = coords[0].trim();
          String lng = coords[1].trim();

          // Create Google Maps URL
          final url =
              'https://www.google.com/maps/search/?api=1&query=$lat,$lng';

          if (await canLaunchUrl(Uri.parse(url))) {
            await launchUrl(
              Uri.parse(url),
              mode: LaunchMode.externalApplication,
            );
          } else {
            // Fallback: try to open with maps app
            final mapsUrl = 'geo:$lat,$lng';
            if (await canLaunchUrl(Uri.parse(mapsUrl))) {
              await launchUrl(Uri.parse(mapsUrl));
            }
          }
        }
      } catch (e) {
        // Handle error silently or show snackbar
        debugPrint('Error opening maps: $e');
      }
    }
  }
}
