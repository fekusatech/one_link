import 'package:flutter/foundation.dart';
import '../models/supplier_model.dart';
import '../services/api/supplier_api_service.dart';

class SupplierListProvider extends ChangeNotifier {
  // Data
  List<Supplier> _suppliers = [];
  int _total = 0;
  int _currentPage = 1;
  int _lastPage = 1;

  // Search and filter states
  String _searchQuery = '';
  String _selectedStatus = '';
  String _selectedCategory = '';

  // Loading states
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isRefreshing = false;

  // Error handling
  String? _errorMessage;

  // Getters
  List<Supplier> get suppliers => _suppliers;
  int get total => _total;
  int get currentPage => _currentPage;
  int get lastPage => _lastPage;
  String get searchQuery => _searchQuery;
  String get selectedStatus => _selectedStatus;
  String get selectedCategory => _selectedCategory;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get isRefreshing => _isRefreshing;
  String? get errorMessage => _errorMessage;
  bool get hasNextPage => _currentPage < _lastPage;

  // Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Load suppliers with optional filters
  Future<void> loadSuppliers({
    bool refresh = false,
    String search = '',
    String status = '',
    String category = '',
  }) async {
    if (refresh) {
      _isRefreshing = true;
      _currentPage = 1;
      _suppliers.clear();
    } else {
      _isLoading = true;
    }

    _searchQuery = search;
    _selectedStatus = status;
    _selectedCategory = category;
    _errorMessage = null;

    notifyListeners();

    try {
      final response = await SupplierApiService.getSupplierList(
        page: _currentPage,
        limit: 25,
        search: search,
        status: status,
        category: category,
      );

      if (response.status && response.data != null) {
        final data = response.data!;

        if (refresh || _currentPage == 1) {
          _suppliers = data.suppliers;
        } else {
          _suppliers.addAll(data.suppliers);
        }

        _total = data.total;
        _currentPage = data.currentPage;
        _lastPage = data.lastPage;
      } else {
        _errorMessage = response.message;
      }
    } catch (e) {
      _errorMessage = 'Failed to load suppliers: $e';
    }

    _isLoading = false;
    _isRefreshing = false;
    notifyListeners();
  }

  // Load more suppliers (pagination)
  Future<void> loadMoreSuppliers() async {
    if (_isLoadingMore || !hasNextPage) return;

    _isLoadingMore = true;
    _currentPage++;
    notifyListeners();

    try {
      final response = await SupplierApiService.getSupplierList(
        page: _currentPage,
        limit: 25,
        search: _searchQuery,
        status: _selectedStatus,
        category: _selectedCategory,
      );

      if (response.status && response.data != null) {
        final data = response.data!;
        _suppliers.addAll(data.suppliers);
        _lastPage = data.lastPage;
      } else {
        _errorMessage = response.message;
        _currentPage--; // Revert page increment on error
      }
    } catch (e) {
      _errorMessage = 'Failed to load more suppliers: $e';
      _currentPage--; // Revert page increment on error
    }

    _isLoadingMore = false;
    notifyListeners();
  }

  // Refresh suppliers list
  Future<void> refreshSuppliers() async {
    await loadSuppliers(
      refresh: true,
      search: _searchQuery,
      status: _selectedStatus,
      category: _selectedCategory,
    );
  }

  // Search suppliers
  Future<void> searchSuppliers(String query) async {
    await loadSuppliers(
      refresh: true,
      search: query,
      status: _selectedStatus,
      category: _selectedCategory,
    );
  }

  // Filter by status
  Future<void> filterByStatus(String status) async {
    await loadSuppliers(
      refresh: true,
      search: _searchQuery,
      status: status,
      category: _selectedCategory,
    );
  }

  // Filter by category
  Future<void> filterByCategory(String category) async {
    await loadSuppliers(
      refresh: true,
      search: _searchQuery,
      status: _selectedStatus,
      category: category,
    );
  }

  // Toggle supplier status
  Future<bool> toggleSupplierStatus(int supplierId) async {
    try {
      final response = await SupplierApiService.toggleSupplierStatus(
        supplierId,
      );

      if (response.status) {
        // Find and update the supplier status locally
        final index = _suppliers.indexWhere((s) => s.id == supplierId);
        if (index != -1) {
          final supplier = _suppliers[index];
          final newStatus = supplier.status == 'active' ? 'inactive' : 'active';
          _suppliers[index] = Supplier(
            id: supplier.id,
            kodePoo: supplier.kodePoo,
            jenis: supplier.jenis,
            picId: supplier.picId,
            name: supplier.name,
            karyawan: supplier.karyawan,
            phone: supplier.phone,
            jabatan: supplier.jabatan,
            kategoriId: supplier.kategoriId,
            jenisUco: supplier.jenisUco,
            price: supplier.price,
            priceSatuanId: supplier.priceSatuanId,
            provinsiId: supplier.provinsiId,
            kotaId: supplier.kotaId,
            kecamatanId: supplier.kecamatanId,
            desaId: supplier.desaId,
            alamat: supplier.alamat,
            gps: supplier.gps,
            namaRek: supplier.namaRek,
            nomorRek: supplier.nomorRek,
            bankRekId: supplier.bankRekId,
            siklus: supplier.siklus,
            poin: supplier.poin,
            status: newStatus,
            createdAt: supplier.createdAt,
            updatedAt: DateTime.now(),
          );
          notifyListeners();
        }
        return true;
      } else {
        _errorMessage = response.message;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Failed to toggle supplier status: $e';
      notifyListeners();
      return false;
    }
  }

  // Get supplier by ID
  Supplier? getSupplierById(int id) {
    try {
      return _suppliers.firstWhere((s) => s.id == id);
    } catch (e) {
      return null;
    }
  }

  // Clear all filters
  Future<void> clearFilters() async {
    await loadSuppliers(refresh: true);
  }
}
