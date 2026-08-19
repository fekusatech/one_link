import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../models/tms/settlement_model.dart';
import '../../services/tms/tms_settlement_service.dart';

class DriverSettlementDetailScreen extends StatefulWidget {
  final int calculationId;

  const DriverSettlementDetailScreen({
    super.key,
    required this.calculationId,
  });

  @override
  State<DriverSettlementDetailScreen> createState() => _DriverSettlementDetailScreenState();
}

class _DriverSettlementDetailScreenState extends State<DriverSettlementDetailScreen> {
  bool isLoading = true;
  SettlementDetailFull? detail;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => isLoading = true);
    try {
      final res = await TmsSettlementService.getSettlementById(widget.calculationId);
      if (mounted) {
        setState(() {
          detail = res;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'approved':
      case 'paid':
        return AppColors.success;
      case 'submitted':
      case 'review':
        return AppColors.warning;
      case 'rejected':
        return AppColors.error;
      default:
        return AppColors.info;
    }
  }

  void _showImageZoomDialog(String title, Uint8List? imageBytes, String? imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: imageBytes != null
                    ? Image.memory(imageBytes, fit: BoxFit.contain)
                    : (imageUrl != null
                        ? Image.network(imageUrl, fit: BoxFit.contain)
                        : const SizedBox.shrink()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settlement = detail?.settlement;
    final calc = detail?.calculation;
    final statusColor = _getStatusColor(settlement?.status ?? calc?.settlementStatus);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: Text(
          'Detail Settlement #${widget.calculationId}',
          style: AppTextStyles.h5.copyWith(
            color: AppColors.primaryGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : detail == null
              ? const Center(child: Text('Gagal memuat detail settlement.'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Header Status Card
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  calc?.kode ?? 'Settlement #${calc?.id}',
                                  style: AppTextStyles.h5.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryGreen,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: statusColor),
                                  ),
                                  child: Text(
                                    (settlement?.status ?? calc?.settlementStatus ?? 'Draft').toUpperCase(),
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text('Gudang: ${calc?.gudangName ?? '-'}'),
                            Text('Driver: ${calc?.driverName ?? '-'}'),
                            Text('Tanggal: ${calc?.tglKalkulasi ?? '-'}'),
                            const Divider(height: 20),
                            // Read-only Lock Indicator
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.lightGrey,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.lock_outline, size: 16, color: AppColors.grey),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Settlement yang sudah diajukan bersifat read-only. Tidak dapat diubah atau dihapus.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Ringkasan Keuangan
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ringkasan Keuangan (Rp)',
                              style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const Divider(height: 20),
                            _buildInfoRow('Uang Jalan Awal (Planned)', 'Rp ${settlement?.plannedTotalCost.toStringAsFixed(0) ?? calc?.totalCostPlanned?.toStringAsFixed(0) ?? '0'}'),
                            _buildInfoRow('Total Pengeluaran Realisasi', 'Rp ${settlement?.totalActualCost.toStringAsFixed(0) ?? '0'}'),
                            const Divider(height: 20),
                            _buildInfoRow(
                              'Selisih Variance',
                              'Rp ${settlement?.varianceAmount.abs().toStringAsFixed(0) ?? '0'}',
                              valueColor: (settlement?.varianceAmount ?? 0) >= 0 ? AppColors.success : AppColors.error,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Rincian Biaya Realisasi
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Rincian Pengeluaran Realisasi',
                              style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const Divider(height: 20),
                            _buildInfoRow('BBM / Solar', 'Rp ${settlement?.actualFuelCost.toStringAsFixed(0) ?? '0'}'),
                            _buildInfoRow('Biaya Tol', 'Rp ${settlement?.actualTollCost.toStringAsFixed(0) ?? '0'}'),
                            _buildInfoRow('Biaya Parkir', 'Rp ${settlement?.actualParkingCost.toStringAsFixed(0) ?? '0'}'),
                            _buildInfoRow('Biaya Lainnya', 'Rp ${settlement?.actualOtherCosts.toStringAsFixed(0) ?? '0'}'),
                            _buildInfoRow('Non-Receipt (Tanpa Struk)', 'Rp ${settlement?.actualNonReceiptCost.toStringAsFixed(0) ?? '0'}'),
                            if (settlement?.alasanNonReceipt != null && settlement!.alasanNonReceipt!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Alasan Non-Receipt: ${settlement.alasanNonReceipt}',
                                style: const TextStyle(fontStyle: FontStyle.italic, color: AppColors.grey),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // ── Photo Attachments Section (Bukti Struk Nota Realisasi) ──
                    if (settlement != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Lampiran Struk & Nota Realisasi',
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                      _buildPhotoAttachmentCard('Bukti Struk BBM / Solar', settlement.buktiFuelPath),
                      _buildPhotoAttachmentCard('Bukti Struk E-Toll', settlement.buktiTollPath),
                      _buildPhotoAttachmentCard('Bukti Struk Parkir', settlement.buktiParkingPath),
                      _buildPhotoAttachmentCard('Bukti Pengeluaran Non-Receipt', settlement.buktiNonReceiptPath),
                      _buildPhotoAttachmentCard('Bukti Pengeluaran Lainnya', settlement.buktiOtherPath),

                      // Multi-item attachments from settlement_items_json
                      for (var item in settlement.settlementItems)
                        if (item.fileData != null && item.fileData!.isNotEmpty)
                          _buildPhotoAttachmentCard('Bukti Nota (${item.category.toUpperCase()} - ${item.notes})', item.fileData),
                    ],

                    if (settlement?.rejectionReason != null && settlement!.rejectionReason!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Card(
                        color: AppColors.error.withOpacity(0.1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.error_outline, color: AppColors.error),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Alasan Penolakan Finance',
                                    style: AppTextStyles.bodyLarge.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.error,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                settlement.rejectionReason!,
                                style: const TextStyle(color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
    );
  }

  Widget _buildPhotoAttachmentCard(String title, String? rawPath) {
    if (rawPath == null || rawPath.trim().isEmpty || rawPath == 'null') {
      return const SizedBox.shrink();
    }

    String? imageUrl;
    Uint8List? imageBytes;
    String clean = rawPath.trim();

    // Check if JSON payload {"name": "...", "data": "data:image/..."}
    if (clean.startsWith('{') && clean.contains('"data"')) {
      try {
        final parsed = jsonDecode(clean);
        if (parsed is Map && parsed['data'] != null) {
          clean = parsed['data'].toString();
        }
      } catch (_) {}
    }

    // Handle Base64 Data URI vs HTTP URL vs Relative ERP Path
    if (clean.startsWith('data:image')) {
      try {
        final base64Str = clean.split(',').last;
        imageBytes = base64Decode(base64Str);
      } catch (_) {}
    } else if (clean.startsWith('http://') || clean.startsWith('https://')) {
      imageUrl = clean;
    } else {
      // Relative path: prefix with erp.greenenergiutama.co.id domain
      final relativePath = clean.startsWith('/') ? clean.substring(1) : clean;
      imageUrl = 'https://erp.greenenergiutama.co.id/$relativePath';
    }

    return Card(
      margin: const EdgeInsets.only(top: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.photo_library, size: 18, color: AppColors.primaryGreen),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                _showImageZoomDialog(title, imageBytes, imageUrl);
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: imageBytes != null
                    ? Image.memory(
                        imageBytes,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      )
                    : (imageUrl != null
                        ? Image.network(
                            imageUrl,
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              height: 120,
                              color: Colors.grey.shade200,
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.broken_image, color: Colors.grey),
                                  SizedBox(height: 4),
                                  Text(
                                    'Gagal memuat gambar nota',
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : const SizedBox.shrink()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
