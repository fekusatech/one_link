import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../widgets/empty_tasks_widget.dart';
import 'calendar_screen.dart';
import 'notification_screen.dart';
import 'profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // List of screens
    final List<Widget> screens = [
      const _HomeScreen(),
      const CalendarScreen(),
      const NotificationScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _selectedIndex == 0
          ? AppBar(
              backgroundColor: AppColors.white,
              elevation: 0,
              title: Text(
                'One Link',
                style: AppTextStyles.h4.copyWith(
                  color: AppColors.primaryGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  color: AppColors.primaryGreen,
                  onPressed: () {
                    // TODO: QR Code scan functionality
                  },
                ),
              ],
            )
          : null,
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.white,
        selectedItemColor: AppColors.primaryGreen,
        unselectedItemColor: AppColors.grey,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Jadwal',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Notifikasi',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}

// Home Screen Widget
class _HomeScreen extends StatefulWidget {
  const _HomeScreen();

  @override
  State<_HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<_HomeScreen> {
  GoogleMapController? _mapController;
  bool _isMapView = true;

  // Flag untuk mengontrol apakah ada tugas hari ini
  // Set ke false untuk menampilkan empty state, true untuk menampilkan tugas
  bool _hasTodayTasks = false; // Ubah ini untuk testing

  // Default location (Malang, Indonesia)
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(-7.9666, 112.6326),
    zoom: 14,
  );

  // Sample pickup locations data
  final List<Map<String, dynamic>> _pickupLocations = [
    {
      'name': 'RM. Ayam Goreng Berkah',
      'address': 'Jl. Veteran No. 12, Malang',
      'volume': '25L',
      'distance': '2.3 km',
      'status': 'Pending',
      'lat': -7.9797,
      'lng': 112.6304,
    },
    {
      'name': 'Warung Makan Sari Rasa',
      'address': 'Jl. Soekarno Hatta No. 45, Malang',
      'volume': '18L',
      'distance': '5.1 km',
      'status': 'Dijadwalkan',
      'lat': -7.9553,
      'lng': 112.6141,
    },
    {
      'name': 'Rumah Makan Padang',
      'address': 'Jl. Tlogomas No. 78, Malang',
      'volume': '30L',
      'distance': '3.7 km',
      'status': 'Pending',
      'lat': -7.9758,
      'lng': 112.6589,
    },
  ];

  Set<Marker> get _markers => {
    Marker(
      markerId: const MarkerId('destination1'),
      position: const LatLng(-7.9797, 112.6304),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      infoWindow: const InfoWindow(title: 'RM. Ayam Goreng Berkah'),
    ),
    Marker(
      markerId: const MarkerId('destination2'),
      position: const LatLng(-7.9553, 112.6141),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      infoWindow: const InfoWindow(title: 'Warung Makan Sari Rasa'),
    ),
    Marker(
      markerId: const MarkerId('destination3'),
      position: const LatLng(-7.9758, 112.6589),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow: const InfoWindow(title: 'Rumah Makan Padang'),
    ),
  };

  Set<Polyline> get _polylines => {
    const Polyline(
      polylineId: PolylineId('route'),
      points: [
        LatLng(-7.9666, 112.6326),
        LatLng(-7.9797, 112.6304),
        LatLng(-7.9553, 112.6141),
        LatLng(-7.9758, 112.6589),
      ],
      color: AppColors.primaryGreen,
      width: 5,
    ),
  };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Statistics Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Tugas Hari Ini',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _hasTodayTasks
                              ? _pickupLocations.length.toString()
                              : '0',
                          style: AppTextStyles.h1.copyWith(
                            color: AppColors.white,
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 60,
                    width: 1,
                    color: AppColors.white.withOpacity(0.3),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Total Minyak',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '500L',
                          style: AppTextStyles.h1.copyWith(
                            color: AppColors.white,
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Conditional content based on whether there are tasks today
            if (_hasTodayTasks) ...[
              // View Toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Lokasi Penjemputan',
                    style: AppTextStyles.h5.copyWith(
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.map,
                          color: _isMapView
                              ? AppColors.primaryGreen
                              : AppColors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _isMapView = true;
                          });
                        },
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.list,
                          color: !_isMapView
                              ? AppColors.primaryGreen
                              : AppColors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _isMapView = false;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Map or List View
              if (_isMapView)
                Container(
                  height: 300,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.grey.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: GoogleMap(
                      initialCameraPosition: _initialPosition,
                      markers: _markers,
                      polylines: _polylines,
                      onMapCreated: (GoogleMapController controller) {
                        _mapController = controller;
                      },
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _pickupLocations.length,
                  itemBuilder: (context, index) {
                    final location = _pickupLocations[index];
                    return _buildLocationCard(location);
                  },
                ),

              const SizedBox(height: 24),

              // Schedule Pick-up Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/navigation');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text('Jadwal Pick-up', style: AppTextStyles.button),
                ),
              ),
            ] else ...[
              // Empty state when no tasks
              const EmptyTasksWidget(),
            ],

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard(Map<String, dynamic> location) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.restaurant, color: AppColors.primaryGreen),
        ),
        title: Text(
          location['name'],
          style: AppTextStyles.bodyLarge.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.primaryGreen,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(location['address'], style: AppTextStyles.bodySmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.local_gas_station,
                  size: 14,
                  color: AppColors.accentOrange,
                ),
                const SizedBox(width: 4),
                Text(
                  location['volume'],
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.accentOrange,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.location_on, size: 14, color: AppColors.grey),
                const SizedBox(width: 4),
                Text(
                  location['distance'],
                  style: AppTextStyles.caption.copyWith(color: AppColors.grey),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: location['status'] == 'Dijadwalkan'
                        ? AppColors.success.withOpacity(0.1)
                        : AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    location['status'],
                    style: AppTextStyles.caption.copyWith(
                      color: location['status'] == 'Dijadwalkan'
                          ? AppColors.success
                          : AppColors.warning,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Icon(Icons.chevron_right, color: AppColors.primaryGreen),
        onTap: () {
          Navigator.pushNamed(context, '/navigation');
        },
      ),
    );
  }
}
