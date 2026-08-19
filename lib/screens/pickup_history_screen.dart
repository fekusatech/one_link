import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

import '../services/surat_jalan_service.dart';
import '../services/geu/surat_jalan_service.dart';
import '../models/surat_jalan.dart';
import 'surat_jalan_detail_screen.dart';

class PickupHistoryScreen extends StatefulWidget {
  const PickupHistoryScreen({Key? key}) : super(key: key);

  @override
  State<PickupHistoryScreen> createState() => _PickupHistoryScreenState();
}

class _PickupHistoryScreenState extends State<PickupHistoryScreen> {
  List<SuratJalan> _allHistory = [];
  List<SuratJalan> _filteredHistory = [];

  bool _isLoading = true;
  String? _errorMessage;

  // Filter States
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatusFilter = 'all'; // 'all', 'done', 'cancel'
  String _selectedDatePreset = 'all'; // 'all', 'today', 'yesterday', '7days', 'custom'

  DateTime? _startDate;
  DateTime? _endDate;

  // Pagination States
  int _currentPage = 1;
  final int _itemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String? dateFromStr;
      String? dateToStr;

      if (_startDate != null) {
        dateFromStr = DateFormat('yyyy-MM-dd').format(_startDate!);
      }
      if (_endDate != null) {
        dateToStr = DateFormat('yyyy-MM-dd').format(_endDate!);
      }

      final all = await GeuSuratJalanService.listForDriver(
        dateFrom: dateFromStr,
        dateTo: dateToStr,
        limit: 200,
      );

      final history = all.where((s) {
        final st = s.status.toLowerCase();
        return st == 'done' || st == 'cancel' || st == 'cancelled';
      }).toList();

      if (mounted) {
        setState(() {
          _allHistory = history;
          _isLoading = false;
        });
        _applyFilters();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();

    List<SuratJalan> temp = List.from(_allHistory);

    // 1. Status Filter
    if (_selectedStatusFilter == 'done') {
      temp = temp.where((s) => s.status.toLowerCase() == 'done').toList();
    } else if (_selectedStatusFilter == 'cancel') {
      temp = temp.where((s) {
        final st = s.status.toLowerCase();
        return st == 'cancel' || st == 'cancelled';
      }).toList();
    }

    // 2. Date Filter
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final yesterdayStr = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));

    if (_selectedDatePreset == 'today') {
      temp = temp.where((s) => s.tanggal.startsWith(todayStr)).toList();
    } else if (_selectedDatePreset == 'yesterday') {
      temp = temp.where((s) => s.tanggal.startsWith(yesterdayStr)).toList();
    } else if (_selectedDatePreset == '7days') {
      final sevenDaysAgo = now.subtract(const Duration(days: 7));
      temp = temp.where((s) {
        try {
          final dt = DateTime.parse(s.tanggal.substring(0, 10));
          return dt.isAfter(sevenDaysAgo.subtract(const Duration(days: 1)));
        } catch (_) {
          return true;
        }
      }).toList();
    } else if (_selectedDatePreset == 'custom' && _startDate != null) {
      temp = temp.where((s) {
        try {
          final dt = DateTime.parse(s.tanggal.substring(0, 10));
          final start = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
          final end = _endDate != null
              ? DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59)
              : DateTime(_startDate!.year, _startDate!.month, _startDate!.day, 23, 59, 59);
          return dt.isAfter(start.subtract(const Duration(seconds: 1))) &&
              dt.isBefore(end.add(const Duration(seconds: 1)));
        } catch (_) {
          return true;
        }
      }).toList();
    }

    // 3. Search Query Filter
    if (query.isNotEmpty) {
      temp = temp.where((s) {
        final kodeMatch = s.kode.isNotEmpty
            ? s.kode.toLowerCase().contains(query)
            : s.suratJalanId.contains(query);
        final dateMatch = s.tanggalFormatted.toLowerCase().contains(query) || s.tanggal.contains(query);
        final detailMatch = s.suratJalanDetail.any((d) =>
            d.supplierName.toLowerCase().contains(query) ||
            d.supplierAlamat.toLowerCase().contains(query));
        return kodeMatch || dateMatch || detailMatch;
      }).toList();
    }

    setState(() {
      _filteredHistory = temp;
      _currentPage = 1;
    });
  }

  Future<void> _selectCustomDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : DateTimeRange(
              start: DateTime.now().subtract(const Duration(days: 1)),
              end: DateTime.now(),
            ),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryGreen,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _selectedDatePreset = 'custom';
      });
      _loadHistory();
    }
  }

  void _setDatePreset(String preset) {
    setState(() {
      _selectedDatePreset = preset;
      final now = DateTime.now();

      if (preset == 'all') {
        _startDate = null;
        _endDate = null;
      } else if (preset == 'today') {
        _startDate = now;
        _endDate = now;
      } else if (preset == 'yesterday') {
        final y = now.subtract(const Duration(days: 1));
        _startDate = y;
        _endDate = y;
      } else if (preset == '7days') {
        _startDate = now.subtract(const Duration(days: 7));
        _endDate = now;
      }
    });

    if (preset != 'custom') {
      _loadHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalItems = _filteredHistory.length;
    final totalPages = (totalItems / _itemsPerPage).ceil();
    final safeTotalPages = totalPages < 1 ? 1 : totalPages;

    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage) > totalItems
        ? totalItems
        : (startIndex + _itemsPerPage);

    final paginatedItems = (startIndex < totalItems)
        ? _filteredHistory.sublist(startIndex, endIndex)
        : <SuratJalan>[];

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
      body: Column(
        children: [
          // ── Search & Filter Header (Compact) ────────────────
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Search Field
                SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => _applyFilters(),
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Cari kode SJ / supplier...',
                      hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey, fontSize: 13),
                      prefixIcon: const Icon(Icons.search, color: AppColors.primaryGreen, size: 18),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16, color: AppColors.grey),
                              onPressed: () {
                                _searchController.clear();
                                _applyFilters();
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 14),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Date Presets (Row)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildPresetChip('all', 'Semua Tgl'),
                      const SizedBox(width: 6),
                      _buildPresetChip('today', 'Hari Ini'),
                      const SizedBox(width: 6),
                      _buildPresetChip('yesterday', 'Kemarin'),
                      const SizedBox(width: 6),
                      _buildPresetChip('7days', '7 Hari Terakhir'),
                      const SizedBox(width: 6),
                      ActionChip(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        visualDensity: VisualDensity.compact,
                        avatar: const Icon(Icons.date_range, size: 14, color: AppColors.primaryGreen),
                        label: Text(
                          _selectedDatePreset == 'custom' && _startDate != null
                              ? '${DateFormat('dd/MM').format(_startDate!)} - ${DateFormat('dd/MM').format(_endDate ?? _startDate!)}'
                              : 'Pilih Tanggal',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: _selectedDatePreset == 'custom' ? FontWeight.bold : FontWeight.normal,
                            color: _selectedDatePreset == 'custom' ? AppColors.primaryGreen : AppColors.textPrimary,
                          ),
                        ),
                        backgroundColor: _selectedDatePreset == 'custom'
                            ? AppColors.primaryGreen.withOpacity(0.15)
                            : AppColors.background,
                        onPressed: _selectCustomDateRange,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),

                // Status Presets (Row)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildStatusChip('all', 'Semua Status'),
                      const SizedBox(width: 6),
                      _buildStatusChip('done', 'Selesai'),
                      const SizedBox(width: 6),
                      _buildStatusChip('cancel', 'Dibatalkan'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.lightGrey),

          // ── History List View ──────────────────────────────
          Expanded(
            child: _isLoading
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
                    : paginatedItems.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.history, size: 56, color: AppColors.grey),
                                const SizedBox(height: 12),
                                Text(
                                  'Tidak ditemukan riwayat penjemputan',
                                  style: AppTextStyles.bodyLarge.copyWith(color: AppColors.grey),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Coba ubah kata kunci pencarian atau filter tanggal',
                                  style: TextStyle(fontSize: 12, color: AppColors.grey),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadHistory,
                            color: AppColors.primaryGreen,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                              itemCount: paginatedItems.length,
                              itemBuilder: (context, index) {
                                final item = paginatedItems[index];
                                return _buildHistoryCard(context, item);
                              },
                            ),
                          ),
          ),

          // ── Pagination Control Bar (Zero Overflow) ─────────
          if (!_isLoading && totalItems > 0)
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Menampilkan ${startIndex + 1}-$endIndex dari $totalItems data',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_left, size: 22),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: _currentPage > 1
                          ? () => setState(() => _currentPage--)
                          : null,
                    ),
                    Text(
                      '$_currentPage / $safeTotalPages',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, size: 22),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: _currentPage < safeTotalPages
                          ? () => setState(() => _currentPage++)
                          : null,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Helper Widgets ─────────────────────────────────────
  Widget _buildPresetChip(String key, String label) {
    final isSelected = _selectedDatePreset == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      visualDensity: VisualDensity.compact,
      selectedColor: AppColors.primaryGreen.withOpacity(0.18),
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? AppColors.primaryGreen : AppColors.textPrimary,
      ),
      onSelected: (_) => _setDatePreset(key),
    );
  }

  Widget _buildStatusChip(String key, String label) {
    final isSelected = _selectedStatusFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      visualDensity: VisualDensity.compact,
      selectedColor: AppColors.accentOrange.withOpacity(0.2),
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? AppColors.accentOrange : AppColors.textPrimary,
      ),
      onSelected: (_) {
        setState(() {
          _selectedStatusFilter = key;
        });
        _applyFilters();
      },
    );
  }

  Widget _buildHistoryCard(BuildContext context, SuratJalan item) {
    final bool isDone = item.status.toLowerCase() == 'done';
    final Color statusColor = isDone ? AppColors.success : AppColors.error;
    final String statusText = isDone
        ? 'Selesai'
        : (item.status.toLowerCase() == 'cancelled' || item.status.toLowerCase() == 'cancel'
            ? 'Batal'
            : item.status.toUpperCase());

    final String kodeTitle = item.kode.trim().isNotEmpty
        ? item.kode
        : 'Surat Jalan #${item.suratJalanId}';

    final totalKg = SuratJalanService.convertLiterToKg(item.totalLiter);

    return InkWell(
      onTap: () async {
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
          SuratJalan fullDetail;
          try {
            fullDetail = await GeuSuratJalanService.getById(int.parse(item.suratJalanId));
          } catch (_) {
            fullDetail = item;
          }

          if (context.mounted) {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SuratJalanDetailScreen(suratJalan: fullDetail),
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            Navigator.pop(context);
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
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      kodeTitle,
                      style: AppTextStyles.h6.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
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
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 14, color: AppColors.grey),
                  const SizedBox(width: 6),
                  Text(
                    item.tanggalFormatted != '-' ? item.tanggalFormatted : item.tanggal,
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey, fontSize: 12),
                  ),
                ],
              ),
              const Divider(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Supplier',
                          style: AppTextStyles.caption.copyWith(color: AppColors.grey, fontSize: 11),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.store, size: 14, color: AppColors.primaryGreen),
                            const SizedBox(width: 4),
                            Text(
                              '${item.totalSuppliers} Lokasi',
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
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
                          style: AppTextStyles.caption.copyWith(color: AppColors.grey, fontSize: 11),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.scale, size: 14, color: AppColors.primaryGreen),
                            const SizedBox(width: 4),
                            Text(
                              '$totalKg Kg',
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
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
