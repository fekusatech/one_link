import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

import 'add_supplier_screen_simple.dart';
import '../providers/supplier_form_provider.dart';
import '../widgets/active_visit_warning_banner.dart';
import 'supplier_list_screen.dart';
import '../widgets/permission_gate.dart';
import '../services/role_management_service.dart';
import 'notification_screen.dart';
import 'profile_screen.dart';
import '../services/dashboard_stats_service.dart';
import '../models/dashboard_stats_model.dart';
import '../models/api_response.dart';
import '../services/update_service.dart';
import '../services/user_storage.dart';
import '../services/location_tracking_service.dart';
import '../services/fake_gps_alert_service.dart';
import '../services/impersonation_service.dart';
import 'canvassing/visit_plan_screen.dart';
import 'canvassing/visit_history_screen.dart';
import 'canvassing/scan_prospect_screen.dart';
import 'canvassing/nearby_supplier_screen.dart';
import 'canvassing/tasks_hub_screen.dart';
import 'canvassing/pickup_list_screen.dart';
import 'canvassing/my_statistic_screen.dart';
import 'canvassing/work_order_list_screen.dart';
import 'canvassing/self_assign_screen.dart';
import 'tracking_system_screen.dart';
import '../services/geu/mission_navigation_state.dart';
import '../models/geu/visit_planner_models.dart';
import '../services/geu/visit_planner_service.dart';
import '../services/geu/my_statistic_service.dart';
import '../services/geu/geu_auth_service.dart';
import '../services/geu/reverse_geocoding_service.dart';

class SalesDashboardScreen extends StatefulWidget {
  const SalesDashboardScreen({super.key});

  @override
  State<SalesDashboardScreen> createState() => _SalesDashboardScreenState();
}

class _SalesDashboardScreenState extends State<SalesDashboardScreen> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Sales statistics
  DashboardStats? _dashboardStats;
  String _userName = 'CRO';
  bool _isLoading = true;
  String? _errorMessage;
  bool _canSwitchDashboard = false;
  TodaysMission? _todaysMission;
  AssignmentStats? _myStats;
  GeuUser? _geuUser;
  int? _weatherCode;
  double? _temperatureC;
  int? _relativeHumidity;
  double? _windSpeedKmh;
  String _locationLabel = 'Mencari lokasi…';

  @override
  void initState() {
    super.initState();
    _loadSalesData();
    _loadUserName();
    _loadMissionSummary();
    _loadMyStatistics();
    _loadPermissions();
    _loadSwitchDashboardPermission();
    _loadWeather();

    // CRO/RO can land here directly on app open (not just via Driver
    // dashboard), so the update/maintenance check needs to fire from here
    // too — UpdateService's own _hasCheckedOnThisLoad flag prevents a
    // duplicate check if the admin dashboard-switch button is used.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService.instance.startMonitoring(context);
      _startLocationTracking();
      FakeGpsAlertService.instance.start(context);
    });
  }

  /// Sales/CRO follows the same consent + Working Mode rules as Driver.
  /// This is needed on every dashboard entry, including an auto-login after
  /// the app process was restarted.
  Future<void> _startLocationTracking() async {
    final service = LocationTrackingService.instance;
    if (!await service.hasPermissions()) {
      if (!mounted) return;
      final granted = await service.requestPermissions(context);
      if (!granted) {
        debugPrint('⚠️ Sales/CRO location permission was not granted');
        return;
      }
      await UserStorage.setLocationTrackingConsent(true);
    } else if (!await UserStorage.hasLocationTrackingConsent()) {
      await UserStorage.setLocationTrackingConsent(true);
    }

    if (!service.isTracking) {
      final started = await service.startTrackingWithoutPermissionCheck(
        ignoreWorkingMode: true,
      );
      if (started) {
        debugPrint('📍 Auto-started location tracking for Sales/CRO');
      } else {
        debugPrint('⚠️ Sales/CRO location tracking could not be started');
      }
    }
    await _loadWeather();
  }

  Future<void> _loadPermissions() async {
    final user = await GeuAuthService.getCachedUser();
    if (mounted) setState(() => _geuUser = user);
  }

  Future<void> _loadSwitchDashboardPermission() async {
    var allowed = RoleManagementService.isAdmin();
    if (!allowed) {
      final user = await UserStorage.getUser();
      final groups = user?['groups'] as List<dynamic>? ?? const [];
      final roles = user?['roles'] as List<dynamic>? ?? const [];
      final identity = [
        ...groups,
        ...roles,
      ].map((role) => role.toString().toLowerCase()).join(' ');
      allowed =
          identity.contains('admin') ||
          identity.contains('developer') ||
          identity.contains('super');
    }
    if (!allowed) allowed = await ImpersonationService.canImpersonate();
    if (mounted) setState(() => _canSwitchDashboard = allowed);
  }

  bool _has(String slug) => _geuUser?.hasPermission(slug) ?? false;

  Future<void> _loadWeather() async {
    try {
      Position? location = await Geolocator.getLastKnownPosition();
      location ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 8),
        ),
      );
      final addressFuture = ReverseGeocodingService.resolveLocality(
        location.latitude,
        location.longitude,
      );
      final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': location.latitude.toStringAsFixed(2),
        'longitude': location.longitude.toStringAsFixed(2),
        'current':
            'temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m',
        'timezone': 'auto',
      });
      final responseFuture = http.get(uri).timeout(const Duration(seconds: 5));
      final address = await addressFuture;
      if (mounted) {
        setState(() => _locationLabel = address);
      }
      final response = await responseFuture;
      if (response.statusCode != 200 || !mounted) return;
      final current =
          (jsonDecode(response.body) as Map<String, dynamic>)['current']
              as Map<String, dynamic>?;
      final code = current?['weather_code'] as int?;
      if (code != null) {
        setState(() {
          _weatherCode = code;
          _temperatureC = (current?['temperature_2m'] as num?)?.toDouble();
          _relativeHumidity = (current?['relative_humidity_2m'] as num?)
              ?.toInt();
          _windSpeedKmh = (current?['wind_speed_10m'] as num?)?.toDouble();
        });
      }
    } catch (_) {
      // Weather is decorative; keep the branded neutral background offline.
      if (mounted && _locationLabel == 'Mencari lokasi…') {
        setState(() => _locationLabel = 'Lokasi belum tersedia');
      }
    }
  }

  _WeatherMood get _weatherMood {
    final code = _weatherCode;
    if (code == null) return _WeatherMood.clear;
    if (code == 0) return _WeatherMood.clear;
    if (code <= 3) return _WeatherMood.cloudy;
    if (code <= 48) return _WeatherMood.fog;
    if (code <= 67 || (code >= 80 && code <= 82)) return _WeatherMood.rain;
    if (code >= 95) return _WeatherMood.storm;
    return _WeatherMood.cloudy;
  }

  Future<void> _loadUserName() async {
    final name = await UserStorage.getUserName();
    if (mounted && name.trim().isNotEmpty) {
      setState(() => _userName = name.trim());
    }
  }

  Future<void> _loadMissionSummary() async {
    try {
      final mission = await VisitPlannerService.getTodaysMission();
      if (mounted) setState(() => _todaysMission = mission);
    } catch (_) {
      // The dashboard card gracefully keeps its empty state until the user
      // opens Visit Plan, which has its own cached/offline handling.
    }
  }

  Future<void> _loadMyStatistics() async {
    try {
      final now = DateTime.now();
      final stats = await MyStatisticService.assignment(
        now.subtract(const Duration(days: 6)),
        now,
      );
      if (mounted) setState(() => _myStats = stats);
    } catch (_) {
      // The dashboard omits its optional chart when the reporting API has no
      // usable data, rather than displaying a misleading empty visualization.
    }
  }

  Future<void> _loadSalesData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final ApiResponse<DashboardStats> response =
          await DashboardStatsService.getDashboardStats();

      setState(() {
        _isLoading = false;
        if (response.status && response.data != null) {
          _dashboardStats = response.data;
        } else {
          _errorMessage = response.message;
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading dashboard data: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // CRO/RO share this dashboard, but Visit Planner (mission map,
    // check-in/out, and kunjungan history) is only meaningful for users who
    // hold crm-read-visit-planner — mirrors the web sidebar's gating of the
    // "Visit Plan" menu item, and keeps the tab/screens list positionally in
    // sync with SharedBottomNavbar's own showVisitPlan-driven item list.
    final hasVisitPlanner = _has('crm-read-visit-planner');
    final showTasksTab = _has('crm-read-task') || _has('crm-read-self-assign');
    final List<Widget> screens = [
      _buildMainDashboard(),
      if (hasVisitPlanner)
        const PermissionGate(
          slug: 'crm-read-visit-planner',
          child: VisitPlanScreen(),
        ),
      if (showTasksTab)
        const PermissionGate(slug: 'crm-read-task', child: TasksHubScreen()),
      if (hasVisitPlanner)
        const PermissionGate(
          slug: 'crm-read-visit-planner',
          child: VisitHistoryScreen(),
        ),
      const ProfileScreen(role: ProfileRole.cro),
    ];

    final lightStatusSurface = _weatherMood.background.computeLuminance() > .5;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: lightStatusSurface
            ? Brightness.dark
            : Brightness.light,
        statusBarBrightness: lightStatusSurface
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _weatherMood.background,
        drawer: _buildDrawer(),
        body: Stack(
          children: [
            Positioned.fill(child: _WeatherBackdrop(mood: _weatherMood)),
            SafeArea(
              child: _selectedIndex == 0
                  ? _buildMainDashboard()
                  : screens[_selectedIndex],
            ),
          ],
        ),
        bottomNavigationBar: _SalesBottomBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          showVisitPlan: hasVisitPlanner,
          showTasks: showTasksTab,
          showHistory: hasVisitPlanner,
          onNotifications: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationScreen()),
          ),
        ),
      ),
    );
  }

  /// Reachable from the compact menu button beside the greeting. The drawer
  /// holds secondary CRO/RO navigation without crowding the bottom nav.
  Widget _buildDrawer() {
    final items = [
      ..._menuItems(),
      _CroMenuItem(
        title: 'Daftar Work Order',
        subtitle: 'Riwayat & status semua WO',
        icon: Icons.assignment_outlined,
        color: AppColors.primaryGreen,
        permission: 'crm-read-work-order',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const PermissionGate(
              slug: 'crm-read-work-order',
              child: WorkOrderListScreen(),
            ),
          ),
        ),
      ),
    ];
    final visible = items
        .where((item) => item.permission == null || _has(item.permission!))
        .toList();

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    color: AppColors.primaryGreen,
                    child: Text(
                      'Menu',
                      style: AppTextStyles.h4.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  for (final item in visible)
                    ListTile(
                      leading: Icon(item.icon, color: item.color),
                      title: Text(item.title),
                      subtitle: Text(
                        item.subtitle,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        item.onTap();
                      },
                    ),
                ],
              ),
            ),
            if (_canSwitchDashboard) ...[
              const Divider(height: 1),
              ListTile(
                minVerticalPadding: 12,
                leading: const Icon(
                  Icons.swap_horiz_rounded,
                  color: AppColors.primaryGreen,
                ),
                title: const Text('Pindah ke Driver'),
                subtitle: Text(
                  'Ganti workspace',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                onTap: () => Navigator.pushReplacementNamed(
                  context,
                  '/driver-dashboard',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMainDashboard() {
    final hasVisitPlanner = _has('crm-read-visit-planner');
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 118),
      children: [
        _buildCroGreeting(),
        const SizedBox(height: 16),
        const ActiveVisitWarningBanner(),
        if (hasVisitPlanner) ...[
          const SizedBox(height: 16),
          _buildMissionSummary(),
        ],
        const SizedBox(height: 28),
        _buildStatisticsSection(),
        const SizedBox(height: 28),
        _buildQuickActions(),
        const SizedBox(height: 28),
        _buildMyStatistics(),
      ],
    );
  }

  Widget _buildCroGreeting() {
    final weatherDetails = [
      if (_temperatureC != null) '${_temperatureC!.round()}°C',
      if (_relativeHumidity != null) 'Kelembapan $_relativeHumidity%',
      if (_windSpeedKmh != null) 'Angin ${_windSpeedKmh!.round()} km/j',
    ].join('  ·  ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              _greeting(),
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          _userName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.h3.copyWith(
            color: AppColors.primaryGreen,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(
              Icons.location_on_outlined,
              size: 17,
              color: AppColors.primaryGreen,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                _locationLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Icon(_weatherMood.icon, size: 17, color: AppColors.primaryGreen),
            const SizedBox(width: 4),
            Text(
              _weatherCode == null ? 'Cuaca—' : _weatherMood.label,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        if (weatherDetails.isNotEmpty) ...[
          const SizedBox(height: 3),
          Padding(
            padding: const EdgeInsets.only(left: 21),
            child: Text(
              weatherDetails,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMissionSummary() {
    return ValueListenableBuilder<MissionNavigationState>(
      valueListenable: MissionNavigationStateService.current,
      builder: (context, mission, _) {
        final plannedItems = _todaysMission?.items ?? const <MissionItem>[];
        final total = mission.isActive
            ? mission.totalVisits
            : plannedItems.length;
        final completed = mission.isActive
            ? mission.completedVisits
            : plannedItems
                  .where((item) => item.status.toUpperCase() == 'VISITED')
                  .length;
        final destination = mission.destination?.trim();
        return Material(
          color: AppColors.primaryGreen,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => setState(() => _selectedIndex = 1),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kunjungan hari ini',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    total > 0
                        ? '$completed dari $total selesai'
                        : 'Belum ada kunjungan',
                    style: AppTextStyles.h3.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (total > 0) ...[
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: (completed / total).clamp(0.0, 1.0),
                        minHeight: 4,
                        backgroundColor: AppColors.white.withValues(alpha: .5),
                        valueColor: const AlwaysStoppedAnimation(
                          AppColors.accentOrange,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Text(
                    destination != null && destination.isNotEmpty
                        ? 'TUJUAN BERIKUTNYA'
                        : 'RENCANA KUNJUNGAN',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    destination != null && destination.isNotEmpty
                        ? destination
                        : 'Buka Visit untuk melihat rute hari ini',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.h5.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 48),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.accentOrange,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      mission.isActive
                          ? 'Lanjutkan kunjungan'
                          : 'Buka Visit Plan',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat pagi 👋';
    if (hour < 15) return 'Selamat siang 👋';
    if (hour < 19) return 'Selamat sore 👋';
    return 'Selamat malam 👋';
  }

  Widget _buildStatisticsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Ringkasan supplier',
                style: AppTextStyles.h5.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton(
              onPressed: _loadSalesData,
              child: const Text('Perbarui'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            ),
          )
        else if (_errorMessage != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              border: Border.all(color: AppColors.borderColor),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gagal memuat statistik',
                  style: AppTextStyles.h6.copyWith(
                    color: AppColors.primaryGreen,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _errorMessage!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                TextButton(
                  onPressed: _loadSalesData,
                  child: const Text('Coba lagi'),
                ),
              ],
            ),
          )
        else
          Row(
            children: [
              _supplierMetric(
                '${_dashboardStats?.totalSuppliers ?? 0}',
                'Terdaftar',
              ),
              _supplierMetric(
                '${_dashboardStats?.activeSuppliers ?? 0}',
                'Aktif',
              ),
              _supplierMetric(
                '${_dashboardStats?.newThisMonth ?? 0}',
                'Baru bulan ini',
              ),
            ],
          ),
      ],
    );
  }

  Widget _supplierMetric(String value, String label) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: AppTextStyles.h3.copyWith(
            color: AppColors.primaryGreen,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 2,
          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
        ),
      ],
    ),
  );

  Widget _buildMyStatistics() {
    final stats = _myStats;
    if (stats == null) return const SizedBox.shrink();
    final trend = stats.trend
        .map((item) => _number(item['completed']) + _number(item['pending']))
        .toList();
    final hasChart = trend.isNotEmpty && trend.any((value) => value > 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Statistik saya',
          style: AppTextStyles.h6.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  _miniStat('Total', stats.total, AppColors.primaryGreen),
                  _miniStat('Selesai', stats.completed, AppColors.success),
                  _miniStat('Proses', stats.inProgress, AppColors.info),
                  _miniStat('Pending', stats.pending, AppColors.accentOrange),
                ],
              ),
              if (hasChart) ...[
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Aktivitas 7 hari terakhir',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 112,
                  child: _activityChart(
                    trend,
                    stats.trend.map((item) => '${item['date'] ?? ''}').toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _miniStat(String label, int value, Color color) => Expanded(
    child: Column(
      children: [
        Text(
          '$value',
          style: AppTextStyles.h6.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
        ),
      ],
    ),
  );

  Widget _activityChart(List<int> values, List<String> dates) {
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(values.take(7).length, (index) {
        final value = values[index];
        final fraction = value / maxValue;
        final date = index < dates.length ? dates[index] : '';
        return Expanded(
          child: Tooltip(
            message: '${_activityDateLabel(date)}\n$value aktivitas',
            preferBelow: false,
            triggerMode: TooltipTriggerMode.tap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {},
                        child: Container(
                          height: 10 + (62 * fraction),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen.withValues(
                              alpha: .78,
                            ),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _activityDateLabel(date),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 9,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  String _activityDateLabel(String iso) {
    final date = DateTime.tryParse(iso);
    if (date == null) return '-';
    const weekdays = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    return '${weekdays[date.weekday - 1]}\n${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
  }

  int _number(dynamic value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

  /// Full CRO/RO menu, mirroring the web sidebar's permission-slug gating
  /// (crm-react's filterNav()): an item with no `permission` is always
  /// shown once logged in; otherwise it only shows if `_geuUser.permissions`
  /// includes that slug. This is what makes RO (which holds
  /// crm-read-visit-planner) see Mission/Visit Plan while CRO (which
  /// doesn't) does not.
  // Tugas Saya & Self Assign live in the "Tugas" bottom-nav tab
  // (TasksHubScreen) instead of here, so they aren't duplicated as both a
  // tab and a menu card.
  List<_CroMenuItem> _menuItems() => [
    _CroMenuItem(
      title: 'Mission hari ini',
      subtitle: 'Rute & check-in kunjungan',
      icon: Icons.map_outlined,
      color: Colors.purple,
      permission: 'crm-read-visit-planner',
      onTap: () => setState(() => _selectedIndex = 1),
    ),
    _CroMenuItem(
      title: 'Tugas Saya',
      subtitle: 'Daftar tugas & follow-up harian',
      icon: Icons.assignment_outlined,
      color: Colors.indigo,
      permission: 'crm-read-task',
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const PermissionGate(
            slug: 'crm-read-task',
            child: TasksHubScreen(),
          ),
        ),
      ),
    ),
    _CroMenuItem(
      title: 'Self Assign',
      subtitle: 'Klaim supplier & lead (CRO / RO)',
      icon: Icons.handshake_outlined,
      color: Colors.teal,
      permission: 'crm-read-self-assign',
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const PermissionGate(
            slug: 'crm-read-self-assign',
            child: SelfAssignScreen(),
          ),
        ),
      ),
    ),
    _CroMenuItem(
      title: 'Pickup',
      subtitle: 'Daftar dan status pengambilan',
      icon: Icons.local_shipping_outlined,
      color: AppColors.accentOrange,
      permission: 'crm-read-pickup',
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const PermissionGate(
            slug: 'crm-read-pickup',
            child: PickupListScreen(),
          ),
        ),
      ),
    ),
    _CroMenuItem(
      title: 'Daftar Work Order',
      subtitle: 'Kelola & lihat status Work Order',
      icon: Icons.description_outlined,
      color: AppColors.primaryGreen,
      permission: 'crm-read-work-order',
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const PermissionGate(
            slug: 'crm-read-work-order',
            child: WorkOrderListScreen(),
          ),
        ),
      ),
    ),
    _CroMenuItem(
      title: 'Daftar Supplier',
      subtitle: 'Cari & perbarui data supplier',
      icon: Icons.edit_location,
      color: AppColors.accentOrange,
      permission: 'crm-read-supplier',
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const PermissionGate(
            slug: 'crm-read-supplier',
            child: SupplierListScreen(),
          ),
        ),
      ),
    ),
    _CroMenuItem(
      title: 'Outlet Baru',
      subtitle: 'Daftarkan outlet/supplier baru',
      icon: Icons.add_business_outlined,
      color: AppColors.primaryGreen,
      permission: 'crm-create-supplier',
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PermissionGate(
            slug: 'crm-create-supplier',
            child: ChangeNotifierProvider(
              create: (_) => SupplierFormProvider(),
              child: const AddSupplierScreenSimple(),
            ),
          ),
        ),
      ),
    ),
    _CroMenuItem(
      title: 'Supplier Nearby',
      subtitle: 'Cari supplier berdasarkan lokasi/kota',
      icon: Icons.near_me_outlined,
      color: AppColors.info,
      permission: 'crm-read-visit-planner',
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const PermissionGate(
            slug: 'crm-read-visit-planner',
            child: NearbySupplierScreen(),
          ),
        ),
      ),
    ),
    _CroMenuItem(
      title: 'Scan Prospek',
      subtitle: 'Riset calon supplier di sekitar Anda',
      icon: Icons.radar_outlined,
      color: AppColors.info,
      permission: 'crm-read-visit-planner',
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const PermissionGate(
            slug: 'crm-read-visit-planner',
            child: ScanProspectScreen(),
          ),
        ),
      ),
    ),
    _CroMenuItem(
      title: 'Statistik Saya',
      subtitle: 'KPI assignment dan tren harian',
      icon: Icons.bar_chart_outlined,
      color: Colors.blueGrey,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MyStatisticScreen()),
      ),
    ),
    _CroMenuItem(
      title: 'Tracking System',
      subtitle: 'Pantau PO, WO, dan Surat Jalan',
      icon: Icons.timeline_rounded,
      color: AppColors.primaryGreen,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TrackingSystemScreen()),
      ),
    ),
  ];

  Widget _buildQuickActions() {
    final visible = _menuItems()
        .where((item) => item.permission == null || _has(item.permission!))
        .toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Akses kerja',
          style: AppTextStyles.h5.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        for (final item in visible) ...[
          Material(
            color: AppColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: AppColors.borderColor),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: item.onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 64),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Icon(item.icon, size: 22, color: AppColors.primaryGreen),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              item.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.primaryGreen,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

enum _WeatherMood { clear, cloudy, fog, rain, storm }

extension on _WeatherMood {
  Color get background => switch (this) {
    _WeatherMood.clear => AppColors.background,
    _WeatherMood.cloudy => const Color(0xFFE8EFED),
    _WeatherMood.fog => const Color(0xFFEDF0F0),
    _WeatherMood.rain => const Color(0xFFD9E6EC),
    _WeatherMood.storm => const Color(0xFFCFDCE3),
  };

  IconData get icon => switch (this) {
    _WeatherMood.clear => Icons.wb_sunny_outlined,
    _WeatherMood.cloudy => Icons.cloud_outlined,
    _WeatherMood.fog => Icons.foggy,
    _WeatherMood.rain => Icons.water_drop_outlined,
    _WeatherMood.storm => Icons.thunderstorm_outlined,
  };

  String get label => switch (this) {
    _WeatherMood.clear => 'Cerah',
    _WeatherMood.cloudy => 'Berawan',
    _WeatherMood.fog => 'Berkabut',
    _WeatherMood.rain => 'Hujan',
    _WeatherMood.storm => 'Hujan lebat',
  };
}

class _WeatherBackdrop extends StatelessWidget {
  const _WeatherBackdrop({required this.mood});
  final _WeatherMood mood;

  @override
  Widget build(BuildContext context) {
    final isWet = mood == _WeatherMood.rain || mood == _WeatherMood.storm;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: mood.background,
        gradient: mood == _WeatherMood.clear
            ? null
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [mood.background, AppColors.background],
              ),
      ),
      child: Stack(
        children: [
          if (mood != _WeatherMood.clear)
            Positioned(
              top: -30,
              right: -24,
              child: Icon(
                isWet ? Icons.cloud : Icons.cloud_outlined,
                size: 190,
                color: const Color(0xFF879A9B).withValues(alpha: .08),
              ),
            ),
          if (isWet)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 270,
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _RainPainter(mood == _WeatherMood.storm),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RainPainter extends CustomPainter {
  const _RainPainter(this.heavy);
  final bool heavy;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF587987).withValues(alpha: heavy ? .20 : .13)
      ..strokeWidth = heavy ? 1.7 : 1.4
      ..strokeCap = StrokeCap.round;
    final step = heavy ? 28.0 : 40.0;
    for (double x = 8; x < size.width; x += step) {
      for (double y = 30 + (x % 61); y < size.height; y += step * 1.7) {
        canvas.drawLine(Offset(x, y), Offset(x - 4, y + 12), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RainPainter oldDelegate) =>
      heavy != oldDelegate.heavy;
}

class _CroMenuItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String? permission;
  final VoidCallback onTap;

  const _CroMenuItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.permission,
    required this.onTap,
  });
}

class _SalesBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool showVisitPlan;
  final bool showTasks;
  final bool showHistory;
  final VoidCallback onNotifications;

  const _SalesBottomBar({
    required this.currentIndex,
    required this.onTap,
    required this.showVisitPlan,
    required this.showTasks,
    required this.showHistory,
    required this.onNotifications,
  });

  @override
  Widget build(BuildContext context) {
    final items = <({IconData icon, IconData activeIcon, String label})>[
      (
        icon: Icons.grid_view_rounded,
        activeIcon: Icons.grid_view_rounded,
        label: 'Beranda',
      ),
      if (showVisitPlan)
        (
          icon: Icons.map_outlined,
          activeIcon: Icons.map_rounded,
          label: 'Visit',
        ),
      if (showTasks)
        (
          icon: Icons.checklist_outlined,
          activeIcon: Icons.checklist_rounded,
          label: 'Tugas',
        ),
      if (showHistory)
        (
          icon: Icons.history_outlined,
          activeIcon: Icons.history_rounded,
          label: 'Riwayat',
        ),
      (
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        label: 'Profil',
      ),
      (
        icon: Icons.notifications_none_rounded,
        activeIcon: Icons.notifications_rounded,
        label: 'Notifikasi',
      ),
    ];

    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.borderColor)),
        ),
        child: Row(
          children: List.generate(items.length, (index) {
            final item = items[index];
            final isNotifications = item.label == 'Notifikasi';
            final selected = !isNotifications && index == currentIndex;
            return Expanded(
              child: Semantics(
                button: true,
                selected: selected,
                label: 'Navigasi ${item.label}',
                child: InkWell(
                  onTap: isNotifications ? onNotifications : () => onTap(index),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 64),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Container(
                          height: 3,
                          width: 32,
                          color: selected
                              ? AppColors.accentOrange
                              : Colors.transparent,
                        ),
                        const SizedBox(height: 8),
                        Icon(
                          selected ? item.activeIcon : item.icon,
                          size: 22,
                          color: selected
                              ? AppColors.primaryGreen
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isNotifications ? 'Notif' : item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 10,
                            fontWeight: selected
                                ? FontWeight.w800
                                : FontWeight.w500,
                            color: selected
                                ? AppColors.primaryGreen
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
