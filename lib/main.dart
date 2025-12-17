import 'package:flutter/material.dart';
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
import 'providers/supplier_form_provider.dart';
import 'providers/supplier_list_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'One Link',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryGreen,
          primary: AppColors.primaryGreen,
          secondary: AppColors.accentOrange,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
      ),
      // Set initial route to SplashScreen for auto-login check
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/role-selection': (context) => const RoleSelectionScreen(),
        '/login': (context) => const LoginScreen(),
        '/phone-input': (context) => const PhoneInputScreen(),
        '/otp': (context) => const OtpScreen(),
        '/dashboard': (context) => const DashboardScreen(),
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
      },
    );
  }
}
