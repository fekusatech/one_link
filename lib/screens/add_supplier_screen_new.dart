import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../providers/supplier_form_provider.dart';
import '../models/supplier_model.dart';
import '../widgets/custom_dropdown.dart';

class AddSupplierScreen extends StatefulWidget {
  const AddSupplierScreen({super.key});

  @override
  State<AddSupplierScreen> createState() => _AddSupplierScreenState();
}

class _AddSupplierScreenState extends State<AddSupplierScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form Controllers
  final _kodeController = TextEditingController();
  final _nameController = TextEditingController();
  final _karyawanController = TextEditingController();
  final _phoneController = TextEditingController();
  final _jabatanController = TextEditingController();
  final _priceController = TextEditingController();
  final _alamatController = TextEditingController();
  final _gpsController = TextEditingController();
  final _namaRekController = TextEditingController();
  final _nomorRekController = TextEditingController();
  final _poinController = TextEditingController();

  // Location data
  Position? _currentPosition;
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  bool _isGettingLocation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SupplierFormProvider>().loadMasterData();
    });
  }

  @override
  void dispose() {
    _kodeController.dispose();
    _nameController.dispose();
    _karyawanController.dispose();
    _phoneController.dispose();
    _jabatanController.dispose();
    _priceController.dispose();
    _alamatController.dispose();
    _gpsController.dispose();
    _namaRekController.dispose();
    _nomorRekController.dispose();
    _poinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundGrey,
      appBar: AppBar(
        title: Text(
          'Tambah Data POO',
          style: AppTextStyles.h5.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.primaryGreen,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.white),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: Consumer<SupplierFormProvider>(
        builder: (context, provider, child) {
          if (provider.isLoadingMaster) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading master data...'),
                ],
              ),
            );
          }

          if (provider.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading data',
                    style: AppTextStyles.h5.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    provider.errorMessage!,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.loadMasterData(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: AppColors.white,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return _buildForm(provider);
        },
      ),
    );
  }

  Widget _buildForm(SupplierFormProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.add, color: AppColors.white),
                  const SizedBox(width: 8),
                  Text(
                    'Tambah Data POO',
                    style: AppTextStyles.h5.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Form Fields in Grid
            _buildFormGrid(provider),

            const SizedBox(height: 32),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Batal'),
                ),
                const SizedBox(width: 24),
                ElevatedButton(
                  onPressed: provider.isSubmitting ? null : () => _submitForm(provider),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: provider.isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                          ),
                        )
                      : const Text('Simpan'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormGrid(SupplierFormProvider provider) {
    return Column(
      children: [
        // Row 1: Jenis POO, Kode POO, PIC RO
        Row(
          children: [
            Expanded(child: _buildJenisDropdown(provider)),
            const SizedBox(width: 16),
            Expanded(child: _buildKodeField()),
            const SizedBox(width: 16),
            Expanded(child: _buildPicDropdown(provider)),
          ],
        ),
        const SizedBox(height: 16),

        // Row 2: Nama POO, Nama Karyawan, No WhatsApp
        Row(
          children: [
            Expanded(child: _buildTextField('Nama POO *', _nameController, required: true)),
            const SizedBox(width: 16),
            Expanded(child: _buildTextField('Nama Karyawan POO *', _karyawanController, required: true)),
            const SizedBox(width: 16),
            Expanded(child: _buildPhoneField()),
          ],
        ),
        const SizedBox(height: 16),

        // Row 3: Jabatan, Kategori POO, Jenis UCO
        Row(
          children: [
            Expanded(child: _buildTextField('Jabatan Karyawan POO *', _jabatanController, required: true)),
            const SizedBox(width: 16),
            Expanded(child: _buildKategoriDropdown(provider)),
            const SizedBox(width: 16),
            Expanded(child: _buildJenisUcoDropdown()),
          ],
        ),
        const SizedBox(height: 16),

        // Row 4: Price, Satuan Price, Provinsi
        Row(
          children: [
            Expanded(child: _buildPriceField()),
            const SizedBox(width: 16),
            Expanded(child: _buildSatuanDropdown(provider)),
            const SizedBox(width: 16),
            Expanded(child: _buildProvinsiDropdown(provider)),
          ],
        ),
        const SizedBox(height: 16),

        // Row 5: Kota, Kecamatan, Desa
        Row(
          children: [
            Expanded(child: _buildKotaDropdown(provider)),
            const SizedBox(width: 16),
            Expanded(child: _buildKecamatanDropdown(provider)),
            const SizedBox(width: 16),
            Expanded(child: _buildDesaDropdown(provider)),
          ],
        ),
        const SizedBox(height: 16),

        // Row 6: Siklus, Alamat Detail, GPS
        Row(
          children: [
            Expanded(child: _buildSiklusDropdown()),
            const SizedBox(width: 16),
            Expanded(child: _buildAlamatField()),
            const SizedBox(width: 16),
            Expanded(child: _buildGpsField()),
          ],
        ),
        const SizedBox(height: 16),

        // Row 7: Nama Rekening, Nomor Rekening, Bank
        Row(
          children: [
            Expanded(child: _buildTextField('Nama Rekening POO *', _namaRekController, required: true)),
            const SizedBox(width: 16),
            Expanded(child: _buildNomorRekeningField()),
            const SizedBox(width: 16),
            Expanded(child: _buildBankDropdown(provider)),
          ],
        ),
        const SizedBox(height: 16),

        // Row 8: Poin
        Row(
          children: [
            Expanded(child: _buildTextField('Poin POO', _poinController, keyboardType: TextInputType.number)),
            const Expanded(child: SizedBox()),
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool required = false, TextInputType? keyboardType}) {
                  controller: _pageController,
                  onPageChanged: (page) {
                    setState(() {
                      _currentPage = page;
                    });
                  },
                  children: [
                    _buildBusinessInfoStep(provider),
                    _buildLocationStep(provider),
                    _buildDetailsStep(provider),
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
      padding: const EdgeInsets.all(20),
      color: AppColors.white,
      child: Row(
        children: [
          _buildStepIndicator(0, 'Info Bisnis', _currentPage >= 0),
          Expanded(child: _buildConnector(_currentPage >= 1)),
          _buildStepIndicator(1, 'Lokasi', _currentPage >= 1),
          Expanded(child: _buildConnector(_currentPage >= 2)),
          _buildStepIndicator(2, 'Detail', _currentPage >= 2),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int step, String title, bool isActive) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive ? AppColors.primaryGreen : AppColors.borderColor,
            shape: BoxShape.circle,
          ),
          child: Icon(
            step < _currentPage ? Icons.check : Icons.circle,
            color: isActive ? AppColors.white : AppColors.textSecondary,
            size: 16,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: AppTextStyles.caption.copyWith(
            color: isActive ? AppColors.primaryGreen : AppColors.textSecondary,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildConnector(bool isActive) {
    return Container(
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isActive ? AppColors.primaryGreen : AppColors.borderColor,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }

  Widget _buildBusinessInfoStep(SupplierFormProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Informasi Bisnis',
              style: AppTextStyles.h4.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Masukkan informasi dasar tentang supplier',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),

            // Jenis Supplier
            CustomDropdown(
              label: 'Jenis Supplier *',
              items: provider.jenisSupplier,
              value: provider.selectedJenis,
              getTitle: (item) => item.name,
              onChanged: (value) {
                provider.selectedJenis = value;
                provider.notifyListeners();
              },
              hint: 'Pilih jenis supplier',
            ),
            const SizedBox(height: 16),

            // PIC/RO
            CustomDropdown(
              label: 'PIC/RO *',
              items: provider.employees,
              value: provider.selectedPic,
              getTitle: (item) =>
                  '${item.name}${item.position != null ? ' - ${item.position}' : ''}',
              onChanged: (value) {
                provider.selectedPic = value;
                provider.notifyListeners();
              },
              hint: 'Pilih PIC/RO',
            ),
            const SizedBox(height: 16),

            // Business Name
            _buildTextField(
              label: 'Nama Bisnis *',
              controller: _businessNameController,
              hint: 'Masukkan nama bisnis',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Nama bisnis wajib diisi';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Contact Person
            _buildTextField(
              label: 'Nama Karyawan *',
              controller: _contactPersonController,
              hint: 'Masukkan nama karyawan',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Nama karyawan wajib diisi';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Phone
            _buildTextField(
              label: 'No. Telepon *',
              controller: _phoneController,
              hint: 'Masukkan nomor telepon',
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Nomor telepon wajib diisi';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Position/Jabatan
            _buildTextField(
              label: 'Jabatan *',
              controller: _positionController,
              hint: 'Masukkan jabatan',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Jabatan wajib diisi';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Kategori Supplier
            if (provider.kategoriSupplier.isNotEmpty)
              CustomDropdown(
                label: 'Kategori Supplier',
                items: provider.kategoriSupplier,
                value: provider.selectedKategori,
                getTitle: (item) => item.name,
                onChanged: (value) {
                  provider.selectedKategori = value;
                  provider.notifyListeners();
                },
                hint: 'Pilih kategori supplier',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationStep(SupplierFormProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Informasi Lokasi',
            style: AppTextStyles.h4.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tentukan lokasi supplier secara akurat',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),

          // Province
          CustomDropdown(
            label: 'Provinsi *',
            items: provider.provinces,
            value: provider.selectedProvince,
            getTitle: (item) => item.name,
            onChanged: provider.onProvinceChanged,
            hint: 'Pilih provinsi',
          ),
          const SizedBox(height: 16),

          // City
          CustomDropdown(
            label: 'Kota/Kabupaten *',
            items: provider.cities,
            value: provider.selectedCity,
            getTitle: (item) => item.name,
            onChanged: provider.onCityChanged,
            isLoading: provider.isLoadingCities,
            enabled:
                provider.selectedProvince != null && !provider.isLoadingCities,
            hint: 'Pilih kota/kabupaten',
          ),
          const SizedBox(height: 16),

          // District
          CustomDropdown(
            label: 'Kecamatan *',
            items: provider.districts,
            value: provider.selectedDistrict,
            getTitle: (item) => item.name,
            onChanged: provider.onDistrictChanged,
            isLoading: provider.isLoadingDistricts,
            enabled:
                provider.selectedCity != null && !provider.isLoadingDistricts,
            hint: 'Pilih kecamatan',
          ),
          const SizedBox(height: 16),

          // Village
          CustomDropdown(
            label: 'Desa/Kelurahan *',
            items: provider.villages,
            value: provider.selectedVillage,
            getTitle: (item) => item.name,
            onChanged: (value) {
              provider.selectedVillage = value;
              provider.notifyListeners();
            },
            isLoading: provider.isLoadingVillages,
            enabled:
                provider.selectedDistrict != null &&
                !provider.isLoadingVillages,
            hint: 'Pilih desa/kelurahan',
          ),
          const SizedBox(height: 16),

          // Address
          _buildTextField(
            label: 'Alamat Lengkap *',
            controller: _addressController,
            hint: 'Masukkan alamat lengkap',
            maxLines: 3,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Alamat wajib diisi';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // GPS Location
          _buildLocationPicker(),
        ],
      ),
    );
  }

  Widget _buildDetailsStep(SupplierFormProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Detail Supplier',
            style: AppTextStyles.h4.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Lengkapi informasi detail supplier',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),

          // Jenis UCO
          _buildTextField(
            label: 'Jenis UCO',
            controller: _jenisUcoController,
            hint: 'Masukkan jenis UCO',
          ),
          const SizedBox(height: 16),

          // Price
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildTextField(
                  label: 'Harga',
                  controller: _priceController,
                  hint: 'Masukkan harga',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CustomDropdown(
                  label: 'Satuan',
                  items: provider.satuan,
                  value: provider.selectedSatuan,
                  getTitle: (item) => item.name,
                  onChanged: (value) {
                    provider.selectedSatuan = value;
                    provider.notifyListeners();
                  },
                  hint: 'Satuan',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Bank Account
          CustomDropdown(
            label: 'Bank *',
            items: provider.banks,
            value: provider.selectedBank,
            getTitle: (item) => item.namaBank,
            onChanged: (value) {
              provider.selectedBank = value;
              provider.notifyListeners();
            },
            hint: 'Pilih bank',
          ),
          const SizedBox(height: 16),

          // Account Name
          _buildTextField(
            label: 'Nama Rekening *',
            controller: _accountNameController,
            hint: 'Masukkan nama rekening',
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Nama rekening wajib diisi';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Account Number
          _buildTextField(
            label: 'Nomor Rekening *',
            controller: _accountNumberController,
            hint: 'Masukkan nomor rekening',
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Nomor rekening wajib diisi';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Cycle
          _buildTextField(
            label: 'Siklus Pengambilan',
            controller: _cycleController,
            hint: 'Masukkan siklus pengambilan',
          ),
          const SizedBox(height: 16),

          // Poin
          _buildTextField(
            label: 'Poin',
            controller: _poinController,
            hint: 'Masukkan poin',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),

          // Terms Agreement
          _buildTermsAgreement(),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.borderColor),
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
            filled: true,
            fillColor: AppColors.white,
          ),
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildLocationPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lokasi GPS (Opsional)',
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _currentPosition != null
                ? GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                      ),
                      zoom: 15,
                    ),
                    markers: _markers,
                    onMapCreated: (controller) {
                      _mapController = controller;
                    },
                    onTap: _onMapTapped,
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: AppColors.backgroundGrey,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 48,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap untuk pilih lokasi',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),
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
            _isGettingLocation ? 'Getting Location...' : 'Use Current Location',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryGreen,
            foregroundColor: AppColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTermsAgreement() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Persetujuan',
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _agreesToTerms,
            onChanged: (value) {
              setState(() {
                _agreesToTerms = value ?? false;
              });
            },
            title: Text(
              'Saya menyetujui syarat dan ketentuan yang berlaku',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.primaryGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons(SupplierFormProvider provider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentPage > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: const BorderSide(color: AppColors.primaryGreen),
                ),
                child: Text(
                  'Sebelumnya',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          if (_currentPage > 0) const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: provider.isSubmitting
                  ? null
                  : () => _handleNextButton(provider),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: provider.isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.white,
                        ),
                      ),
                    )
                  : Text(
                      _currentPage == 2 ? 'Simpan Supplier' : 'Selanjutnya',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleNextButton(SupplierFormProvider provider) {
    if (_currentPage < 2) {
      if (_validateCurrentStep()) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } else {
      _submitSupplier(provider);
    }
  }

  bool _validateCurrentStep() {
    switch (_currentPage) {
      case 0:
        if (!_formKey.currentState!.validate()) return false;
        final provider = context.read<SupplierFormProvider>();
        if (provider.selectedJenis == null || provider.selectedPic == null) {
          _showErrorDialog('Harap lengkapi semua field yang wajib diisi.');
          return false;
        }
        return true;
      case 1:
        final provider = context.read<SupplierFormProvider>();
        if (provider.selectedProvince == null ||
            provider.selectedCity == null ||
            provider.selectedDistrict == null ||
            provider.selectedVillage == null ||
            _addressController.text.isEmpty) {
          _showErrorDialog(
            'Harap lengkapi semua informasi lokasi yang wajib diisi.',
          );
          return false;
        }
        return true;
      case 2:
        final provider = context.read<SupplierFormProvider>();
        if (provider.selectedBank == null ||
            _accountNameController.text.isEmpty ||
            _accountNumberController.text.isEmpty) {
          _showErrorDialog('Harap lengkapi informasi bank yang wajib diisi.');
          return false;
        }
        if (!_agreesToTerms) {
          _showErrorDialog(
            'Anda harus menyetujui syarat dan ketentuan untuk melanjutkan.',
          );
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  Future<void> _submitSupplier(SupplierFormProvider provider) async {
    print('🔥 DEBUG: Starting supplier submission...');
    
    if (!_validateCurrentStep()) {
      print('❌ Validation failed!');
      return;
    }

    String? gpsString;
    if (_currentPosition != null) {
      gpsString =
          '${_currentPosition!.latitude},${_currentPosition!.longitude}';
    }
    
    print('📍 GPS: $gpsString');

    print('📝 Creating supplier object...');
    print('- Jenis: ${provider.selectedJenis?.name}');
    print('- PIC: ${provider.selectedPic?.name}');
    print('- Name: ${_businessNameController.text.trim()}');
    
    final supplier = Supplier(
      jenis: provider.selectedJenis!.name,
      picId: provider.selectedPic!.id,
      name: _businessNameController.text.trim(),
      karyawan: _contactPersonController.text.trim(),
      phone: _phoneController.text.trim(),
      jabatan: _positionController.text.trim(),
      kategoriId: provider.selectedKategori?.id,
      jenisUco: _jenisUcoController.text.trim().isEmpty
          ? null
          : _jenisUcoController.text.trim(),
      price: _priceController.text.trim().isEmpty
          ? null
          : double.tryParse(_priceController.text.trim()),
      priceSatuanId: provider.selectedSatuan?.id,
      provinsiId: provider.selectedProvince!.id,
      kotaId: provider.selectedCity!.id,
      kecamatanId: provider.selectedDistrict!.id,
      desaId: provider.selectedVillage!.id,
      alamat: _addressController.text.trim(),
      gps: gpsString,
      namaRek: _accountNameController.text.trim(),
      nomorRek: _accountNumberController.text.trim(),
      bankRekId: provider.selectedBank!.id,
      siklus: _cycleController.text.trim().isEmpty
          ? null
          : _cycleController.text.trim(),
      poin: _poinController.text.trim().isEmpty
          ? null
          : int.tryParse(_poinController.text.trim()),
    );

    print('🚀 Calling API to submit supplier...');
    final success = await provider.submitSupplier(supplier);
    
    print('✅ API Response: $success');

    if (success) {
      print('🎉 Success! Showing success dialog...');
      if (mounted) {
        _showSuccessDialog();
      }
    } else {
      print('❌ Failed! Showing error dialog...');
      if (mounted) {
        _showErrorDialog(
          provider.errorMessage ??
              'Gagal menyimpan supplier. Silakan coba lagi.',
        );
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Layanan GPS tidak aktif');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Izin lokasi ditolak');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Izin lokasi ditolak secara permanen');
      }

      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
        _markers = {
          Marker(
            markerId: const MarkerId('supplier_location'),
            position: LatLng(position.latitude, position.longitude),
            infoWindow: const InfoWindow(title: 'Lokasi Supplier'),
          ),
        };
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          15,
        ),
      );
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Gagal mendapatkan lokasi: $e');
      }
    } finally {
      setState(() {
        _isGettingLocation = false;
      });
    }
  }

  void _onMapTapped(LatLng latLng) {
    setState(() {
      _currentPosition = Position(
        latitude: latLng.latitude,
        longitude: latLng.longitude,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
      );
      _markers = {
        Marker(
          markerId: const MarkerId('supplier_location'),
          position: latLng,
          infoWindow: const InfoWindow(title: 'Lokasi Supplier'),
        ),
      };
    });
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green.shade400),
            const SizedBox(height: 16),
            Text(
              'Berhasil!',
              style: AppTextStyles.h5.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Text(
          'Supplier berhasil ditambahkan ke sistem.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back to previous screen
            },
            child: Text(
              'OK',
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.primaryGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade400),
            const SizedBox(width: 8),
            Text(
              'Error',
              style: AppTextStyles.h5.copyWith(
                color: Colors.red.shade400,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'OK',
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.primaryGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
