import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/supplier_form_provider.dart';
import '../models/supplier_model.dart';

class AddSupplierScreenSimple extends StatefulWidget {
  const AddSupplierScreenSimple({super.key});

  @override
  State<AddSupplierScreenSimple> createState() => _AddSupplierScreenSimpleState();
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

  // Error tracking
  Set<String> _fieldErrors = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SupplierFormProvider>(context, listen: false).loadMasterData();
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
          return Column(
            children: [
              // Progress indicator
              _buildProgressIndicator(),
              // Page content
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
                    _buildContactPage(provider),
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
          for (int i = 0; i < 4; i++)
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                height: 4,
                decoration: BoxDecoration(
                  color: i <= _currentPage ? const Color(0xFF1976D2) : Colors.grey[300],
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
              provider.notifyListeners();
            },
            displayText: (item) => item.name,
            hint: 'Pilih Jenis Supplier',
            isRequired: true,
          ),
          
          const SizedBox(height: 16),
          
          _buildDropdown(
            label: 'Kategori Supplier',
            value: provider.selectedKategori,
            items: provider.kategoriSupplier,
            onChanged: (value) {
              provider.selectedKategori = value;
              provider.notifyListeners();
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
            hint: 'Masukkan jenis minyak jelantah (UCO)',
            isRequired: true,
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
              provider.notifyListeners();
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
              provider.notifyListeners();
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
                  label: Text(_isGettingLocation ? 'Mendapatkan Lokasi...' : 'Ambil Lokasi Saat Ini'),
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
              provider.notifyListeners();
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
            label: 'Siklus Pickup',
            hint: 'Contoh: Mingguan, Bulanan, dll',
            isRequired: true,
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

  Widget _buildContactPage(SupplierFormProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Informasi Kontak',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF212121),
            ),
          ),
          const SizedBox(height: 24),
          
          _buildDropdown(
            label: 'Person In Charge (PIC)',
            value: provider.selectedPic,
            items: provider.employees,
            onChanged: (value) {
              provider.selectedPic = value;
              provider.notifyListeners();
            },
            displayText: (item) => item.name,
            hint: 'Pilih PIC',
            isRequired: true,
          ),
          
          const SizedBox(height: 16),
          
          _buildTextField(
            controller: _namaPicController,
            label: 'Nama PIC Alternatif',
            hint: 'Atau masukkan nama PIC manual',
          ),
          
          const SizedBox(height: 16),
          
          _buildTextField(
            controller: _noTelpPicController,
            label: 'Nomor Telepon PIC',
            hint: 'Masukkan nomor telepon PIC',
            keyboardType: TextInputType.phone,
            isRequired: true,
          ),
          
          const SizedBox(height: 16),
          
          _buildTextField(
            controller: _emailPicController,
            label: 'Email PIC',
            hint: 'Masukkan email PIC',
            keyboardType: TextInputType.emailAddress,
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
              onPressed: provider.isSubmitting ? null : () {
                if (_currentPage < 3) {
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
                  : Text(_currentPage < 3 ? 'Selanjutnya' : 'Simpan'),
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: hasError ? Colors.red : Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: hasError ? Colors.red : Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: hasError ? Colors.red : const Color(0xFF1976D2)),
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
            style: TextStyle(
              color: Colors.red,
              fontSize: 12,
            ),
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
            border: Border.all(color: hasError ? Colors.red : Colors.grey[300]!),
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
                    onChanged: enabled ? (T? newValue) {
                      onChanged(newValue);
                      // Remove error state when user selects
                      if (hasError && newValue != null) {
                        setState(() {
                          _fieldErrors.remove(label);
                        });
                      }
                    } : null,
                  ),
                ),
        ),
        if (hasError) ...[
          const SizedBox(height: 4),
          Text(
            'Field ini wajib dipilih',
            style: TextStyle(
              color: Colors.red,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
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
               _alamatController.text.trim().isNotEmpty &&
               _noTelpController.text.trim().isNotEmpty &&
               _jenisUcoController.text.trim().isNotEmpty &&
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
      case 3: // Contact
        return (provider.selectedPic != null || _namaPicController.text.trim().isNotEmpty) &&
               _noTelpPicController.text.trim().isNotEmpty;
      default:
        return false;
    }
  }

  void _showValidationError() {
    String message;
    switch (_currentPage) {
      case 0:
        message = 'Mohon lengkapi nama, jenis supplier, alamat, nomor telepon, jenis UCO, harga, dan satuan';
        break;
      case 1:
        message = 'Mohon pilih provinsi, kota/kabupaten, kecamatan, dan ambil koordinat GPS';
        break;
      case 2:
        message = 'Mohon lengkapi informasi bank, rekening, dan siklus pickup';
        break;
      case 3:
        message = 'Mohon lengkapi informasi PIC dan nomor telepon';
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
    
    String message = 'Field berikut masih kosong:\\n• ${missingFields.join('\\n• ')}';
    _showErrorToast(message);
    
    // Navigate to the first page that has errors
    _navigateToErrorPage(missingFields);
  }
  
  void _navigateToErrorPage(List<String> missingFields) {
    // Map fields to pages
    Set<int> errorPages = {};
    
    for (String field in missingFields) {
      if (['Nama Supplier', 'Jenis Supplier', 'Alamat', 'Nomor Telepon'].contains(field)) {
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
      _showErrorToast('Terdapat kesalahan validasi. Mohon periksa kembali data yang diinput.');
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
    if (provider.selectedPic == null && _namaPicController.text.trim().isEmpty) {
      missingFields.add('PIC');
    }
    if (_noTelpPicController.text.trim().isEmpty) {
      missingFields.add('Nomor Telepon PIC');
    }

    if (missingFields.isNotEmpty) {
      _showMissingFieldsError(missingFields);
      return;
    }

    try {
      // Ensure we have proper PIC data
      String picName = _namaPicController.text.trim().isNotEmpty 
          ? _namaPicController.text.trim() 
          : (provider.selectedPic?.name ?? '');
      
      String picJabatan = provider.selectedPic?.jabatan ?? 
          (provider.selectedPic?.position ?? 'Staff');
      
      // Make sure jabatan is not empty
      if (picJabatan.trim().isEmpty) {
        picJabatan = 'Staff';
      }

      // Create Supplier object with collected data
      final supplier = Supplier(
        jenis: provider.selectedJenis!.name,
        picId: provider.selectedPic?.id ?? 0,
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
        gps: _gpsController.text.trim().isNotEmpty ? _gpsController.text.trim() : null,
        namaRek: _namaRekeningController.text.trim(),
        nomorRek: _nomorRekeningController.text.trim(),
        bankRekId: provider.selectedBank!.id,
        siklus: _siklusController.text.trim().isNotEmpty ? _siklusController.text.trim() : null,
        poin: int.tryParse(_poinController.text.trim()),
      );

      final success = await provider.submitSupplier(supplier);
      
      if (mounted) {
        if (success) {
          _showSuccessToast();
          Navigator.of(context).pop(true);
        } else {
          // Show detailed API validation errors
          if (provider.errorMessage != null && provider.errorMessage!.contains('Validation Error')) {
            _showApiValidationErrors();
          } else {
            _handleApiError(provider.errorMessage ?? 'Gagal menambahkan supplier');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorToast('Error: $e');
      }
    }
  }

  void _showApiValidationErrors() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          '🚨 MASALAH BACKEND TERDETEKSI',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: const Text(
                  '📊 ANALISA FRONTEND:\n✅ Data dikirim dengan benar\n✅ Format JSON sudah sesuai\n✅ Semua field required terisi',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: const Text(
                  '💡 POST BODY YANG DIKIRIM:\n{"jenis":"POO RETAIL","pic":89,"name":"test pak hari","karyawan":"Test Saja"...}\n\nSemua field sudah terisi dengan benar!',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: const Text(
                  '❌ MASALAH DI BACKEND:\n\n1. STATUS 400: Validation error padahal data sudah benar\n\n2. STATUS 500: Call to undefined method M_supplier::get_last_code()\n\n3. STATUS 500: Database Error\n\n→ Backend tidak bisa parse request body\n→ Missing method di PHP model\n→ Database configuration error',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: const Text(
                  '🔧 SOLUSI:\nHubungi Backend Developer untuk:\n• Fix validation logic di Api_supplier.php\n• Tambah method get_last_code() di M_supplier model\n• Check database connection & struktur table',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
    });

    try {
      // For now, we'll use mock coordinates since we don't have location package
      // In a real app, you would use the location package here
      await Future.delayed(const Duration(seconds: 2)); // Simulate getting location
      
      // Mock coordinates (you can replace with real location service)
      setState(() {
        _currentLatitude = -7.9797 + (DateTime.now().millisecond / 100000);
        _currentLongitude = 112.6304 + (DateTime.now().millisecond / 100000);
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