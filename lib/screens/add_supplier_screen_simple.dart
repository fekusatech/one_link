import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/supplier_form_provider.dart';
import '../models/dropdown_models.dart';
import '../models/supplier_model.dart';
import '../services/api/supplier_api_service.dart';
import '../services/geu/gps_service.dart';

class AddSupplierScreenSimple extends StatefulWidget {
  const AddSupplierScreenSimple({super.key});

  @override
  State<AddSupplierScreenSimple> createState() =>
      _AddSupplierScreenSimpleState();
}

class _AddSupplierScreenSimpleState extends State<AddSupplierScreenSimple> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Form controllers
  final _namaController = TextEditingController();
  final _alamatController = TextEditingController();
  final _noTelpController = TextEditingController();
  final _nomorRekeningController = TextEditingController();
  final _namaRekeningController = TextEditingController();
  final _namaPicController = TextEditingController();
  final _karyawanController = TextEditingController();
  final _jabatanController = TextEditingController();
  final _noTelpPicController = TextEditingController();
  final _emailPicController = TextEditingController();
  final _jenisUcoController = TextEditingController();
  final _priceController = TextEditingController();
  final _siklusController = TextEditingController();
  final _poinController = TextEditingController();
  final _gpsController = TextEditingController();

  // GPS state
  double? _currentLatitude;
  double? _currentLongitude;
  bool _isGettingLocation = false;
  bool _isIsccCertified = false;

  // Error tracking
  Set<String> _fieldErrors = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SupplierFormProvider>(
        context,
        listen: false,
      ).loadMasterData();
    });
  }

  @override
  void dispose() {
    _namaController.dispose();
    _alamatController.dispose();
    _noTelpController.dispose();
    _nomorRekeningController.dispose();
    _namaRekeningController.dispose();
    _namaPicController.dispose();
    _karyawanController.dispose();
    _jabatanController.dispose();
    _noTelpPicController.dispose();
    _emailPicController.dispose();
    _jenisUcoController.dispose();
    _priceController.dispose();
    _siklusController.dispose();
    _poinController.dispose();
    _gpsController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Supplier'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
      ),
      body: Consumer<SupplierFormProvider>(
        builder: (context, provider, child) {
          if (provider.masterDataFailed) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_off, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      provider.errorMessage ?? 'Gagal memuat data.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => provider.loadMasterData(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            );
          }
          return Column(
            children: [
              _buildProgressIndicator(),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (page) {
                    setState(() {
                      _currentPage = page;
                    });
                  },
                  children: [
                    _buildBasicInfoPage(provider),
                    _buildLocationPage(provider),
                    _buildFinancialPage(provider),
                  ],
                ),
              ),
              // Navigation buttons
              _buildNavigationButtons(provider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          for (int i = 0; i < 3; i++)
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                height: 4,
                decoration: BoxDecoration(
                  color: i <= _currentPage
                      ? const Color(0xFF1976D2)
                      : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoPage(SupplierFormProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Informasi Dasar',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF212121),
            ),
          ),
          const SizedBox(height: 24),

          _buildTextField(
            controller: _namaController,
            label: 'Nama Supplier',
            hint: 'Masukkan nama supplier',
            isRequired: true,
          ),

          const SizedBox(height: 16),

          _buildDropdown(
            label: 'Jenis Supplier',
            value: provider.selectedJenis,
            items: provider.jenisSupplier,
            onChanged: (value) {
              provider.selectedJenis = value;
              provider.refreshSelection();
            },
            displayText: (item) => item.name,
            hint: 'Pilih Jenis Supplier',
            isRequired: true,
          ),

          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('ISCC Certified'),
            subtitle: Text(_isIsccCertified ? 'Ya' : 'Tidak'),
            value: _isIsccCertified,
            onChanged: (value) => setState(() => _isIsccCertified = value),
          ),

          const SizedBox(height: 16),

          _buildPicPicker(provider),

          const SizedBox(height: 16),

          _buildTextField(
            controller: _karyawanController,
            label: 'Nama kontak',
            hint: 'Nama penanggung jawab supplier',
            isRequired: true,
          ),

          const SizedBox(height: 16),

          _buildTextField(
            controller: _jabatanController,
            label: 'Jabatan kontak',
            hint: 'Contoh: Owner atau Manager',
            isRequired: true,
          ),

          const SizedBox(height: 16),

          _buildDropdown(
            label: 'Kategori Supplier',
            value: provider.selectedKategori,
            items: provider.kategoriSupplier,
            onChanged: (value) {
              provider.selectedKategori = value;
              provider.refreshSelection();
            },
            displayText: (item) => item.name,
            hint: 'Pilih Kategori Supplier',
          ),

          const SizedBox(height: 16),

          _buildTextField(
            controller: _alamatController,
            label: 'Alamat Lengkap',
            hint: 'Masukkan alamat lengkap',
            maxLines: 3,
            isRequired: true,
          ),

          const SizedBox(height: 16),

          _buildTextField(
            controller: _noTelpController,
            label: 'Nomor Telepon',
            hint: 'Masukkan nomor telepon',
            keyboardType: TextInputType.phone,
            isRequired: true,
          ),

          const SizedBox(height: 16),

          _buildTextField(
            controller: _jenisUcoController,
            label: 'Jenis UCO',
            hint: 'Cair, beku, atau padat',
          ),

          const SizedBox(height: 16),

          _buildTextField(
            controller: _priceController,
            label: 'Harga per Satuan',
            hint: 'Masukkan harga per satuan',
            keyboardType: TextInputType.number,
            isRequired: true,
          ),

          const SizedBox(height: 16),

          _buildDropdown(
            label: 'Satuan Harga',
            value: provider.selectedSatuan,
            items: provider.satuan,
            onChanged: (value) {
              provider.selectedSatuan = value;
              provider.refreshSelection();
            },
            displayText: (item) => item.name,
            hint: 'Pilih Satuan',
            isRequired: true,
          ),
        ],
      ),
    );
  }

  Widget _buildLocationPage(SupplierFormProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lokasi',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF212121),
            ),
          ),
          const SizedBox(height: 24),

          _buildDropdown(
            label: 'Provinsi',
            value: provider.selectedProvince,
            items: provider.provinces,
            onChanged: (value) => provider.onProvinceChanged(value),
            displayText: (item) => item.name,
            hint: 'Pilih Provinsi',
            isRequired: true,
            isLoading: provider.isLoadingMaster,
          ),

          const SizedBox(height: 16),

          _buildDropdown(
            label: 'Kabupaten/Kota',
            value: provider.selectedCity,
            items: provider.cities,
            onChanged: (value) => provider.onCityChanged(value),
            displayText: (item) => item.name,
            hint: 'Pilih Kabupaten/Kota',
            isRequired: true,
            isLoading: provider.isLoadingCities,
            enabled: provider.selectedProvince != null,
          ),

          const SizedBox(height: 16),

          _buildDropdown(
            label: 'Kecamatan',
            value: provider.selectedDistrict,
            items: provider.districts,
            onChanged: (value) => provider.onDistrictChanged(value),
            displayText: (item) => item.name,
            hint: 'Pilih Kecamatan',
            isRequired: true,
            isLoading: provider.isLoadingDistricts,
            enabled: provider.selectedCity != null,
          ),

          const SizedBox(height: 16),

          _buildDropdown(
            label: 'Desa/Kelurahan',
            value: provider.selectedVillage,
            items: provider.villages,
            onChanged: (value) {
              provider.selectedVillage = value;
              provider.refreshSelection();
            },
            displayText: (item) => item.name,
            hint: 'Pilih Desa/Kelurahan',
            isLoading: provider.isLoadingVillages,
            enabled: provider.selectedDistrict != null,
          ),

          const SizedBox(height: 24),

          const Text(
            'Koordinat GPS',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Color(0xFF424242),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                if (_currentLatitude != null && _currentLongitude != null) ...[
                  Text(
                    'Lat: $_currentLatitude',
                    style: const TextStyle(fontSize: 14),
                  ),
                  Text(
                    'Lng: $_currentLongitude',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                ],
                ElevatedButton.icon(
                  onPressed: _isGettingLocation ? null : _getCurrentLocation,
                  icon: _isGettingLocation
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                  label: Text(
                    _isGettingLocation
                        ? 'Mendapatkan Lokasi...'
                        : 'Ambil Lokasi Saat Ini',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialPage(SupplierFormProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Informasi Keuangan',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF212121),
            ),
          ),
          const SizedBox(height: 24),

          _buildDropdown(
            label: 'Bank',
            value: provider.selectedBank,
            items: provider.banks,
            onChanged: (value) {
              provider.selectedBank = value;
              provider.refreshSelection();
            },
            displayText: (item) => item.namaBank,
            hint: 'Pilih Bank',
            isRequired: true,
          ),

          const SizedBox(height: 16),

          _buildTextField(
            controller: _nomorRekeningController,
            label: 'Nomor Rekening',
            hint: 'Masukkan nomor rekening',
            keyboardType: TextInputType.number,
            isRequired: true,
          ),

          const SizedBox(height: 16),

          _buildTextField(
            controller: _namaRekeningController,
            label: 'Nama Pemilik Rekening',
            hint: 'Masukkan nama pemilik rekening',
            isRequired: true,
          ),

          const SizedBox(height: 16),

          _buildTextField(
            controller: _siklusController,
            label: 'Siklus pickup',
            hint: 'Contoh: 1 Minggu atau 2 Minggu',
          ),

          const SizedBox(height: 16),

          _buildTextField(
            controller: _poinController,
            label: 'Poin/Score',
            hint: 'Masukkan poin atau score supplier',
            keyboardType: TextInputType.number,
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons(SupplierFormProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (_currentPage > 0)
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[300],
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Sebelumnya'),
              ),
            ),
          if (_currentPage > 0) const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: provider.isSubmitting
                  ? null
                  : () {
                      if (_currentPage < 2) {
                        _handleNextButton();
                      } else {
                        _submitForm(provider);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: provider.isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(_currentPage < 2 ? 'Selanjutnya' : 'Simpan'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    bool isRequired = false,
    bool enabled = true,
    bool readOnly = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
  }) {
    final hasError = _fieldErrors.contains(label);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label + (isRequired ? ' *' : ''),
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: hasError ? Colors.red : const Color(0xFF424242),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          enabled: enabled,
          readOnly: readOnly,
          keyboardType: keyboardType,
          onChanged: (value) {
            // Remove error state when user starts typing
            if (hasError && value.trim().isNotEmpty) {
              setState(() {
                _fieldErrors.remove(label);
              });
            }
          },
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: suffixIcon,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: hasError ? Colors.red : Colors.grey[300]!,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: hasError ? Colors.red : Colors.grey[300]!,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: hasError ? Colors.red : const Color(0xFF1976D2),
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.red),
            ),
            fillColor: hasError ? Colors.red.withOpacity(0.05) : null,
            filled: hasError,
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 4),
          Text(
            'Field ini wajib diisi',
            style: TextStyle(color: Colors.red, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required void Function(T?) onChanged,
    required String Function(T) displayText,
    String? hint,
    bool isRequired = false,
    bool enabled = true,
    bool isLoading = false,
  }) {
    final hasError = _fieldErrors.contains(label);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label + (isRequired ? ' *' : ''),
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: hasError ? Colors.red : const Color(0xFF424242),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(
              color: hasError ? Colors.red : Colors.grey[300]!,
            ),
            borderRadius: BorderRadius.circular(8),
            color: enabled
                ? (hasError ? Colors.red.withOpacity(0.05) : Colors.white)
                : Colors.grey[100],
          ),
          child: isLoading
              ? const SizedBox(
                  height: 48,
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : DropdownButtonHideUnderline(
                  child: DropdownButton<T>(
                    value: value,
                    isExpanded: true,
                    hint: Text(
                      hint ?? 'Pilih $label',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    items: items.map((T item) {
                      return DropdownMenuItem<T>(
                        value: item,
                        child: Text(
                          displayText(item),
                          style: const TextStyle(fontSize: 14),
                        ),
                      );
                    }).toList(),
                    onChanged: enabled
                        ? (T? newValue) {
                            onChanged(newValue);
                            // Remove error state when user selects
                            if (hasError && newValue != null) {
                              setState(() {
                                _fieldErrors.remove(label);
                              });
                            }
                          }
                        : null,
                  ),
                ),
        ),
        if (hasError) ...[
          const SizedBox(height: 4),
          Text(
            'Field ini wajib dipilih',
            style: TextStyle(color: Colors.red, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _buildPicPicker(SupplierFormProvider provider) {
    final hasError = _fieldErrors.contains('PIC RO');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PIC RO',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: hasError ? Colors.red : const Color(0xFF424242),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _showPicPickerSheet(provider),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(
                color: hasError ? Colors.red : Colors.grey[300]!,
              ),
              borderRadius: BorderRadius.circular(8),
              color: hasError ? Colors.red.withOpacity(0.05) : Colors.white,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    provider.selectedPic?.name ?? 'Pilih PIC RO',
                    style: TextStyle(
                      fontSize: 14,
                      color: provider.selectedPic != null
                          ? const Color(0xFF212121)
                          : Colors.grey[600],
                    ),
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
              ],
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 4),
          const Text(
            'Field ini wajib dipilih',
            style: TextStyle(color: Colors.red, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Future<void> _showPicPickerSheet(SupplierFormProvider provider) async {
    final result = await showModalBottomSheet<Employee>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _PicPickerSheet(initialSelection: provider.selectedPic),
    );

    if (result != null && mounted) {
      provider.selectedPic = result;
      _karyawanController.text = result.name;
      _jabatanController.text = result.jabatan ?? result.position ?? '';
      provider.refreshSelection();
    }
  }

  void _handleNextButton() {
    // Clear previous errors for current page
    setState(() {
      _fieldErrors.clear();
    });

    if (_validateCurrentPage()) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _showValidationError();
    }
  }

  bool _validateCurrentPage() {
    final provider = Provider.of<SupplierFormProvider>(context, listen: false);

    switch (_currentPage) {
      case 0: // Basic info
        return _namaController.text.trim().isNotEmpty &&
            provider.selectedJenis != null &&
            _karyawanController.text.trim().isNotEmpty &&
            _jabatanController.text.trim().isNotEmpty &&
            _alamatController.text.trim().isNotEmpty &&
            _noTelpController.text.trim().isNotEmpty &&
            _priceController.text.trim().isNotEmpty &&
            provider.selectedSatuan != null;
      case 1: // Location
        return provider.selectedProvince != null &&
            provider.selectedCity != null &&
            provider.selectedDistrict != null &&
            (_currentLatitude != null && _currentLongitude != null);
      case 2: // Financial
        return provider.selectedBank != null &&
            _nomorRekeningController.text.trim().isNotEmpty &&
            _namaRekeningController.text.trim().isNotEmpty &&
            _siklusController.text.trim().isNotEmpty;
      case 3:
        return true;
      default:
        return false;
    }
  }

  void _showValidationError() {
    String message;
    switch (_currentPage) {
      case 0:
        message = 'Mohon lengkapi profil supplier, kontak, harga, dan satuan';
        break;
      case 1:
        message =
            'Mohon pilih provinsi, kota/kabupaten, kecamatan, dan ambil koordinat GPS';
        break;
      case 2:
        message = 'Mohon lengkapi informasi bank, rekening, dan siklus pickup';
        break;
      case 3:
        message = 'Periksa kembali data supplier sebelum menyimpan';
        break;
      default:
        message = 'Mohon lengkapi semua field yang diperlukan';
    }

    _showErrorToast(message);
  }

  void _showMissingFieldsError(List<String> missingFields) {
    setState(() {
      _fieldErrors.addAll(missingFields);
    });

    String message =
        'Field berikut masih kosong:\\n• ${missingFields.join('\\n• ')}';
    _showErrorToast(message);

    // Navigate to the first page that has errors
    _navigateToErrorPage(missingFields);
  }

  void _navigateToErrorPage(List<String> missingFields) {
    // Map fields to pages
    Set<int> errorPages = {};

    for (String field in missingFields) {
      if ([
        'Nama Supplier',
        'Jenis Supplier',
        'Alamat',
        'Nomor Telepon',
      ].contains(field)) {
        errorPages.add(0);
      } else if (['Provinsi', 'Kota/Kabupaten', 'Kecamatan'].contains(field)) {
        errorPages.add(1);
      } else if (['Bank', 'Nomor Rekening', 'Nama Rekening'].contains(field)) {
        errorPages.add(2);
      } else if (['PIC', 'Nomor Telepon PIC'].contains(field)) {
        errorPages.add(3);
      }
    }

    // Navigate to first error page
    if (errorPages.isNotEmpty) {
      int firstErrorPage = errorPages.first;
      _pageController.animateToPage(
        firstErrorPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _handleApiError(String errorMessage) {
    // Try to parse API validation errors
    if (errorMessage.contains('Validation Error')) {
      _showErrorToast(
        'Terdapat kesalahan validasi. Mohon periksa kembali data yang diinput.',
      );
    } else {
      _showErrorToast(errorMessage);
    }
  }

  void _showErrorToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  void _showSuccessToast() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text('Supplier berhasil ditambahkan'),
          ],
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  Future<void> _submitForm(SupplierFormProvider provider) async {
    if (!_validateCurrentPage()) {
      _showValidationError();
      return;
    }

    // Validate all required fields before submission
    List<String> missingFields = [];

    if (_namaController.text.trim().isEmpty) {
      missingFields.add('Nama Supplier');
    }
    if (provider.selectedJenis == null) {
      missingFields.add('Jenis Supplier');
    }
    if (_alamatController.text.trim().isEmpty) {
      missingFields.add('Alamat');
    }
    if (_noTelpController.text.trim().isEmpty) {
      missingFields.add('Nomor Telepon');
    }
    if (provider.selectedProvince == null) {
      missingFields.add('Provinsi');
    }
    if (provider.selectedCity == null) {
      missingFields.add('Kota/Kabupaten');
    }
    if (provider.selectedDistrict == null) {
      missingFields.add('Kecamatan');
    }
    if (provider.selectedBank == null) {
      missingFields.add('Bank');
    }
    if (_nomorRekeningController.text.trim().isEmpty) {
      missingFields.add('Nomor Rekening');
    }
    if (_namaRekeningController.text.trim().isEmpty) {
      missingFields.add('Nama Rekening');
    }
    if (_karyawanController.text.trim().isEmpty)
      missingFields.add('Nama Kontak');
    if (_jabatanController.text.trim().isEmpty)
      missingFields.add('Jabatan Kontak');

    if (missingFields.isNotEmpty) {
      _showMissingFieldsError(missingFields);
      return;
    }

    try {
      // Ensure we have proper PIC data
      String picName = _karyawanController.text.trim();

      String picJabatan = _jabatanController.text.trim();

      // Make sure jabatan is not empty
      if (picJabatan.trim().isEmpty) {
        picJabatan = 'Staff';
      }

      // Create Supplier object with collected data
      final supplier = Supplier(
        jenis: provider.selectedJenis!.name,
        // PIC RO tidak wajib diisi. Kirim null (nanti dibuang toJson) alih-alih
        // 0 — id 0 tidak menunjuk ke karyawan mana pun, jadi supplier akan
        // tersimpan dengan foreign key yang menggantung.
        picId: provider.selectedPic?.id,
        name: _namaController.text.trim(),
        karyawan: picName,
        phone: _noTelpController.text.trim(),
        jabatan: picJabatan,
        kategoriId: provider.selectedKategori?.id,
        jenisUco: _jenisUcoController.text.trim(),
        price: double.tryParse(_priceController.text.trim()),
        priceSatuanId: provider.selectedSatuan?.id,
        provinsiId: provider.selectedProvince!.id,
        kotaId: provider.selectedCity!.id,
        kecamatanId: provider.selectedDistrict!.id,
        desaId: provider.selectedVillage?.id,
        alamat: _alamatController.text.trim(),
        gps: _gpsController.text.trim().isNotEmpty
            ? _gpsController.text.trim()
            : null,
        namaRek: _namaRekeningController.text.trim(),
        nomorRek: _nomorRekeningController.text.trim(),
        bankRekId: provider.selectedBank!.id,
        siklus: _siklusController.text.trim().isNotEmpty
            ? _siklusController.text.trim()
            : null,
        poin: int.tryParse(_poinController.text.trim()),
        isIsccCertified: _isIsccCertified,
      );

      final success = await provider.submitSupplier(supplier);

      if (mounted) {
        if (success) {
          _showSuccessToast();
          Navigator.of(context).pop(true);
        } else {
          _handleApiError(
            provider.errorMessage ?? 'Gagal menambahkan supplier',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorToast('Error: $e');
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
    });

    try {
      final fix = await GpsService.getCurrentFix();
      setState(() {
        _currentLatitude = fix.latitude;
        _currentLongitude = fix.longitude;
        _gpsController.text = '$_currentLatitude,$_currentLongitude';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lokasi berhasil didapat'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error mendapatkan lokasi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isGettingLocation = false;
      });
    }
  }
}

/// Pencarian PIC dengan scroll tak terbatas + debounce. Sengaja StatefulWidget
/// sendiri (bukan closure + StatefulBuilder di dalam showModalBottomSheet)
/// karena versi closure sebelumnya membuat Timer debounce dan network call
/// yang masih tertunda saat sheet ditutup memanggil setSheetState()/mengakses
/// TextEditingController & ScrollController SETELAH keduanya di-dispose() —
/// muncul persis sebagai "A TextEditingController/ScrollController was used
/// after being disposed" di log. StatefulWidget punya dispose() resmi yang
/// dipanggil framework saat widget benar-benar unmount, jadi guard `mounted`
/// di setiap callback async menutup celah race tersebut.
class _PicPickerSheet extends StatefulWidget {
  final Employee? initialSelection;
  const _PicPickerSheet({this.initialSelection});

  @override
  State<_PicPickerSheet> createState() => _PicPickerSheetState();
}

class _PicPickerSheetState extends State<_PicPickerSheet> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  List<Employee> _employees = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _error = false;
  String _errorMsg = '';
  int _currentPage = 1;
  Employee? _selection;

  @override
  void initState() {
    super.initState();
    _selection = widget.initialSelection;
    _scrollController.addListener(_onScroll);
    _loadPage();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loading || _loadingMore) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100) {
      setState(() => _loadingMore = true);
      _loadPage();
    }
  }

  Future<void> _loadPage({bool reset = false}) async {
    if (reset) {
      _currentPage = 1;
      _employees = [];
      _hasMore = true;
      _error = false;
      _loading = true;
    }
    if (mounted) setState(() {});

    try {
      final res = await SupplierApiService.getEmployees(
        search: _searchController.text.trim(),
        page: _currentPage,
        limit: 20,
      );
      if (!mounted) return;

      if (res.status && res.data != null) {
        final data = res.data!;
        final list = (data['data'] as List? ?? [])
            .map((e) => Employee.fromJson(e as Map<String, dynamic>))
            .toList();
        final pagination = data['pagination'] as Map<String, dynamic>?;
        setState(() {
          _employees.addAll(list);
          _hasMore = pagination?['has_next'] as bool? ?? false;
          _currentPage++;
        });
      } else {
        setState(() {
          _error = true;
          _errorMsg = res.message.isNotEmpty
              ? res.message
              : 'Gagal memuat data';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = true;
          _errorMsg = 'Gagal memuat data. Coba lagi.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = _loadingMore = false);
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _loadPage(reset: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (context, _) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  const Text(
                    'Pilih PIC',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Cari nama karyawan...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                onChanged: _onSearchChanged,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _error
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_errorMsg),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () => _loadPage(reset: true),
                            child: const Text('Coba Lagi'),
                          ),
                        ],
                      ),
                    )
                  : _employees.isEmpty && !_loading
                  ? const Center(child: Text('Karyawan tidak ditemukan.'))
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: _employees.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (i >= _employees.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          );
                        }
                        final emp = _employees[i];
                        final selected = _selection?.id == emp.id;
                        return ListTile(
                          leading: Icon(
                            selected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            color: selected
                                ? const Color(0xFF1976D2)
                                : Colors.grey,
                          ),
                          title: Text(emp.name),
                          onTap: () => Navigator.pop(context, emp),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
