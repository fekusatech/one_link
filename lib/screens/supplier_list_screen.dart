import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import 'add_supplier_screen_simple.dart';

class SupplierListScreen extends StatefulWidget {
  const SupplierListScreen({super.key});

  @override
  State<SupplierListScreen> createState() => _SupplierListScreenState();
}

class _SupplierListScreenState extends State<SupplierListScreen> {
  final _searchController = TextEditingController();
  String _selectedFilter = 'Semua';
  String _selectedCategory = 'Semua';
  bool _isLoading = false;

  // Sample supplier data
  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> _filteredSuppliers = [];

  final List<String> _filterOptions = [
    'Semua',
    'Aktif',
    'Pending',
    'Tidak Aktif',
  ];

  final List<String> _categoryOptions = [
    'Semua',
    'Restoran',
    'Hotel',
    'Warung Makan',
    'Fast Food',
    'Katering',
    'Pabrik Makanan',
    'Lainnya',
  ];

  @override
  void initState() {
    super.initState();
    _loadSupplierData();
    _searchController.addListener(_filterSuppliers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSupplierData() async {
    setState(() {
      _isLoading = true;
    });

    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _suppliers = [
        {
          'id': '1',
          'business_name': 'RM. Ayam Goreng Berkah',
          'contact_person': 'Budi Santoso',
          'phone': '081234567890',
          'address': 'Jl. Veteran No. 12, Malang',
          'category': 'Restoran',
          'estimated_volume': '25',
          'status': 'Aktif',
          'last_pickup': '2 hari lalu',
          'total_volume_collected': '150L',
          'join_date': '15 Jan 2024',
        },
        {
          'id': '2',
          'business_name': 'Warung Makan Sari Rasa',
          'contact_person': 'Sari Dewi',
          'phone': '081234567891',
          'address': 'Jl. Soekarno Hatta No. 45, Malang',
          'category': 'Warung Makan',
          'estimated_volume': '18',
          'status': 'Aktif',
          'last_pickup': '1 hari lalu',
          'total_volume_collected': '89L',
          'join_date': '20 Jan 2024',
        },
        {
          'id': '3',
          'business_name': 'Hotel Grand Malang',
          'contact_person': 'Ahmad Rahman',
          'phone': '081234567892',
          'address': 'Jl. Tugu No. 3, Malang',
          'category': 'Hotel',
          'estimated_volume': '50',
          'status': 'Pending',
          'last_pickup': 'Belum pernah',
          'total_volume_collected': '0L',
          'join_date': '28 Jan 2024',
        },
        {
          'id': '4',
          'business_name': 'KFC Dinoyo',
          'contact_person': 'Manager KFC',
          'phone': '081234567893',
          'address': 'Jl. MT Haryono No. 167, Malang',
          'category': 'Fast Food',
          'estimated_volume': '35',
          'status': 'Aktif',
          'last_pickup': '3 hari lalu',
          'total_volume_collected': '210L',
          'join_date': '10 Jan 2024',
        },
        {
          'id': '5',
          'business_name': 'Catering Sehat Berkah',
          'contact_person': 'Ibu Fatimah',
          'phone': '081234567894',
          'address': 'Jl. Kawi No. 12, Malang',
          'category': 'Katering',
          'estimated_volume': '40',
          'status': 'Tidak Aktif',
          'last_pickup': '2 minggu lalu',
          'total_volume_collected': '95L',
          'join_date': '05 Jan 2024',
        },
      ];
      _filteredSuppliers = List.from(_suppliers);
      _isLoading = false;
    });
  }

  void _filterSuppliers() {
    setState(() {
      _filteredSuppliers = _suppliers.where((supplier) {
        final matchesSearch =
            supplier['business_name'].toLowerCase().contains(
              _searchController.text.toLowerCase(),
            ) ||
            supplier['contact_person'].toLowerCase().contains(
              _searchController.text.toLowerCase(),
            );

        final matchesStatus =
            _selectedFilter == 'Semua' || supplier['status'] == _selectedFilter;

        final matchesCategory =
            _selectedCategory == 'Semua' ||
            supplier['category'] == _selectedCategory;

        return matchesSearch && matchesStatus && matchesCategory;
      }).toList();
    });
  }

  void _editSupplier(Map<String, dynamic> supplier) {
    // TODO: Navigate to edit supplier screen
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Supplier'),
        content: Text(
          'Fitur edit akan ditambahkan. Supplier: ${supplier['business_name']}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _deleteSupplier(Map<String, dynamic> supplier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus Supplier'),
        content: Text(
          'Apakah Anda yakin ingin menghapus ${supplier['business_name']}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _suppliers.removeWhere((s) => s['id'] == supplier['id']);
                _filterSuppliers();
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${supplier['business_name']} berhasil dihapus',
                  ),
                  backgroundColor: AppColors.primaryGreen,
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Hapus'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: AppColors.white,
        title: Text(
          'Kelola Supplier',
          style: AppTextStyles.h5.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddSupplierScreenSimple(),
                ),
              ).then((_) => _loadSupplierData());
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Section
          _buildSearchAndFilter(),

          // Supplier List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryGreen,
                    ),
                  )
                : _filteredSuppliers.isEmpty
                ? _buildEmptyState()
                : _buildSupplierList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddSupplierScreenSimple(),
            ),
          ).then((_) => _loadSupplierData());
        },
        backgroundColor: AppColors.primaryGreen,
        child: const Icon(Icons.add, color: AppColors.white),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.white,
      child: Column(
        children: [
          // Search Bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari supplier atau kontak person...',
              prefixIcon: const Icon(Icons.search, color: AppColors.grey),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: AppColors.grey),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.grey.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.grey.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.primaryGreen,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Filter Row
          Row(
            children: [
              Expanded(
                child: _buildFilterDropdown(
                  label: 'Status',
                  value: _selectedFilter,
                  options: _filterOptions,
                  onChanged: (value) {
                    setState(() {
                      _selectedFilter = value!;
                    });
                    _filterSuppliers();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFilterDropdown(
                  label: 'Kategori',
                  value: _selectedCategory,
                  options: _categoryOptions,
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value!;
                    });
                    _filterSuppliers();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.grey.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.grey.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: options.map((String option) {
        return DropdownMenuItem<String>(value: option, child: Text(option));
      }).toList(),
    );
  }

  Widget _buildSupplierList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredSuppliers.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final supplier = _filteredSuppliers[index];
        return _buildSupplierCard(supplier);
      },
    );
  }

  Widget _buildSupplierCard(Map<String, dynamic> supplier) {
    return Container(
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
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Business Icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getStatusColor(supplier['status']).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getCategoryIcon(supplier['category']),
                    color: _getStatusColor(supplier['status']),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),

                // Business Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        supplier['business_name'],
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        supplier['contact_person'],
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(supplier['status']).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    supplier['status'],
                    style: AppTextStyles.caption.copyWith(
                      color: _getStatusColor(supplier['status']),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                // Menu
                PopupMenuButton(
                  icon: const Icon(Icons.more_vert, color: AppColors.grey),
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _editSupplier(supplier);
                        break;
                      case 'delete':
                        _deleteSupplier(supplier);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Hapus', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Divider
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            color: AppColors.grey.withOpacity(0.2),
          ),

          // Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Contact Info
                Row(
                  children: [
                    Icon(Icons.phone, size: 16, color: AppColors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        supplier['phone'],
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Icon(Icons.location_on, size: 16, color: AppColors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: Text(
                        supplier['address'],
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Statistics
                Row(
                  children: [
                    _buildStatItem(
                      icon: Icons.local_gas_station,
                      label: 'Estimasi',
                      value: '${supplier['estimated_volume']}L/minggu',
                    ),
                    const SizedBox(width: 16),
                    _buildStatItem(
                      icon: Icons.analytics,
                      label: 'Total Terkumpul',
                      value: supplier['total_volume_collected'],
                    ),
                    const SizedBox(width: 16),
                    _buildStatItem(
                      icon: Icons.schedule,
                      label: 'Terakhir',
                      value: supplier['last_pickup'],
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

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 16, color: AppColors.primaryGreen),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off,
              size: 48,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Supplier Tidak Ditemukan',
            style: AppTextStyles.h6.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tidak ada supplier yang sesuai dengan\nkriteria pencarian Anda',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              _searchController.clear();
              setState(() {
                _selectedFilter = 'Semua';
                _selectedCategory = 'Semua';
              });
              _filterSuppliers();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.refresh),
            label: const Text('Reset Filter'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Aktif':
        return AppColors.primaryGreen;
      case 'Pending':
        return AppColors.accentOrange;
      case 'Tidak Aktif':
        return Colors.red;
      default:
        return AppColors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Restoran':
        return Icons.restaurant;
      case 'Hotel':
        return Icons.hotel;
      case 'Warung Makan':
        return Icons.store;
      case 'Fast Food':
        return Icons.fastfood;
      case 'Katering':
        return Icons.room_service;
      case 'Pabrik Makanan':
        return Icons.factory;
      default:
        return Icons.business;
    }
  }
}
