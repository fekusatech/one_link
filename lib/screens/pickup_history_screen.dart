import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

import '../services/surat_jalan_service.dart';
import '../services/persistent_auth_service.dart';
import '../models/surat_jalan.dart';
import 'surat_jalan_detail_screen.dart';

class PickupHistoryScreen extends StatefulWidget {
  const PickupHistoryScreen({Key? key}) : super(key: key);

  @override
  State<PickupHistoryScreen> createState() => _PickupHistoryScreenState();
}

class _PickupHistoryScreenState extends State<PickupHistoryScreen> {
  List<SuratJalan> _historyList = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userData = await PersistentAuthService.instance.getUserData();
      if (userData != null && userData['userId'] != null) {
        final userId = userData['userId'].toString();
        _currentUserId = userId;
        // Fetch from real API (has fallback internally)
        final history = await SuratJalanService.getPickupHistory(userId: userId);
        
        setState(() {
          _historyList = history;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'User ID tidak ditemukan. Harap login kembali.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Riwayat Penjemputan',
          style: AppTextStyles.h4.copyWith(
            color: AppColors.primaryGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primaryGreen),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                      const SizedBox(height: 16),
                      Text(
                        'Gagal memuat data',
                        style: AppTextStyles.h6.copyWith(color: AppColors.error),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadHistory,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                        ),
                        child: const Text('Coba Lagi', style: TextStyle(color: Colors.white)),
                      )
                    ],
                  ),
                )
              : _historyList.isEmpty
                  ? Center(
                      child: Text(
                        'Belum ada riwayat penjemputan.',
                        style: AppTextStyles.bodyLarge.copyWith(color: AppColors.grey),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadHistory,
                      color: AppColors.primaryGreen,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _historyList.length,
                        itemBuilder: (context, index) {
                          final item = _historyList[index];
                          return _buildHistoryCard(context, item);
                        },
                      ),
                    ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, SuratJalan item) {
    final bool isDone = item.status.toLowerCase() == 'done';
    final Color statusColor = isDone ? AppColors.success : AppColors.error;
    final String statusText = isDone ? 'Selesai' : (item.status.toLowerCase() == 'cancelled' ? 'Batal' : item.status.toUpperCase());
    
    // In actual fallback mapping we map total_liter backwards to kg
    final totalKg = SuratJalanService.convertLiterToKg(item.totalLiter);

    return InkWell(
      onTap: () async {
        // Show loading dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
              ),
            );
          },
        );

        try {
          // Gunakan getSuratJalan dengan tanggal item agar cocok dengan histori
          SuratJalan? fullDetail;
          if (_currentUserId != null) {
            print('🔍 History Detail: Fetching full data for ID: ${item.suratJalanId}, date: ${item.tanggal}');
            final response = await SuratJalanService.getSuratJalan(
              userId: _currentUserId!,
              date: item.tanggal, // Gunakan tanggal item agar tidak default ke hari ini
            );
            try {
              fullDetail = response.data.suratJalan.firstWhere(
                (sj) => sj.suratJalanId == item.suratJalanId,
              );
              print('✅ History Detail: Found matching surat jalan');
            } catch (_) {
              print('⚠️ History Detail: ID not found, using history item as fallback');
              fullDetail = item;
            }
          } else {
            fullDetail = item;
          }
          
          if (context.mounted) {
            Navigator.pop(context); // close loading
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SuratJalanDetailScreen(suratJalan: fullDetail ?? item),
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            Navigator.pop(context); // close loading
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(e.toString().replaceAll('Exception: ', '')),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item.kode,
                    style: AppTextStyles.h6.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withOpacity(0.5)),
                    ),
                    child: Text(
                      statusText,
                      style: AppTextStyles.caption.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: AppColors.grey),
                  const SizedBox(width: 8),
                  Text(
                    item.tanggalFormatted != '-' ? item.tanggalFormatted : item.tanggal,
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Supplier',
                          style: AppTextStyles.caption.copyWith(color: AppColors.grey),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.store, size: 16, color: AppColors.primaryGreen),
                            const SizedBox(width: 4),
                            Text(
                              '${item.totalSuppliers} Lokasi',
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Muatan',
                          style: AppTextStyles.caption.copyWith(color: AppColors.grey),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.scale, size: 16, color: AppColors.primaryGreen),
                            const SizedBox(width: 4),
                            Text(
                              '$totalKg Kg',
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
