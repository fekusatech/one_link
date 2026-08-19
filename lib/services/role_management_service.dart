import '../services/auth_debug_service.dart';
import '../services/persistent_auth_service.dart';

/// Enum untuk tipe role yang tersedia
enum RoleType {
  driver, // Auto route ke driver screen
  sales, // Auto route ke sales screen (CRO/RO)
  admin, // Show role selection (superadmin/developer)
  denied, // Access denied
}

/// Service untuk mengelola role-based routing otomatis
class RoleManagementService {
  /// Data role yang ditemukan pada user
  static List<String> _userRoles = [];
  static String _userName = '';

  /// Analisa role dari auth data dan tentukan routing
  static Future<Map<String, dynamic>> analyzeUserRole() async {
    try {
      // Ambil data dari auth.json atau persistent storage
      Map<String, dynamic>? authData = await AuthDebugService.getAuthResponse();

      // Fallback ke persistent storage jika auth.json tidak ada
      if (authData == null) {
        final userData = await PersistentAuthService.instance.getUserData();
        if (userData['userId'] != null) {
          // Simulate basic user data
          authData = {
            'data': {
              'user': {
                'id': userData['userId'],
                'name': userData['userName'],
                'groups': [], // Empty groups, akan di-deny
              },
            },
          };
        }
      }

      if (authData == null) {
        return {
          'success': false,
          'message': 'No user authentication data found',
          'roleType': RoleType.denied,
        };
      }

      // Extract user data
      final userData = authData['data']?['user'];
      if (userData == null) {
        return {
          'success': false,
          'message': 'Invalid user data structure',
          'roleType': RoleType.denied,
        };
      }

      _userName = userData['name'] ?? 'User';
      final groups = userData['groups'] as List<dynamic>? ?? [];

      // Extract role names
      _userRoles = groups
          .map((group) => group['name']?.toString().toLowerCase() ?? '')
          .where((role) => role.isNotEmpty)
          .toList();

      print('🔍 User Roles Analysis:');
      print('👤 User: $_userName');
      print('🏷️  Roles: $_userRoles');

      // Tentukan role type berdasarkan prioritas
      final roleType = _determineRoleType(_userRoles);

      return {
        'success': true,
        'roleType': roleType,
        'userName': _userName,
        'userRoles': _userRoles,
        'message': _getRoleMessage(roleType),
        'autoRoute': _shouldAutoRoute(roleType),
      };
    } catch (e) {
      print('❌ Error analyzing user role: $e');
      return {
        'success': false,
        'message': 'Error analyzing user roles: $e',
        'roleType': RoleType.denied,
      };
    }
  }

  /// Tentukan role type berdasarkan prioritas
  static RoleType _determineRoleType(List<String> roles) {
    // 1. Priority: Driver - jika ada kata "driver" atau "drv"
    for (final role in roles) {
      if (role.contains('driver') || role.contains('drv')) {
        print('✅ Found driver role: $role');
        return RoleType.driver;
      }
    }

    // 2. Priority: Sales - jika ada kata "cro", "roe" atau "ro"
    for (final role in roles) {
      if (role.contains('cro') ||
          role.contains('roe') ||
          role.contains('ro ') ||
          role.startsWith('ro') ||
          role.endsWith('ro') ||
          role.contains('sales')) {
        print('✅ Found sales role: $role');
        return RoleType.sales;
      }
    }

    // 3. Priority: Admin - jika ada "superadmin" atau "developer"
    for (final role in roles) {
      if (role.contains('superadmin') ||
          role.contains('developer') ||
          role.contains('admin')) {
        print('✅ Found admin role: $role');
        return RoleType.admin;
      }
    }

    // 4. Default: Denied jika tidak ada role yang sesuai
    print('❌ No matching role found. Available roles: $roles');
    return RoleType.denied;
  }

  /// Pesan berdasarkan role type
  static String _getRoleMessage(RoleType roleType) {
    switch (roleType) {
      case RoleType.driver:
        return 'Driver role detected. Redirecting to driver dashboard...';
      case RoleType.sales:
        return 'Sales role (CRO/RO) detected. Redirecting to sales dashboard...';
      case RoleType.admin:
        return 'Admin privileges detected. Please select your role.';
      case RoleType.denied:
        return 'Access denied. You do not have permission to access this application.';
    }
  }

  /// Apakah harus auto-route (tidak tampilkan role selection)
  static bool _shouldAutoRoute(RoleType roleType) {
    return roleType == RoleType.driver || roleType == RoleType.sales;
  }

  /// Get route name berdasarkan role type
  static String? getRouteForRole(RoleType roleType) {
    switch (roleType) {
      case RoleType.driver:
        return '/driver-dashboard'; // Route untuk driver
      case RoleType.sales:
        return '/sales-dashboard'; // Route untuk sales (CRO/RO)
      case RoleType.admin:
        return null; // Tetap di role selection
      case RoleType.denied:
        return '/access-denied'; // Route untuk access denied
    }
  }

  /// Check apakah user punya permission untuk role tertentu
  static bool hasRolePermission(String requiredRole) {
    return _userRoles.any((role) => role.contains(requiredRole.toLowerCase()));
  }

  /// Check apakah user adalah admin yang bisa switch role
  static bool isAdmin() {
    return _userRoles.any(
      (role) =>
          role.contains('admin') ||
          role.contains('developer') ||
          role.contains('superadmin'),
    );
  }

  /// Get user name
  static String getUserName() => _userName;

  /// Get user roles
  static List<String> getUserRoles() => _userRoles;

  /// Detailed role analysis for debugging
  static Map<String, dynamic> getDetailedRoleAnalysis() {
    return {
      'userName': _userName,
      'userRoles': _userRoles,
      'hasDriver': _userRoles.any((r) => r.contains('driver')),
      'hasSales': _userRoles.any((r) => r.contains('cro') || r.contains('ro')),
      'hasAdmin': _userRoles.any(
        (r) => r.contains('admin') || r.contains('developer'),
      ),
      'totalRoles': _userRoles.length,
    };
  }

  /// Method untuk testing role detection
  static void testRoleDetection(List<String> testRoles) {
    print('\n🧪 TESTING ROLE DETECTION');
    print('=' * 40);
    print('Test roles: $testRoles');

    final roleType = _determineRoleType(testRoles);
    print('Result: $roleType');
    print('Message: ${_getRoleMessage(roleType)}');
    print('Auto route: ${_shouldAutoRoute(roleType)}');
    print('Route: ${getRouteForRole(roleType)}');
    print('=' * 40);
  }
}
