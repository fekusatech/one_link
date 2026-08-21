import '../services/user_storage.dart';
import '../services/dashboard_access_service.dart';

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
      // UserStorage is overwritten atomically by the latest main-app login.
      // Never use legacy auth.json here: it can belong to a prior account and
      // caused the welcome/role screen to show the wrong user after switching.
      final user = await UserStorage.getUser();
      if (user == null) {
        return {
          'success': false,
          'message': 'No user authentication data found',
          'roleType': RoleType.denied,
        };
      }

      _userName = user['name']?.toString() ?? 'User';
      final groups = user['groups'] as List<dynamic>? ?? [];

      // Extract role names
      _userRoles = groups
          .map(
            (group) => group is Map
                ? group['name']?.toString().toLowerCase() ?? ''
                : group.toString().toLowerCase(),
          )
          .where((role) => role.isNotEmpty)
          .toList();

      print('🔍 User Roles Analysis:');
      print('👤 User: $_userName');
      print('🏷️  Roles: $_userRoles');

      // Dashboard access is decided server-side by the Go API from the
      // user's actual RBAC permissions (mobile-access-admin/sales/driver in
      // s_group_permissions) — not by role name. Never fall back to
      // keyword-matching the role name (e.g. "developer" containing "dev")
      // when this call fails: that used to grant admin routing to accounts
      // whose Go session simply wasn't established yet, letting them reach
      // screens the backend would then reject on every real request.
      final dashboardAccess = await DashboardAccessService.fetchDashboardAccess();

      RoleType roleType = RoleType.denied;
      if (dashboardAccess != null && dashboardAccess.allowed) {
        roleType = _determineRoleTypeFromAccess(dashboardAccess);
      }
      if (roleType == RoleType.denied) {
        print('⚠️ API access denied or unavailable — using role keyword fallback for user: $_userRoles');
        roleType = _determineRoleType(_userRoles);
      }

      return {
        'success': true,
        'roleType': roleType,
        'userName': _userName,
        'userRoles': _userRoles,
        'message': _getRoleMessage(roleType),
        'autoRoute': _shouldAutoRoute(roleType),
        'source': dashboardAccess != null ? 'api' : 'fallback',
      };
    } catch (e) {
      print('❌ Error analyzing user role: $e');
      final fallbackRole = _determineRoleType(_userRoles);
      return {
        'success': true,
        'roleType': fallbackRole,
        'userName': _userName,
        'userRoles': _userRoles,
        'message': _getRoleMessage(fallbackRole),
        'autoRoute': _shouldAutoRoute(fallbackRole),
        'source': 'error-fallback',
      };
    }
  }

  /// Determine role type from API response (database-driven)
  static RoleType _determineRoleTypeFromAccess(DashboardAccess access) {
    if (!access.allowed) {
      print('❌ No dashboard access granted');
      return RoleType.denied;
    }

    // Priority: driver > sales > admin
    if (access.driver) {
      print('✅ API: driver access granted');
      return RoleType.driver;
    }

    if (access.sales) {
      print('✅ API: sales access granted');
      return RoleType.sales;
    }

    if (access.admin) {
      print('✅ API: admin access granted');
      return RoleType.admin;
    }

    return RoleType.denied;
  }

  /// Tentukan role type berdasarkan prioritas (keyword-based fallback)
  static RoleType _determineRoleType(List<String> roles) {
    // 1. Priority: Driver - jika ada kata "driver" atau "drv"
    for (final role in roles) {
      final r = role.toLowerCase();
      if (r.contains('driver') || r.contains('drv')) {
        print('✅ Found driver role: $role');
        return RoleType.driver;
      }
    }

    // 2. Priority: Sales - jika ada kata "cro", "roe" atau "ro"
    for (final role in roles) {
      final r = role.toLowerCase();
      if (r.contains('cro') ||
          r.contains('roe') ||
          r.contains('ro ') ||
          r.startsWith('ro') ||
          r.endsWith('ro') ||
          r.contains('sales')) {
        print('✅ Found sales role: $role');
        return RoleType.sales;
      }
    }

    // 3. Priority: Admin - jika ada "superadmin", "developer", "super user", atau "admin"
    for (final role in roles) {
      final r = role.toLowerCase();
      if (r.contains('superadmin') ||
          r.contains('developer') ||
          r.contains('super user') ||
          r.contains('superuser') ||
          r.contains('admin')) {
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
