import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

class AddSupplierScreen extends StatefulWidget {
  const AddSupplierScreen({super.key});

  @override
  State<AddSupplierScreen> createState() => _AddSupplierScreenState();
}

class _AddSupplierScreenState extends State<AddSupplierScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  int _currentPage = 0;
  bool _isLoading = false;
  bool _isGettingLocation = false;

  // Form Controllers
  final _businessNameController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _estimatedVolumeController = TextEditingController();
  final _notesController = TextEditingController();

  // Location data
  Position? _currentPosition;
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};

  // Form data
  String _selectedCategory = 'Restoran';
  String _selectedSchedule = 'Harian';
  String _selectedOilType = 'UCO (Used Cooking Oil)';
  bool _hasStorageTank = false;
  bool _agreesToTerms = false;

  final List<String> _categoryOptions = [
    'Restoran',
    'Hotel',
    'Warung Makan',
    'Fast Food',
    'Katering',
    'Pabrik Makanan',
    'Lainnya',
  ];

  final List<String> _scheduleOptions = [
    'Harian',
    'Setiap 2 Hari',
    'Setiap 3 Hari',
    'Mingguan',
    'Sesuai Permintaan',
  ];

  final List<String> _oilTypeOptions = [
    'UCO (Used Cooking Oil)',
    'Minyak Goreng Bekas',
    'Lemak Hewani',
    'Minyak Campuran',
  ];

  @override
  void dispose() {
    _businessNameController.dispose();
    _contactPersonController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _estimatedVolumeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services disabled');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _markers = {
          Marker(
            markerId: const MarkerId('supplier_location'),
            position: LatLng(position.latitude, position.longitude),
            infoWindow: const InfoWindow(
              title: 'Lokasi Supplier',
              snippet: 'Tap untuk edit lokasi',
            ),
            draggable: true,
            onDragEnd: (newPosition) {
              setState(() {
                _currentPosition = Position(
                  latitude: newPosition.latitude,
                  longitude: newPosition.longitude,
                  timestamp: DateTime.now(),
                  accuracy: position.accuracy,
                  altitude: position.altitude,
                  altitudeAccuracy: position.altitudeAccuracy,
                  heading: position.heading,
                  headingAccuracy: position.headingAccuracy,
                  speed: position.speed,
                  speedAccuracy: position.speedAccuracy,
                );
              });
            },
          ),
        };
      });

      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 16,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error getting location: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isGettingLocation = false;
      });
    }
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _submitForm();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _validateCurrentPage() {
    switch (_currentPage) {
      case 0:
        return _businessNameController.text.isNotEmpty &&
            _contactPersonController.text.isNotEmpty &&
            _phoneController.text.isNotEmpty;
      case 1:
        return _addressController.text.isNotEmpty && _currentPosition != null;
      case 2:
        return _estimatedVolumeController.text.isNotEmpty && _agreesToTerms;
      default:
        return false;
    }
  }

  Future<void> _submitForm() async {
    if (!_validateCurrentPage()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mohon lengkapi semua field yang wajib'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Simulate API call
      await Future.delayed(const Duration(seconds: 2));

      // TODO: Implement actual API call to save supplier data
      final supplierData = {
        'business_name': _businessNameController.text,
        'contact_person': _contactPersonController.text,
        'phone': _phoneController.text,
        'email': _emailController.text,
        'address': _addressController.text,
        'latitude': _currentPosition?.latitude,
        'longitude': _currentPosition?.longitude,
        'category': _selectedCategory,
        'estimated_volume': _estimatedVolumeController.text,
        'oil_type': _selectedOilType,
        'pickup_schedule': _selectedSchedule,
        'has_storage_tank': _hasStorageTank,
        'notes': _notesController.text,
      };

      print('Supplier data to submit: $supplierData');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Supplier berhasil didaftarkan!'),
          backgroundColor: AppColors.primaryGreen,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: AppColors.white,
        title: Text(
          'Tambah Supplier Baru',
          style: AppTextStyles.h5.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(
              'Batal',
              style: AppTextStyles.bodyLarge.copyWith(color: AppColors.white),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress Indicator
          _buildProgressIndicator(),

          // Form Pages
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (page) {
                setState(() {
                  _currentPage = page;
                });
              },
              children: [
                _buildBusinessInfoPage(),
                _buildLocationPage(),
                _buildDetailsPage(),
              ],
            ),
          ),

          // Navigation Buttons
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: AppColors.white,
      child: Column(
        children: [
          Row(
            children: [
              for (int i = 0; i < 3; i++) ...[
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: i <= _currentPage
                          ? AppColors.primaryGreen
                          : AppColors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                if (i < 2) const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Info Bisnis',
                style: AppTextStyles.caption.copyWith(
                  color: _currentPage >= 0
                      ? AppColors.primaryGreen
                      : AppColors.grey,
                  fontWeight: _currentPage == 0
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
              Text(
                'Lokasi',
                style: AppTextStyles.caption.copyWith(
                  color: _currentPage >= 1
                      ? AppColors.primaryGreen
                      : AppColors.grey,
                  fontWeight: _currentPage == 1
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
              Text(
                'Detail',
                style: AppTextStyles.caption.copyWith(
                  color: _currentPage >= 2
                      ? AppColors.primaryGreen
                      : AppColors.grey,
                  fontWeight: _currentPage == 2
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessInfoPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Informasi Bisnis',
              style: AppTextStyles.h5.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Masukkan informasi dasar tentang bisnis supplier',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),

            // Business Name
            _buildTextFieldCard(
              label: 'Nama Bisnis *',
              controller: _businessNameController,
              hint: 'contoh: RM. Ayam Goreng Berkah',
              icon: Icons.store,
            ),
            const SizedBox(height: 16),

            // Contact Person
            _buildTextFieldCard(
              label: 'Nama Kontak Person *',
              controller: _contactPersonController,
              hint: 'contoh: Budi Santoso',
              icon: Icons.person,
            ),
            const SizedBox(height: 16),

            // Phone
            _buildTextFieldCard(
              label: 'Nomor Telepon *',
              controller: _phoneController,
              hint: 'contoh: 08123456789',
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(15),
              ],
            ),
            const SizedBox(height: 16),

            // Email (Optional)
            _buildTextFieldCard(
              label: 'Email',
              controller: _emailController,
              hint: 'contoh: supplier@email.com',
              icon: Icons.email,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),

            // Category
            _buildDropdownCard(
              label: 'Kategori Bisnis *',
              value: _selectedCategory,
              options: _categoryOptions,
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value!;
                });
              },
              icon: Icons.category,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lokasi Supplier',
            style: AppTextStyles.h5.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Tentukan alamat dan koordinat GPS lokasi supplier',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),

          // Address
          _buildTextFieldCard(
            label: 'Alamat Lengkap *',
            controller: _addressController,
            hint: 'Jl. Veteran No. 12, Malang, Jawa Timur',
            icon: Icons.location_on,
            maxLines: 3,
          ),
          const SizedBox(height: 16),

          // GPS Location Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isGettingLocation ? null : _getCurrentLocation,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _isGettingLocation
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : const Icon(Icons.my_location),
              label: Text(
                _isGettingLocation
                    ? 'Mengambil Lokasi...'
                    : _currentPosition != null
                    ? 'Update Lokasi GPS'
                    : 'Ambil Lokasi GPS',
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Map View
          if (_currentPosition != null) ...[
            Container(
              height: 300,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
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
                initialCameraPosition: CameraPosition(
                  target: LatLng(
                    _currentPosition!.latitude,
                    _currentPosition!.longitude,
                  ),
                  zoom: 16,
                ),
                markers: _markers,
                onMapCreated: (GoogleMapController controller) {
                  _mapController = controller;
                },
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                onTap: (LatLng position) {
                  setState(() {
                    _currentPosition = Position(
                      latitude: position.latitude,
                      longitude: position.longitude,
                      timestamp: DateTime.now(),
                      accuracy: _currentPosition!.accuracy,
                      altitude: _currentPosition!.altitude,
                      altitudeAccuracy: _currentPosition!.altitudeAccuracy,
                      heading: _currentPosition!.heading,
                      headingAccuracy: _currentPosition!.headingAccuracy,
                      speed: _currentPosition!.speed,
                      speedAccuracy: _currentPosition!.speedAccuracy,
                    );
                    _markers = {
                      Marker(
                        markerId: const MarkerId('supplier_location'),
                        position: position,
                        infoWindow: const InfoWindow(
                          title: 'Lokasi Supplier',
                          snippet: 'Lokasi yang dipilih',
                        ),
                      ),
                    };
                  });
                },
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.primaryGreen.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppColors.primaryGreen,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Koordinat: ${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Detail Penjemputan',
            style: AppTextStyles.h5.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Informasi teknis untuk penjemputan minyak jelantah',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),

          // Estimated Volume
          _buildTextFieldCard(
            label: 'Estimasi Volume per Minggu (Liter) *',
            controller: _estimatedVolumeController,
            hint: 'contoh: 25',
            icon: Icons.local_gas_station,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 16),

          // Oil Type
          _buildDropdownCard(
            label: 'Jenis Minyak *',
            value: _selectedOilType,
            options: _oilTypeOptions,
            onChanged: (value) {
              setState(() {
                _selectedOilType = value!;
              });
            },
            icon: Icons.opacity,
          ),
          const SizedBox(height: 16),

          // Pickup Schedule
          _buildDropdownCard(
            label: 'Jadwal Penjemputan *',
            value: _selectedSchedule,
            options: _scheduleOptions,
            onChanged: (value) {
              setState(() {
                _selectedSchedule = value!;
              });
            },
            icon: Icons.schedule,
          ),
          const SizedBox(height: 16),

          // Storage Tank
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.grey.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.storage,
                    color: AppColors.primaryGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Memiliki Tangki Penyimpanan',
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Apakah supplier memiliki tangki penyimpanan?',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _hasStorageTank,
                  onChanged: (value) {
                    setState(() {
                      _hasStorageTank = value;
                    });
                  },
                  activeColor: AppColors.primaryGreen,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Notes
          _buildTextFieldCard(
            label: 'Catatan Tambahan',
            controller: _notesController,
            hint: 'Catatan khusus untuk driver atau hal penting lainnya',
            icon: Icons.note_alt,
            maxLines: 3,
          ),
          const SizedBox(height: 16),

          // Terms Agreement
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.grey.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _agreesToTerms,
                  onChanged: (value) {
                    setState(() {
                      _agreesToTerms = value!;
                    });
                  },
                  activeColor: AppColors.primaryGreen,
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _agreesToTerms = !_agreesToTerms;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: RichText(
                        text: TextSpan(
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          children: [
                            const TextSpan(text: 'Saya setuju dengan '),
                            TextSpan(
                              text: 'Syarat dan Ketentuan',
                              style: TextStyle(
                                color: AppColors.primaryGreen,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const TextSpan(text: ' serta '),
                            TextSpan(
                              text: 'Kebijakan Privasi',
                              style: TextStyle(
                                color: AppColors.primaryGreen,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const TextSpan(text: ' yang berlaku.'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextFieldCard({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey.withOpacity(0.2)),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, color: AppColors.primaryGreen, size: 16),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextFormField(
              controller: controller,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              maxLines: maxLines,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: AppColors.grey.withOpacity(0.3),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: AppColors.grey.withOpacity(0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: AppColors.primaryGreen,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownCard({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey.withOpacity(0.2)),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, color: AppColors.primaryGreen, size: 16),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: DropdownButtonFormField<String>(
              value: value,
              onChanged: onChanged,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: AppColors.grey.withOpacity(0.3),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: AppColors.grey.withOpacity(0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: AppColors.primaryGreen,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              items: options.map((String option) {
                return DropdownMenuItem<String>(
                  value: option,
                  child: Text(option),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentPage > 0) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: _previousPage,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.primaryGreen),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
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
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: _currentPage > 0 ? 1 : 2,
            child: ElevatedButton(
              onPressed: (_validateCurrentPage() && !_isLoading)
                  ? _nextPage
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : Text(
                      _currentPage < 2 ? 'Selanjutnya' : 'Simpan',
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
