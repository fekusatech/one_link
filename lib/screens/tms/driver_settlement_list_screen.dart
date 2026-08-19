import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../models/tms/settlement_model.dart';
import '../../services/tms/tms_settlement_service.dart';
import 'driver_settlement_form_screen.dart';
import 'driver_settlement_detail_screen.dart';

class DriverSettlementListScreen extends StatefulWidget {
  const DriverSettlementListScreen({super.key});

  @override
  State<DriverSettlementListScreen> createState() => _DriverSettlementListScreenState();
}

class _DriverSettlementListScreenState extends State<DriverSettlementListScreen> {
  bool isLoading = true;
  List<SettlementMappingItem> settlements = [];
  String activeFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadSettlements();
  }

  Future<void> _loadSettlements() async {
    setState(() => isLoading = true);
    try {
      final list = await TmsSettlementService.getSettlements(
        status: activeFilter == 'all' ? null : activeFilter,
      );
      if (mounted) {
        setState(() {
          settlements = list;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: Text(
          'Settlement & Uang Jalan',
          style: AppTextStyles.h5.copyWith(
            color: AppColors.primaryGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppColors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('all', 'Semua'),
                  const SizedBox(width: 8),
                  _buildFilterChip('pending', 'Draft / Belum Dikerjakan'),
                  const SizedBox(width: 8),
                  _buildFilterChip('submitted', 'Dalam Review'),
                  const SizedBox(width: 8),
                  _buildFilterChip('approved', 'Disetujui'),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.lightGrey),
          // Content List
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadSettlements,
                    child: settlements.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              SizedBox(height: 100),
                              Center(
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.receipt_long_outlined,
                                      size: 64,
                                      color: AppColors.grey,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'Belum ada data settlement uang jalan',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: settlements.length,
                            itemBuilder: (context, index) {
                              final item = settlements[index];
                              final statusColor = _getStatusColor(item.settlementStatus);

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 2,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            item.kode ?? 'ST-${item.id}',
                                            style: AppTextStyles.bodyLarge.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primaryGreen,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: statusColor.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(color: statusColor),
                                            ),
                                            child: Text(
                                              (item.settlementStatus ?? 'Draft').toUpperCase(),
                                              style: TextStyle(
                                                color: statusColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(Icons.warehouse, size: 16, color: AppColors.grey),
                                          const SizedBox(width: 6),
                                          Text(
                                            item.gudangName ?? 'Gudang Utama',
                                            style: AppTextStyles.bodyMedium.copyWith(
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.calendar_today, size: 16, color: AppColors.grey),
                                          const SizedBox(width: 6),
                                          Text(
                                            item.tglKalkulasi ?? '-',
                                            style: AppTextStyles.bodyMedium.copyWith(
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 20),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Uang Jalan Diberikan',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.grey,
                                                ),
                                              ),
                                              Text(
                                                'Rp ${item.totalCostPlanned?.toStringAsFixed(0) ?? '0'}',
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                            ],
                                          ),
                                          FilledButton.icon(
                                            onPressed: () async {
                                              final isSubmitted = item.settlementStatus == 'submitted' ||
                                                  item.settlementStatus == 'approved';

                                              if (isSubmitted) {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => DriverSettlementDetailScreen(
                                                      calculationId: item.id,
                                                    ),
                                                  ),
                                                );
                                              } else {
                                                final result = await Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => DriverSettlementFormScreen(
                                                      calculationId: item.id,
                                                      plannedCost: item.totalCostPlanned ?? 0.0,
                                                    ),
                                                  ),
                                                );

                                                if (result == true) {
                                                  _loadSettlements();
                                                }
                                              }
                                            },
                                            icon: Icon(
                                              item.settlementStatus == 'submitted' || item.settlementStatus == 'approved'
                                                  ? Icons.visibility
                                                  : Icons.edit_note,
                                              size: 18,
                                            ),
                                            label: Text(
                                              item.settlementStatus == 'submitted' || item.settlementStatus == 'approved'
                                                  ? 'Lihat Detail'
                                                  : 'Isi Klaim',
                                            ),
                                            style: FilledButton.styleFrom(
                                              backgroundColor: AppColors.primaryGreen,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = activeFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primaryGreen.withOpacity(0.2),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primaryGreen : AppColors.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (_) {
        setState(() {
          activeFilter = value;
        });
        _loadSettlements();
      },
    );
  }
}
