import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../providers/supplier_form_provider.dart';
import '../providers/supplier_list_provider.dart';
import 'add_supplier_screen_simple.dart';
import 'supplier_list_screen.dart';

class SalesDashboardScreen extends StatefulWidget {
  const SalesDashboardScreen({super.key});

  @override
  State<SalesDashboardScreen> createState() => _SalesDashboardScreenState();
}

class _SalesDashboardScreenState extends State<SalesDashboardScreen> {
  // Sales statistics
  int _totalSuppliers = 0;
  int _activeSuppliers = 0;
  int _newThisMonth = 0;
  String _monthlyRevenue = '0';
  double _averageVolume = 0.0;
  bool _isLoading = true;

  // Map markers for suppliers
  Set<Marker> _markers = {};
  GoogleMapController? _mapController;

  // Sample data for statistics
  final List<Map<String, dynamic>> _recentActivity = [
    {
      'type': 'new_supplier',
      'title': 'Supplier Baru',
      'description': 'Warung Makan Sari Rasa bergabung',
      'time': '2 jam lalu',
      'icon': Icons.store_outlined,
      'color': AppColors.primaryGreen,
    },
    {
      'type': 'pickup_completed',
      'title': 'Pickup Selesai',
      'description': 'RM. Ayam Goreng - 25L dikonfirmasi',
      'time': '4 jam lalu',
      'icon': Icons.check_circle_outline,
      'color': AppColors.primaryGreen,
    },
    {
      'type': 'target_achieved',
      'title': 'Target Tercapai',
      'description': 'Target bulanan 85% tercapai',
      'time': '1 hari lalu',
      'icon': Icons.trending_up,
      'color': AppColors.accentOrange,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadSalesData();
    _setupSampleMarkers();
  }

  Future<void> _loadSalesData() async {
    // Simulate API call
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _totalSuppliers = 156;
      _activeSuppliers = 142;
      _newThisMonth = 12;
      _monthlyRevenue = '125.5';
      _averageVolume = 18.5;
      _isLoading = false;
    });
  }

  void _setupSampleMarkers() {
    _markers = {
      const Marker(
        markerId: MarkerId('supplier_1'),
        position: LatLng(-6.200000, 106.816666),
        infoWindow: InfoWindow(
          title: 'RM. Ayam Goreng Berkah',
          snippet: 'Volume: 25L/minggu',
        ),
      ),
      const Marker(
        markerId: MarkerId('supplier_2'),
        position: LatLng(-6.205000, 106.820000),
        infoWindow: InfoWindow(
          title: 'Warung Sari Rasa',
          snippet: 'Volume: 18L/minggu',
        ),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            backgroundColor: AppColors.primaryGreen,
            pinned: true,
            expandedHeight: 120,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Dashboard Sales',
                style: AppTextStyles.h5.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primaryGreen,
                      AppColors.primaryGreen.withOpacity(0.8),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                color: AppColors.white,
                onPressed: () {
                  // TODO: Show notifications
                },
              ),
              IconButton(
                icon: const Icon(Icons.person_outline),
                color: AppColors.white,
                onPressed: () {
                  // TODO: Show profile
                },
              ),
            ],
          ),

          // Main Content
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Statistics Cards
                _buildStatisticsSection(),
                const SizedBox(height: 24),

                // Quick Actions
                _buildQuickActions(),
                const SizedBox(height: 24),

                // Supplier Map
                _buildSupplierMap(),
                const SizedBox(height: 24),

                // Recent Activity
                _buildRecentActivity(),
                const SizedBox(height: 24),

                // Performance Charts (placeholder)
                _buildPerformanceSection(),
              ]),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChangeNotifierProvider(
                create: (_) => SupplierFormProvider(),
                child: const AddSupplierScreenSimple(),
              ),
            ),
          );
        },
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: AppColors.white,
        icon: const Icon(Icons.add_business),
        label: const Text('Tambah Supplier'),
      ),
    );
  }

  Widget _buildStatisticsSection() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGreen),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Statistik Hari Ini',
          style: AppTextStyles.h6.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),

        // Top Row - Main Stats
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Total Supplier',
                value: _totalSuppliers.toString(),
                subtitle: 'Terdaftar',
                icon: Icons.store,
                color: AppColors.primaryGreen,
                percentage:
                    '+${((_newThisMonth / _totalSuppliers) * 100).toStringAsFixed(1)}%',
                isPositive: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                title: 'Supplier Aktif',
                value: _activeSuppliers.toString(),
                subtitle: 'Beroperasi',
                icon: Icons.check_circle,
                color: AppColors.accentOrange,
                percentage:
                    '${((_activeSuppliers / _totalSuppliers) * 100).toStringAsFixed(0)}%',
                isPositive: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Bottom Row - Performance Stats
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Baru Bulan Ini',
                value: _newThisMonth.toString(),
                subtitle: 'Supplier',
                icon: Icons.trending_up,
                color: Colors.blue,
                percentage: '+23%',
                isPositive: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                title: 'Pendapatan',
                value: '₹$_monthlyRevenue M',
                subtitle: 'Bulan ini',
                icon: Icons.account_balance_wallet,
                color: Colors.purple,
                percentage: '+12%',
                isPositive: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String percentage,
    required bool isPositive,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isPositive
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  percentage,
                  style: AppTextStyles.caption.copyWith(
                    color: isPositive ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: AppTextStyles.h4.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            subtitle,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Aksi Cepat',
          style: AppTextStyles.h6.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                title: 'Tambah Supplier',
                subtitle: 'Daftarkan mitra baru',
                icon: Icons.add_business,
                color: AppColors.primaryGreen,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChangeNotifierProvider(
                        create: (_) => SupplierFormProvider(),
                        child: const AddSupplierScreenSimple(),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                title: 'Kelola Supplier',
                subtitle: 'Edit data existing',
                icon: Icons.edit_location,
                color: AppColors.accentOrange,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChangeNotifierProvider(
                        create: (_) => SupplierListProvider(),
                        child: const SupplierListScreen(),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupplierMap() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Peta Supplier',
          style: AppTextStyles.h6.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(-6.200000, 106.816666),
              zoom: 12,
            ),
            markers: _markers,
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
            },
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Aktivitas Terbaru',
              style: AppTextStyles.h6.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            TextButton(
              onPressed: () {
                // TODO: Show all activities
              },
              child: Text(
                'Lihat Semua',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.primaryGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: _recentActivity.length,
            separatorBuilder: (context, index) => const Divider(height: 20),
            itemBuilder: (context, index) {
              final activity = _recentActivity[index];
              return Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: activity['color'].withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      activity['icon'],
                      color: activity['color'],
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity['title'],
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          activity['description'],
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    activity['time'],
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Performa Bulan Ini',
          style: AppTextStyles.h6.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildPerformanceItem(
                    title: 'Target Bulanan',
                    value: '85%',
                    subtitle: 'tercapai',
                    color: AppColors.primaryGreen,
                  ),
                  _buildPerformanceItem(
                    title: 'Rata-rata Volume',
                    value: '${_averageVolume.toStringAsFixed(1)}L',
                    subtitle: 'per supplier',
                    color: AppColors.accentOrange,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Progress bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Progress Target',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        '85/100',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: 0.85,
                    backgroundColor: AppColors.grey.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primaryGreen,
                    ),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceItem({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: AppTextStyles.h4.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          subtitle,
          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
