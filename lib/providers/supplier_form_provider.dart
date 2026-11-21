import 'package:flutter/foundation.dart';
import '../models/dropdown_models.dart';
import '../models/geographic_models.dart';
import '../models/supplier_model.dart';
import '../services/api/supplier_api_service.dart';

class SupplierFormProvider extends ChangeNotifier {
  List<JenisSupplier> _jenisSupplier = [];
  List<KategoriSupplier> _kategoriSupplier = [];
  List<Bank> _banks = [];
  List<Satuan> _satuan = [];
  List<Province> _provinces = [];
  List<City> _cities = [];
  List<District> _districts = [];
  List<Village> _villages = [];

  JenisSupplier? selectedJenis;
  KategoriSupplier? selectedKategori;
  Employee? selectedPic;
  Province? selectedProvince;
  City? selectedCity;
  District? selectedDistrict;
  Village? selectedVillage;
  Bank? selectedBank;
  Satuan? selectedSatuan;

  bool _isLoadingMaster = false;
  bool _isLoadingCities = false;
  bool _isLoadingDistricts = false;
  bool _isLoadingVillages = false;
  bool _isSubmitting = false;
  bool _isValidatingAccount = false;

  String? _errorMessage;
  bool _needsApproval = false;

  List<JenisSupplier> get jenisSupplier => _jenisSupplier;
  List<KategoriSupplier> get kategoriSupplier => _kategoriSupplier;
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
  bool get needsApproval => _needsApproval;

  String? get errorMessage => _errorMessage;
  bool get masterDataFailed => _errorMessage != null && _jenisSupplier.isEmpty;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void refreshSelection() => notifyListeners();

  Future<void> loadMasterData() async {
    _isLoadingMaster = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await SupplierApiService.getDropdownOptions();

      if (response.status && response.data != null) {
        final data = response.data!;

        _jenisSupplier =
            (data['jenis_supplier'] as List?)
                ?.map((item) => JenisSupplier.fromJson(item as Map<String, dynamic>))
                .toList() ??
            [];

        _kategoriSupplier =
            (data['kategori_supplier'] as List?)
                ?.map((item) => KategoriSupplier.fromJson(item as Map<String, dynamic>))
                .toList() ??
            [];

        _provinces =
            (data['provinces'] as List?)
                ?.map((item) => Province.fromJson(item as Map<String, dynamic>))
                .toList() ??
            [];

        _banks =
            (data['banks'] as List?)
                ?.map((item) => Bank.fromJson(item as Map<String, dynamic>))
                .toList() ??
            [];

        _satuan =
            (data['satuan'] as List?)
                ?.map((item) => Satuan.fromJson(item as Map<String, dynamic>))
                .toList() ??
            [];
      } else {
        _errorMessage = response.message.isNotEmpty
            ? response.message
            : 'Gagal memuat data master. Periksa koneksi lalu coba lagi.';
      }
    } catch (e) {
      _errorMessage = 'Gagal memuat data master. Periksa koneksi lalu coba lagi.';
    }

    _isLoadingMaster = false;
    notifyListeners();
  }

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
          _errorMessage = response.message.isNotEmpty
              ? response.message
              : 'Gagal memuat kota.';
        }
      } catch (e) {
        _errorMessage = 'Gagal memuat kota. Periksa koneksi lalu coba lagi.';
      }

      _isLoadingCities = false;
    }

    notifyListeners();
  }

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
          _errorMessage = response.message.isNotEmpty
              ? response.message
              : 'Gagal memuat kecamatan.';
        }
      } catch (e) {
        _errorMessage = 'Gagal memuat kecamatan. Periksa koneksi lalu coba lagi.';
      }

      _isLoadingDistricts = false;
    }

    notifyListeners();
  }

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
          _errorMessage = response.message.isNotEmpty
              ? response.message
              : 'Gagal memuat desa.';
        }
      } catch (e) {
        _errorMessage = 'Gagal memuat desa. Periksa koneksi lalu coba lagi.';
      }

      _isLoadingVillages = false;
    }

    notifyListeners();
  }

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
      _errorMessage = 'Gagal memvalidasi rekening. Coba lagi.';
      _isValidatingAccount = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> submitSupplier(Supplier supplier) async {
    _isSubmitting = true;
    _errorMessage = null;
    _needsApproval = false;
    notifyListeners();

    try {
      final response = await SupplierApiService.createSupplier(supplier);

      if (!response.status) {
        _errorMessage = response.message.isNotEmpty
            ? response.message
            : 'Gagal menambahkan supplier';
      }

      _isSubmitting = false;
      notifyListeners();

      return response.status;
    } catch (e) {
      _errorMessage = 'Gagal menambahkan supplier. Coba lagi.';
      _isSubmitting = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateSupplier(int id, Supplier supplier) async {
    _isSubmitting = true;
    _errorMessage = null;
    _needsApproval = false;
    notifyListeners();

    try {
      final response = await SupplierApiService.updateSupplier(id, supplier);

      if (!response.status) {
        _errorMessage = response.message.isNotEmpty
            ? response.message
            : 'Gagal memperbarui supplier';
      } else if (response.message.contains('persetujuan')) {
        _needsApproval = true;
      }

      _isSubmitting = false;
      notifyListeners();

      return response.status;
    } catch (e) {
      _errorMessage = 'Gagal memperbarui supplier. Coba lagi.';
      _isSubmitting = false;
      notifyListeners();
      return false;
    }
  }

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
    _needsApproval = false;

    notifyListeners();
  }
}
