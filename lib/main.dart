import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'constants/app_colors.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/phone_input_screen.dart';
import 'screens/otp_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/navigation_screen.dart';
import 'screens/pickup_process_screen.dart';
import 'screens/sales_dashboard_screen.dart';
import 'screens/add_supplier_screen_simple.dart';
import 'screens/supplier_list_screen.dart';
import 'screens/role_selection_screen.dart';
import 'screens/mandatory_gps_consent_screen.dart';
import 'providers/supplier_form_provider.dart';
import 'providers/supplier_list_provider.dart';
import 'services/gps_enforcement_service.dart';
import 'services/user_storage.dart';
import 'services/driver_monitoring_service.dart';
import 'services/file_logger_service.dart';

import 'config/app_config.dart';

Future<void> main() async {
  // Wrapping startup in a Zone with a custom print handler captures every
  // print()/debugPrint() call app-wide (debugPrint funnels through the
  // zone's print in debug builds) into the rotating file log, with zero
  // changes needed at existing call sites. Uncaught errors go there too.
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await _configureOrientation();
      await AppConfig.init();
      await FileLoggerService.instance.init();
      runApp(const MyApp());
    },
    (error, stack) {
      FileLoggerService.instance.write('UNCAUGHT ERROR: $error\n$stack');
    },
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        parent.print(zone, line);
        FileLoggerService.instance.write(line);
      },
    ),
  );
}

/// Ponsel memakai portrait agar alur kerja lapangan tidak berubah ketika
/// perangkat terbalik. Layar tablet (shortest side >= 600dp) tetap bebas
/// berotasi untuk memanfaatkan ruang kerja yang lebih luas.
Future<void> _configureOrientation() async {
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  final shortestSide = view.physicalSize.shortestSide / view.devicePixelRatio;

  if (shortestSide < 600) {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    return;
  }

  await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'One Link',
      debugShowCheckedModeBanner: false,
      locale: const Locale('id'),
      supportedLocales: const [Locale('id'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryGreen,
          primary: AppColors.primaryGreen,
          secondary: AppColors.accentOrange,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryGreen,
          primary: AppColors.primaryGreen,
          secondary: AppColors.accentOrange,
          brightness: Brightness.dark,
        ),
        textTheme: ThemeData.dark().textTheme,
        useMaterial3: true,
      ),
      // App masih didesain penuh untuk light mode (warna teks di seluruh
      // screen pakai AppColors hardcoded, bukan theme-aware). Mengikuti
      // ThemeMode.system membuat teks abu-abu/hitam tidak terbaca di atas
      // background gelap. Dikunci ke light sampai ada refactor warna
      // theme-aware menyeluruh.
      themeMode: ThemeMode.light,
      builder: (context, child) {
        return RepaintBoundary(
          key: DriverMonitoringService.repaintBoundaryKey,
          child: child ?? const SizedBox.shrink(),
        );
      },
      // Set initial route to SplashScreen for auto-login check
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/role-selection': (context) => const RoleSelectionScreen(),
        '/login': (context) => const LoginScreen(),
        '/phone-input': (context) => const PhoneInputScreen(),
        '/otp': (context) => const OtpScreen(),
        '/mandatory-gps': (context) => const MandatoryGpsConsentScreen(),
        '/main': (context) => const AppMainRouter(),
        '/dashboard': (context) => const DashboardScreen(),
        '/driver-dashboard': (context) =>
            const DashboardScreen(), // Driver uses same dashboard
        '/sales-dashboard': (context) => const SalesDashboardScreen(),
        '/navigation': (context) => const NavigationScreen(),
        '/pickup-process': (context) => const PickupProcessScreen(),
        '/add-supplier': (context) => ChangeNotifierProvider(
          create: (_) => SupplierFormProvider(),
          child: const AddSupplierScreenSimple(),
        ),
        '/supplier-list': (context) => ChangeNotifierProvider(
          create: (_) => SupplierListProvider(),
          child: const SupplierListScreen(),
        ),
        '/exit': (context) => const AppExitHandler(),
      },
    );
  }
}

// Router to handle main app navigation based on role and GPS consent
class AppMainRouter extends StatelessWidget {
  const AppMainRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _determineMainRoute(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.primaryGreen,
                ),
              ),
            ),
          );
        }

        final route = snapshot.data ?? '/dashboard';

        // Navigate to appropriate screen based on user role
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context).pushReplacementNamed(route);
        });

        return const SizedBox.shrink();
      },
    );
  }

  Future<String> _determineMainRoute() async {
    try {
      final user = await UserStorage.getUser();

      if (user == null) {
        return '/login';
      }

      // Check if GPS consent is given and start enforcement
      final hasGpsConsent = await UserStorage.hasMandatoryGpsConsent();
      if (hasGpsConsent) {
        // Start GPS enforcement service
        GpsEnforcementService.instance.startEnforcement();
        print('GPS enforcement service started');
      }

      // Determine dashboard based on user groups/role
      final groups = user['groups'] as List<dynamic>?;
      if (groups != null && groups.isNotEmpty) {
        // Use RoleManagementService logic (simplified)
        for (var group in groups) {
          final role = group['name'].toString().toLowerCase();

          if (role.contains('cro') ||
              role.contains('roe') ||
              role.contains('ro ') ||
              role.startsWith('ro') ||
              role.endsWith('ro') ||
              role.contains('sales')) {
            return '/sales-dashboard';
          } else if (role.contains('driver') || role.contains('drv')) {
            return '/driver-dashboard';
          }
        }
      }

      return '/dashboard'; // Default dashboard
    } catch (e) {
      return '/login';
    }
  }
}

// Handle app exit when user denies GPS consent
class AppExitHandler extends StatefulWidget {
  const AppExitHandler({super.key});

  @override
  State<AppExitHandler> createState() => _AppExitHandlerState();
}

class _AppExitHandlerState extends State<AppExitHandler> {
  @override
  void initState() {
    super.initState();
    _exitApp();
  }

  void _exitApp() {
    // Close app gracefully
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.exit_to_app, size: 64, color: AppColors.textSecondary),
            SizedBox(height: 16),
            Text(
              'Menutup aplikasi...',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
