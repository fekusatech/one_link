import 'dart:async';

import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../services/supplier_list_service.dart';
import '../models/supplier_list_model.dart';
import '../models/supplier_model.dart';
import '../models/dropdown_models.dart';
import '../services/user_storage.dart';
import '../services/api/supplier_api_service.dart';
import 'supplier_detail_sheet.dart';
import 'quick_add_supplier_sheet.dart';

class SupplierListScreen extends StatefulWidget {
  const SupplierListScreen({super.key});

  @override
  State<SupplierListScreen> createState() => _SupplierListScreenState();
}

class _SupplierListScreenState extends State<SupplierListScreen> {
  final _searchController = TextEditingController();
  final _listScrollController = ScrollController();
  Timer? _searchDebounce;
  String _selectedFilter = 'Semua';
  String _selectedCategory = 'Semua';
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasNext = false;
  int? _nextCursor;

  // Real supplier data
  List<SupplierListItem> _suppliers = [];
  List<SupplierListItem> _filteredSuppliers = [];

  int? _currentUserId;

  Future<void> _addSupplier() async {
    final created = await showQuickAddSupplierSheet(context);
    if (created == true && mounted) {
      await _loadSupplierData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Supplier berhasil ditambahkan')),
        );
      }
    }
  }

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
    _searchDebounce?.cancel();
    _listScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSupplierData({bool loadMore = false}) async {
    if (loadMore && (_isLoading || _isLoadingMore || !_hasNext)) return;
    if (loadMore) {
      setState(() => _isLoadingMore = true);
    } else {
      setState(() {
        _isLoading = true;
        _nextCursor = null;
        _hasNext = false;
      });
    }

    try {
      // Get current user ID
      _currentUserId = await UserStorage.getUserId();

      // No `date` filter here — the API filters by exact-date match, and
      // this screen has no date-picker UI, so passing one only ever hid
      // every supplier not created on that exact day.
      final response = await SupplierListService.getSupplierList(
        page: 1,
        limit: 100,
        cursor: loadMore ? _nextCursor : null,
        search: _searchController.text.trim(),
        picId: _currentUserId,
      );

      if (response.status && response.data != null) {
        final page = response.data!;
        setState(() {
          if (loadMore) {
            final seen = _suppliers.map((item) => item.id).toSet();
            _suppliers.addAll(page.data.where((item) => seen.add(item.id)));
          } else {
            _suppliers = page.data;
          }
          _filteredSuppliers = List.of(_suppliers);
          _nextCursor = page.nextCursor;
          _hasNext = page.hasNext && page.nextCursor != null;
          _isLoading = false;
          _isLoadingMore = false;
        });
      } else {
        setState(() {
          if (!loadMore) {
            _suppliers = [];
            _filteredSuppliers = [];
          }
          _isLoading = false;
          _isLoadingMore = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        if (!loadMore) {
          _suppliers = [];
          _filteredSuppliers = [];
        }
        _isLoading = false;
        _isLoadingMore = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _filterSuppliers() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _loadSupplierData(),
    );
  }

  Future<void> _editSupplier(SupplierListItem supplier) async {
    final id = int.tryParse(supplier.id);
    if (id == null) return;

    final detailResponse = await SupplierApiService.getSupplierDetail(id);
    if (!mounted) return;
    final detail = detailResponse.data;
    if (!detailResponse.status || detail == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(detailResponse.message)));
      return;
    }

    final name = TextEditingController(text: detail.name);
    final contact = TextEditingController(text: detail.karyawan);
    final position = TextEditingController(text: detail.jabatan);
    final phone = TextEditingController(text: detail.phone);
    final address = TextEditingController(text: detail.alamat ?? '');
    final accountName = TextEditingController(text: detail.namaRek);
    final accountNumber = TextEditingController(text: detail.nomorRek);
    final dropdownResponse = await SupplierApiService.getDropdownOptions();
    if (!mounted) {
      name.dispose();
      contact.dispose();
      position.dispose();
      phone.dispose();
      address.dispose();
      accountName.dispose();
      accountNumber.dispose();
      return;
    }
    final banks = (dropdownResponse.data?['banks'] as List? ?? const [])
        .whereType<Map>()
        .map((row) => Bank.fromJson(Map<String, dynamic>.from(row)))
        .toList();
    var selectedBankId = detail.bankRekId;
    var isIsccCertified = detail.isIsccCertified;
    String? error;
    String? accountValidation;
    String? successMessage;
    var saving = false;
    var validatingAccount = false;

    final updated = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Edit Supplier'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Nama supplier'),
                ),
                TextField(
                  controller: contact,
                  decoration: const InputDecoration(labelText: 'Nama PIC'),
                ),
                TextField(
                  controller: position,
                  decoration: const InputDecoration(labelText: 'Jabatan PIC'),
                ),
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Nomor telepon'),
                ),
                TextField(
                  controller: address,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Alamat'),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('ISCC Certified'),
                  subtitle: Text(isIsccCertified ? 'Ya' : 'Tidak'),
                  value: isIsccCertified,
                  onChanged: saving
                      ? null
                      : (value) => setDialogState(() {
                          isIsccCertified = value;
                        }),
                ),
                TextField(
                  controller: accountName,
                  decoration: const InputDecoration(
                    labelText: 'Nama rekening *',
                  ),
                ),
                TextField(
                  controller: accountNumber,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Nomor rekening *',
                  ),
                ),
                DropdownButtonFormField<int>(
                  initialValue: banks.any((bank) => bank.id == selectedBankId)
                      ? selectedBankId
                      : null,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Bank *'),
                  hint: const Text('Pilih bank'),
                  items: banks
                      .map(
                        (bank) => DropdownMenuItem<int>(
                          value: bank.id,
                          child: Text('${bank.namaBank} (${bank.kodeBank})'),
                        ),
                      )
                      .toList(),
                  onChanged: saving
                      ? null
                      : (value) => setDialogState(() {
                          selectedBankId = value;
                          accountValidation = null;
                        }),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: saving || validatingAccount
                        ? null
                        : () async {
                            Bank? bank;
                            for (final option in banks) {
                              if (option.id == selectedBankId) bank = option;
                            }
                            if (accountNumber.text.trim().isEmpty ||
                                bank == null) {
                              setDialogState(
                                () => accountValidation =
                                    'Isi nomor rekening dan pilih bank terlebih dahulu.',
                              );
                              return;
                            }
                            setDialogState(() {
                              validatingAccount = true;
                              accountValidation = null;
                            });
                            final result =
                                await SupplierApiService.validateAccount(
                                  nomorRek: accountNumber.text.trim(),
                                  bank: bank.kodeBank,
                                  namaRek: accountName.text.trim(),
                                );
                            if (!dialogContext.mounted) return;
                            final verifiedName = result.data?['account_name']
                                ?.toString();
                            setDialogState(() {
                              validatingAccount = false;
                              accountValidation = result.status
                                  ? '✓ ${verifiedName?.isNotEmpty == true ? verifiedName : 'Rekening valid'}'
                                  : '✗ ${result.message}';
                            });
                          },
                    icon: validatingAccount
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.verified_outlined),
                    label: const Text('Validasi rekening'),
                  ),
                ),
                if (accountValidation != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        accountValidation!,
                        style: TextStyle(
                          color: accountValidation!.startsWith('✓')
                              ? AppColors.primaryGreen
                              : AppColors.error,
                        ),
                      ),
                    ),
                  ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!, style: const TextStyle(color: AppColors.error)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving
                  ? null
                  : () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (name.text.trim().isEmpty ||
                          contact.text.trim().isEmpty ||
                          position.text.trim().isEmpty ||
                          accountName.text.trim().isEmpty ||
                          accountNumber.text.trim().isEmpty ||
                          selectedBankId == null) {
                        setDialogState(
                          () => error =
                              'Lengkapi data supplier, PIC, rekening, dan bank.',
                        );
                        return;
                      }
                      setDialogState(() {
                        saving = true;
                        error = null;
                      });
                      final input = Supplier.fromJson({
                        ...detail.toJson(),
                        'name': name.text.trim(),
                        'karyawan': contact.text.trim(),
                        'jabatan': position.text.trim(),
                        'phone': phone.text.trim(),
                        'alamat': address.text.trim(),
                        'nama_rek': accountName.text.trim(),
                        'nomor_rek': accountNumber.text.trim(),
                        'bank_rek_id': selectedBankId ?? detail.bankRekId,
                        'is_iscc_certified': isIsccCertified ? 1 : 0,
                      });
                      final response = await SupplierApiService.updateSupplier(
                        id,
                        input,
                      );
                      if (!dialogContext.mounted) return;
                      if (response.status) {
                        successMessage = response.message;
                        Navigator.pop(dialogContext, true);
                      } else {
                        setDialogState(() {
                          saving = false;
                          error = response.message;
                        });
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    contact.dispose();
    position.dispose();
    phone.dispose();
    address.dispose();
    accountName.dispose();
    accountNumber.dispose();

    if (updated == true && mounted) {
      await _loadSupplierData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            successMessage?.isNotEmpty == true
                ? successMessage!
                : 'Perubahan POO berhasil dikirim.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.primaryGreen,
        title: Text(
          'Supplier',
          style: AppTextStyles.h5.copyWith(
            color: AppColors.primaryGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
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
        onPressed: _addSupplier,
        backgroundColor: AppColors.primaryGreen,
        tooltip: 'Tambah supplier',
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
      isExpanded: true,
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
        return DropdownMenuItem<String>(
          value: option,
          child: Text(option, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
    );
  }

  Widget _buildSupplierList() {
    return ListView.separated(
      controller: _listScrollController,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      itemCount:
          _filteredSuppliers.length + (_hasNext || _isLoadingMore ? 1 : 0),
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == _filteredSuppliers.length) {
          if (_hasNext && !_isLoadingMore) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _loadSupplierData(loadMore: true);
            });
          }
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            ),
          );
        }
        final supplier = _filteredSuppliers[index];
        return _buildSupplierCard(supplier);
      },
    );
  }

  Widget _buildSupplierCard(SupplierListItem supplier) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => showSupplierDetailSheet(context, supplier),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderColor),
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
                        color: AppColors.primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.store,
                        color: AppColors.primaryGreen,
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
                            supplier.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyLarge.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            supplier.jenisName ?? 'Supplier',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: supplier.isIsccCertified
                                  ? AppColors.success.withOpacity(0.1)
                                  : AppColors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'ISCC ${supplier.isIsccCertified ? 'Ya' : 'Tidak'}',
                              style: AppTextStyles.caption.copyWith(
                                color: supplier.isIsccCertified
                                    ? AppColors.success
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Status Badge (default to Aktif for real data)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Aktif',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primaryGreen,
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
                    if (supplier.alamat?.isNotEmpty == true) ...[
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 16,
                            color: AppColors.grey,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              supplier.alamat!,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Basic Info
                    Row(
                      children: [
                        _buildStatItem(
                          icon: Icons.tag,
                          label: 'Kode',
                          value: supplier.kode ?? '-',
                        ),
                        const SizedBox(width: 16),
                        _buildStatItem(
                          icon: Icons.category,
                          label: 'Kategori',
                          value: supplier.kategoriName ?? '-',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
}
