import 'package:flutter/foundation.dart';
import '../models/dropdown_models.dart';
import '../models/geographic_models.dart';
import '../models/supplier_model.dart';
import '../services/api/supplier_api_service.dart';

class SupplierFormProvider extends ChangeNotifier {
  // Dropdown data
  List<JenisSupplier> _jenisSupplier = [];
  List<KategoriSupplier> _kategoriSupplier = [];
  List<Employee> _employees = [];
  List<Bank> _banks = [];
  List<Satuan> _satuan = [];
  List<Province> _provinces = [];
  List<City> _cities = [];
  List<District> _districts = [];
  List<Village> _villages = [];

  // Selected values
  JenisSupplier? selectedJenis;
  KategoriSupplier? selectedKategori;
  Employee? selectedPic;
  Province? selectedProvince;
  City? selectedCity;
  District? selectedDistrict;
  Village? selectedVillage;
  Bank? selectedBank;
  Satuan? selectedSatuan;

  // Loading states
  bool _isLoadingMaster = false;
  bool _isLoadingCities = false;
  bool _isLoadingDistricts = false;
  bool _isLoadingVillages = false;
  bool _isSubmitting = false;
  bool _isValidatingAccount = false;

  // Error handling
  String? _errorMessage;

  // Getters
  List<JenisSupplier> get jenisSupplier => _jenisSupplier;
  List<KategoriSupplier> get kategoriSupplier => _kategoriSupplier;
  List<Employee> get employees => _employees;
  List<Bank> get banks => _banks;
  List<Satuan> get satuan => _satuan;
  List<Province> get provinces => _provinces;
  List<City> get cities => _cities;
  List<District> get districts => _districts;
  List<Village> get villages => _villages;

  bool get isLoadingMaster => _isLoadingMaster;
  bool get isLoadingCities => _isLoadingCities;
  bool get isLoadingDistricts => _isLoadingDistricts;
  bool get isLoadingVillages => _isLoadingVillages;
  bool get isSubmitting => _isSubmitting;
  bool get isValidatingAccount => _isValidatingAccount;

  String? get errorMessage => _errorMessage;

  // Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Lets form fields notify dependent dropdowns without exposing the
  /// protected ChangeNotifier API to widgets.
  void refreshSelection() => notifyListeners();

  // Load initial master data
  Future<void> loadMasterData() async {
    print('🔄 Loading master data...');
    _isLoadingMaster = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await SupplierApiService.getDropdownOptions();
      print('🌐 API Response: ${response.status}');

      if (response.status && response.data != null) {
        final data = response.data!;

        _jenisSupplier =
            (data['jenis_supplier'] as List?)
                ?.map((item) => JenisSupplier.fromJson(item))
                .toList() ??
            [];

        _kategoriSupplier =
            (data['kategori_supplier'] as List?)
                ?.map((item) => KategoriSupplier.fromJson(item))
                .toList() ??
            [];

        _employees =
            (data['employees'] as List?)
                ?.map((item) => Employee.fromJson(item))
                .toList() ??
            [];

        _provinces =
            (data['provinces'] as List?)
                ?.map((item) => Province.fromJson(item))
                .toList() ??
            [];

        _banks =
            (data['banks'] as List?)
                ?.map((item) => Bank.fromJson(item))
                .toList() ??
            [];

        _satuan =
            (data['satuan'] as List?)
                ?.map((item) => Satuan.fromJson(item))
                .toList() ??
            [];
      } else {
        print('⚠️ API failed, loading dummy data...');
        _loadDummyData();
      }
    } catch (e) {
      print('❌ Error: $e, loading dummy data...');
      _loadDummyData();
    }

    _isLoadingMaster = false;
    notifyListeners();
  }

  // Load dummy data as fallback
  void _loadDummyData() {
    print('📊 Loading dummy data...');

    _jenisSupplier = [
      JenisSupplier(id: 1, name: 'Restoran'),
      JenisSupplier(id: 2, name: 'Hotel'),
      JenisSupplier(id: 3, name: 'Catering'),
      JenisSupplier(id: 4, name: 'Rumah Sakit'),
      JenisSupplier(id: 5, name: 'Pabrik'),
    ];

    _kategoriSupplier = [
      KategoriSupplier(id: 1, name: 'Kategori A'),
      KategoriSupplier(id: 2, name: 'Kategori B'),
      KategoriSupplier(id: 3, name: 'Kategori C'),
    ];

    _employees = [
      Employee(id: 1, name: 'John Doe', jabatan: 'Sales Manager'),
      Employee(id: 2, name: 'Jane Smith', jabatan: 'Account Manager'),
      Employee(id: 3, name: 'Ahmad Rizki', jabatan: 'Field Sales'),
    ];

    _provinces = [
      Province(id: 11, name: 'DKI Jakarta'),
      Province(id: 12, name: 'Jawa Barat'),
      Province(id: 13, name: 'Jawa Tengah'),
      Province(id: 14, name: 'Jawa Timur'),
      Province(id: 15, name: 'Banten'),
    ];

    _banks = [
      Bank(id: 1, namaBank: 'Bank BCA', kodeBank: '014'),
      Bank(id: 2, namaBank: 'Bank Mandiri', kodeBank: '008'),
      Bank(id: 3, namaBank: 'Bank BNI', kodeBank: '009'),
      Bank(id: 4, namaBank: 'Bank BRI', kodeBank: '002'),
      Bank(id: 5, namaBank: 'Bank CIMB Niaga', kodeBank: '022'),
    ];

    _satuan = [
      Satuan(id: 1, name: 'Liter'),
      Satuan(id: 2, name: 'Kg'),
      Satuan(id: 3, name: 'Ton'),
    ];

    print('✅ Dummy data loaded successfully');
  }

  void _loadDummyCities(int provinceId) {
    _cities = [
      City(id: 1101, name: 'Jakarta Pusat', idProvinsi: 11),
      City(id: 1102, name: 'Jakarta Utara', idProvinsi: 11),
      City(id: 1103, name: 'Jakarta Barat', idProvinsi: 11),
      City(id: 1104, name: 'Jakarta Selatan', idProvinsi: 11),
      City(id: 1105, name: 'Jakarta Timur', idProvinsi: 11),
      City(id: 1201, name: 'Bandung', idProvinsi: 12),
      City(id: 1202, name: 'Bekasi', idProvinsi: 12),
      City(id: 1203, name: 'Depok', idProvinsi: 12),
    ];
  }

  void _loadDummyDistricts(int cityId) {
    _districts = [
      District(id: 110101, name: 'Menteng', idKota: 1101),
      District(id: 110102, name: 'Tanah Abang', idKota: 1101),
      District(id: 110103, name: 'Kemayoran', idKota: 1101),
      District(id: 110201, name: 'Kelapa Gading', idKota: 1102),
      District(id: 110202, name: 'Tanjung Priok', idKota: 1102),
    ];
  }

  void _loadDummyVillages(int districtId) {
    _villages = [
      Village(id: 1101011001, name: 'Menteng', idKecamatan: 110101),
      Village(id: 1101011002, name: 'Pegangsaan', idKecamatan: 110101),
      Village(id: 1101011003, name: 'Cikini', idKecamatan: 110101),
      Village(id: 1101021001, name: 'Bendungan Hilir', idKecamatan: 110102),
      Village(id: 1101021002, name: 'Karet Tengsin', idKecamatan: 110102),
    ];
  }

  // Handle province selection
  Future<void> onProvinceChanged(Province? province) async {
    selectedProvince = province;
    selectedCity = null;
    selectedDistrict = null;
    selectedVillage = null;
    _cities.clear();
    _districts.clear();
    _villages.clear();

    if (province != null) {
      _isLoadingCities = true;
      _errorMessage = null;
      notifyListeners();

      try {
        final response = await SupplierApiService.getCities(province.id);
        if (response.status && response.data != null) {
          _cities = response.data!;
        } else {
          print('⚠️ Cities API failed, using dummy data');
          _loadDummyCities(province.id);
        }
      } catch (e) {
        print('❌ Cities error: $e, using dummy data');
        _loadDummyCities(province.id);
        _errorMessage = 'Failed to load cities: $e';
      }

      _isLoadingCities = false;
    }

    notifyListeners();
  }

  // Handle city selection
  Future<void> onCityChanged(City? city) async {
    selectedCity = city;
    selectedDistrict = null;
    selectedVillage = null;
    _districts.clear();
    _villages.clear();

    if (city != null) {
      _isLoadingDistricts = true;
      _errorMessage = null;
      notifyListeners();

      try {
        final response = await SupplierApiService.getDistricts(city.id);
        if (response.status && response.data != null) {
          _districts = response.data!;
        } else {
          print('⚠️ Districts API failed, using dummy data');
          _loadDummyDistricts(city.id);
        }
      } catch (e) {
        print('❌ Districts error: $e, using dummy data');
        _loadDummyDistricts(city.id);
        _errorMessage = 'Failed to load districts: $e';
      }

      _isLoadingDistricts = false;
    }

    notifyListeners();
  }

  // Handle district selection
  Future<void> onDistrictChanged(District? district) async {
    selectedDistrict = district;
    selectedVillage = null;
    _villages.clear();

    if (district != null) {
      _isLoadingVillages = true;
      _errorMessage = null;
      notifyListeners();

      try {
        final response = await SupplierApiService.getVillages(district.id);
        if (response.status && response.data != null) {
          _villages = response.data!;
        } else {
          print('⚠️ Villages API failed, using dummy data');
          _loadDummyVillages(district.id);
        }
      } catch (e) {
        print('❌ Villages error: $e, using dummy data');
        _loadDummyVillages(district.id);
        _errorMessage = 'Failed to load villages: $e';
      }

      _isLoadingVillages = false;
    }

    notifyListeners();
  }

  // Validate bank account (optional)
  Future<bool> validateBankAccount(String nomorRek, String namaRek) async {
    if (selectedBank == null) return false;

    _isValidatingAccount = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await SupplierApiService.validateAccount(
        nomorRek: nomorRek,
        bank: selectedBank!.kodeBank,
        namaRek: namaRek,
      );

      if (!response.status) {
        _errorMessage = response.message;
      }

      _isValidatingAccount = false;
      notifyListeners();

      return response.status;
    } catch (e) {
      _errorMessage = 'Failed to validate account: $e';
      _isValidatingAccount = false;
      notifyListeners();
      return false;
    }
  }

  // Submit supplier
  Future<bool> submitSupplier(Supplier supplier) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await SupplierApiService.createSupplier(supplier);

      if (!response.status) {
        // Parse validation errors if available
        if (response.message?.contains('Validation Error') == true) {
          _errorMessage =
              'Validation Error: Terdapat kesalahan pada data yang dikirim';
        } else {
          _errorMessage = response.message ?? 'Gagal menambahkan supplier';
        }
      }

      _isSubmitting = false;
      notifyListeners();

      return response.status;
    } catch (e) {
      _errorMessage = 'Failed to create supplier: $e';
      _isSubmitting = false;
      notifyListeners();
      return false;
    }
  }

  // Reset form
  void resetForm() {
    selectedJenis = null;
    selectedKategori = null;
    selectedPic = null;
    selectedProvince = null;
    selectedCity = null;
    selectedDistrict = null;
    selectedVillage = null;
    selectedBank = null;
    selectedSatuan = null;

    _cities.clear();
    _districts.clear();
    _villages.clear();
    _errorMessage = null;

    notifyListeners();
  }
}
