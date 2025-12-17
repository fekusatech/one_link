import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/surat_jalan.dart';
import 'navigation_screen.dart';

class SuratJalanDetailScreen extends StatelessWidget {
  final SuratJalan suratJalan;

  const SuratJalanDetailScreen({Key? key, required this.suratJalan})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detail ${suratJalan.kode}'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
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
              icon: const Icon(Icons.map),
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

  Widget _buildHeaderCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    suratJalan.kode,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  suratJalan.tanggalFormatted,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.receipt, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Kode Pickup: ${suratJalan.kodePickup}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverInfoCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Informasi Driver & Kendaraan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.person, 'Driver', suratJalan.driverName),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.directions_car, 'Plat Nomor', suratJalan.plat),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.location_on, 'Gudang', suratJalan.gudangName),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderInfoCard() {
    // Convert liter to kg using UCO density (0.9)
    double totalLiterDouble = double.tryParse(suratJalan.totalLiter) ?? 0.0;
    double totalKg = totalLiterDouble * 0.9;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Informasi Pesanan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.inventory,
              'Total Qty',
              '${suratJalan.totalQty} item',
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.check_circle,
              'Qty Terealisasi',
              '${suratJalan.totalQtyReal} item',
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.local_gas_station,
              'Total Volume',
              '${suratJalan.totalLiter} liter',
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.scale,
              'Total Berat',
              '${totalKg.toStringAsFixed(1)} kg',
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.attach_money,
              'Total Harga',
              'Rp ${_formatCurrency(suratJalan.totalHarga)}',
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.business,
              'Total Supplier',
              '${suratJalan.totalSuppliers} supplier',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Progress Pengambilan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: suratJalan.progress.percentage / 100,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(_getStatusColor()),
            ),
            const SizedBox(height: 8),
            Text(
              '${suratJalan.progress.percentage}% Selesai',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildProgressItem(
                    'Selesai',
                    suratJalan.progress.statusSummary.done,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildProgressItem(
                    'Pickup',
                    suratJalan.progress.statusSummary.pickup,
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildProgressItem(
                    'Pending',
                    '${suratJalan.progress.statusSummary.pending}',
                    Colors.grey,
                  ),
                ),
                Expanded(
                  child: _buildProgressItem(
                    'Batal',
                    suratJalan.progress.statusSummary.cancelled,
                    Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuppliersCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Detail Supplier',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (suratJalan.suratJalanDetail.isEmpty)
              const Text(
                'Tidak ada detail supplier',
                style: TextStyle(color: Colors.grey),
              )
            else
              ...suratJalan.suratJalanDetail.map(
                (detail) => _buildSupplierItem(detail),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupplierItem(SuratJalanDetail detail) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            detail.supplierName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            detail.supplierAlamat,
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildDetailInfo(
                  'Qty Order',
                  '${detail.qtyOrder} ${detail.satuan}',
                ),
              ),
              Expanded(
                child: _buildDetailInfo(
                  'Qty Real',
                  '${detail.qtyReal} ${detail.satuan}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildDetailInfo(
                  'Harga',
                  'Rp ${_formatCurrency(detail.harga)}',
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getDetailStatusColor(detail.status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    detail.status.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhotosSection() {
    // Kumpulkan semua foto dari detail yang ada
    List<String> allPhotos = [];
    for (var detail in suratJalan.suratJalanDetail) {
      if (detail.fotoUrl != null && detail.fotoUrl!.isNotEmpty) {
        allPhotos.add(detail.fotoUrl!);
      }
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dokumentasi Foto',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            if (allPhotos.isEmpty)
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.photo_camera, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        'Belum ada foto pickup',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: allPhotos.length,
                  itemBuilder: (context, index) {
                    return Container(
                      width: 200,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          allPhotos[index],
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value:
                                    loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[200],
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.error, color: Colors.red),
                                  Text('Gagal memuat foto'),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignatureSection() {
    // Kumpulkan semua tanda tangan dari detail yang ada
    List<String> allSignatures = [];
    for (var detail in suratJalan.suratJalanDetail) {
      if (detail.ttdUrl != null && detail.ttdUrl!.isNotEmpty) {
        allSignatures.add(detail.ttdUrl!);
      }
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tanda Tangan Digital',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            if (allSignatures.isEmpty)
              Container(
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.draw, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        'Belum ada tanda tangan',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
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
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                        color: Colors.white,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          allSignatures[index],
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value:
                                    loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[200],
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.error, color: Colors.red),
                                  Text('Gagal memuat TTD'),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text('$label: $value', style: const TextStyle(fontSize: 14)),
        ),
      ],
    );
  }

  Widget _buildProgressItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildDetailInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }

  Color _getStatusColor() {
    switch (suratJalan.status.toLowerCase()) {
      case 'done':
        return Colors.green;
      case 'progress':
        return Colors.orange;
      case 'pending':
        return Colors.grey;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
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
        return Colors.green;
      case 'progress':
      case 'pickup':
        return Colors.orange;
      case 'pending':
        return Colors.grey;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
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
