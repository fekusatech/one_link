import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../models/surat_jalan.dart';
import '../services/surat_jalan_service.dart';
import 'surat_jalan_detail_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _selectedDate = DateTime.now();
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 2));
  DateTime _endDate = DateTime.now().add(const Duration(days: 2));

  // Filter states
  String _selectedStatus = 'all'; // all, done, pickup, pending, cancelled
  bool _isLoading = false;
  String? _errorMessage;

  // API data
  List<SuratJalan> _suratJalanList = [];
  final String _userId = '128'; // hardcoded sesuai permintaan

  // Filter options
  final Map<String, String> _statusOptions = {
    'all': 'Semua',
    'done': 'Selesai',
    'pickup': 'Pickup',
    'pending': 'Pending',
    'cancelled': 'Dibatalkan',
  };

  @override
  void initState() {
    super.initState();
    _loadSuratJalanData();
  }

  Future<void> _loadSuratJalanData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Use single date format based on selected date
      final selectedDateStr =
          '${_selectedDate.year.toString().padLeft(4, '0')}-'
          '${_selectedDate.month.toString().padLeft(2, '0')}-'
          '${_selectedDate.day.toString().padLeft(2, '0')}';

      print('📅 Calendar loading data:');
      print('  Selected Date: $selectedDateStr');
      print('  Selected Status: ${_selectedStatus}');
      print('  User ID: $_userId');

      final response = await SuratJalanService.getSuratJalan(
        userId: _userId,
        status: _selectedStatus == 'all' ? null : _selectedStatus,
        date: selectedDateStr, // Use single date instead of date range
      );

      setState(() {
        _suratJalanList = response.data.suratJalan;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _updateDateRange() {
    // Just reload data for the selected date
    _loadSuratJalanData();
  }

  List<SuratJalan> _getSuratJalanForDate(DateTime date) {
    return _suratJalanList.where((surat) {
      try {
        // Parse tanggal dari surat jalan
        final parts = surat.tanggal.split('-');
        if (parts.length == 3) {
          final suratDate = DateTime(
            int.parse(parts[0]), // year
            int.parse(parts[1]), // month
            int.parse(parts[2]), // day
          );
          return suratDate.year == date.year &&
              suratDate.month == date.month &&
              suratDate.day == date.day;
        }
      } catch (e) {
        // Skip entries with invalid date format
      }
      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final todaySuratJalan = _getSuratJalanForDate(_selectedDate);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: Text(
          'Jadwal Surat Jalan',
          style: AppTextStyles.h5.copyWith(
            color: AppColors.primaryGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            color: AppColors.primaryGreen,
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            color: AppColors.primaryGreen,
            onPressed: _loadSuratJalanData,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Status Bar
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.filter_list,
                  size: 18,
                  color: AppColors.primaryGreen,
                ),
                const SizedBox(width: 8),
                Text(
                  'Status: ${_statusOptions[_selectedStatus]}',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'Tanggal: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primaryGreen,
                  ),
                ),
                const Spacer(),
                if (_isLoading)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primaryGreen,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Calendar widget placeholder
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      color: AppColors.primaryGreen,
                      onPressed: () {
                        setState(() {
                          _selectedDate = _selectedDate.subtract(
                            const Duration(days: 1),
                          );
                        });
                        _updateDateRange();
                      },
                    ),
                    Text(
                      '${_selectedDate.day} ${_getMonthName(_selectedDate.month)} ${_selectedDate.year}',
                      style: AppTextStyles.h5.copyWith(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      color: AppColors.primaryGreen,
                      onPressed: () {
                        setState(() {
                          _selectedDate = _selectedDate.add(
                            const Duration(days: 1),
                          );
                        });
                        _updateDateRange();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(7, (index) {
                    final date = _selectedDate.subtract(
                      Duration(days: _selectedDate.weekday - 1 - index),
                    );
                    final isSelected = date.day == _selectedDate.day;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedDate = date;
                        });
                        _updateDateRange();
                      },
                      child: Container(
                        width: 40,
                        height: 60,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primaryGreen
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _getDayName(date.weekday),
                              style: AppTextStyles.caption.copyWith(
                                color: isSelected
                                    ? AppColors.white
                                    : AppColors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${date.day}',
                              style: AppTextStyles.bodyLarge.copyWith(
                                color: isSelected
                                    ? AppColors.white
                                    : AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),

          // Surat Jalan list
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primaryGreen,
                      ),
                    ),
                  )
                : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 80,
                          color: AppColors.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error: $_errorMessage',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadSuratJalanData,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                          ),
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  )
                : todaySuratJalan.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_busy,
                          size: 80,
                          color: AppColors.grey.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Tidak ada surat jalan',
                          style: AppTextStyles.h5.copyWith(
                            color: AppColors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'pada ${_selectedDate.day} ${_getMonthName(_selectedDate.month)} ${_selectedDate.year}',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: todaySuratJalan.length,
                    itemBuilder: (context, index) {
                      final surat = todaySuratJalan[index];
                      return _buildSuratJalanCard(surat);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuratJalanCard(SuratJalan surat) {
    final statusColor = surat.status == 'done'
        ? AppColors.primaryGreen
        : surat.status == 'pickup'
        ? const Color(0xFFFF9500)
        : AppColors.error;

    final statusText = surat.status == 'done'
        ? 'Selesai'
        : surat.status == 'pickup'
        ? 'Pickup'
        : 'Pending';

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SuratJalanDetailScreen(suratJalan: surat),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.background),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header dengan kode surat jalan
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.05),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      surat.kode,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusText,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Supplier info
                  Row(
                    children: [
                      Icon(
                        Icons.business,
                        size: 16,
                        color: AppColors.primaryGreen,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          surat.supplierNames,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.black,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Driver dan plat
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.person, size: 16, color: AppColors.grey),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                surat.driverName,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.grey,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.local_shipping,
                            size: 16,
                            color: AppColors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            surat.plat,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Quantity dan harga
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.scale,
                                size: 16,
                                color: AppColors.primaryGreen,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${SuratJalanService.convertLiterToKg(surat.totalLiter)} kg',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.primaryGreen,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.attach_money,
                                size: 16,
                                color: AppColors.primaryGreen,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  SuratJalanService.formatCurrency(
                                    surat.totalHarga,
                                  ),
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.primaryGreen,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Progress bar
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Progress',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.grey,
                            ),
                          ),
                          Text(
                            '${surat.progress.percentage}%',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.primaryGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: surat.progress.percentage / 100,
                        backgroundColor: AppColors.background,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          surat.progress.percentage == 100
                              ? AppColors.primaryGreen
                              : const Color(0xFFFF9500),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Tanggal
                  Text(
                    'Tanggal: ${surat.tanggalFormatted}',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Filter Surat Jalan',
          style: AppTextStyles.h5.copyWith(
            color: AppColors.primaryGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Status:',
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _statusOptions.entries.map((entry) {
                final isSelected = _selectedStatus == entry.key;
                return FilterChip(
                  selected: isSelected,
                  label: Text(entry.value),
                  selectedColor: AppColors.primaryGreen.withOpacity(0.2),
                  checkmarkColor: AppColors.primaryGreen,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedStatus = entry.key;
                      });
                      Navigator.pop(context);
                      _loadSuratJalanData();
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text(
              'Tanggal: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Tutup',
              style: TextStyle(color: AppColors.primaryGreen),
            ),
          ),
        ],
      ),
    );
  }

  String _getDayName(int weekday) {
    const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    return days[weekday - 1];
  }

  String _getMonthName(int month) {
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return months[month - 1];
  }
}
