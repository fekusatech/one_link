import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../services/auth_debug_service.dart';

/// Analyzer untuk file auth.json dengan laporan detail
class AuthJsonAnalyzer {
  static Future<void> analyzeAuthFile() async {
    print('\n🔍 =======================================================');
    print('🔍                 AUTH.JSON ANALYSIS');
    print('🔍 =======================================================\n');

    final fileInfo = await AuthDebugService.getAuthFileInfo();
    final authResponse = await AuthDebugService.getAuthResponse();

    // File Status Analysis
    await _analyzeFileStatus(fileInfo);

    if (authResponse != null) {
      // Structure Analysis
      await _analyzeResponseStructure(authResponse);

      // Security Analysis
      await _analyzeSecurityData(authResponse);

      // User Data Analysis
      await _analyzeUserData(authResponse);

      // Session Data Analysis
      await _analyzeSessionData(authResponse);

      // Timestamp Analysis
      await _analyzeTimestamps(authResponse);
    }

    print('\n🔍 ======================= END =========================\n');
  }

  static Future<void> _analyzeFileStatus(Map<String, dynamic>? fileInfo) async {
    print('📄 FILE STATUS ANALYSIS:');
    print('-' * 40);

    if (fileInfo != null) {
      print('✅ File exists: ${fileInfo['exists']}');
      if (fileInfo['exists']) {
        print('📍 Path: ${fileInfo['path']}');
        print('📏 Size: ${fileInfo['size']} bytes');
        print('🕐 Last modified: ${fileInfo['modified']}');

        final sizeKB = (fileInfo['size'] as int) / 1024;
        print('📊 Size category: ${_getSizeCategory(sizeKB)}');
      }
    } else {
      print('❌ File information unavailable');
    }
    print('');
  }

  static Future<void> _analyzeResponseStructure(
    Map<String, dynamic> response,
  ) async {
    print('🏗️  RESPONSE STRUCTURE ANALYSIS:');
    print('-' * 40);

    // Top level keys
    final topLevelKeys = response.keys.toList();
    print('📋 Top-level keys (${topLevelKeys.length}):');
    for (final key in topLevelKeys) {
      final valueType = response[key].runtimeType.toString();
      print('  • $key ($valueType)');
    }

    // Deep structure analysis
    print('\n🔍 Detailed structure:');
    _printStructure(response, 0);
    print('');
  }

  static Future<void> _analyzeSecurityData(
    Map<String, dynamic> response,
  ) async {
    print('🔐 SECURITY DATA ANALYSIS:');
    print('-' * 40);

    // Check for tokens
    final tokens = _findTokens(response);
    if (tokens.isNotEmpty) {
      print('🎫 Found ${tokens.length} token(s):');
      for (final token in tokens) {
        final tokenInfo = _analyzeToken(token['value']);
        print('  • ${token['key']}: ${tokenInfo['summary']}');
        print('    Length: ${token['value'].toString().length} chars');
        print('    Type: ${tokenInfo['type']}');
      }
    } else {
      print('🎫 No tokens found');
    }

    // Check for sensitive data
    final sensitiveFields = ['password', 'pin', 'otp', 'secret'];
    final foundSensitive = <String>[];

    _findSensitiveData(response, '', sensitiveFields, foundSensitive);

    if (foundSensitive.isNotEmpty) {
      print('\n⚠️  Sensitive data detected:');
      for (final field in foundSensitive) {
        print('  • $field');
      }
    } else {
      print('\n✅ No obvious sensitive data in plain text');
    }
    print('');
  }

  static Future<void> _analyzeUserData(Map<String, dynamic> response) async {
    print('👤 USER DATA ANALYSIS:');
    print('-' * 40);

    final userData = _extractUserData(response);
    if (userData.isNotEmpty) {
      print('📋 User information found:');
      for (final entry in userData.entries) {
        print('  • ${entry.key}: ${entry.value}');
      }
    } else {
      print('❌ No user data found');
    }
    print('');
  }

  static Future<void> _analyzeSessionData(Map<String, dynamic> response) async {
    print('📱 SESSION DATA ANALYSIS:');
    print('-' * 40);

    // Look for session-related data
    final sessionData = _extractSessionData(response);
    if (sessionData.isNotEmpty) {
      print('🔗 Session information:');
      for (final entry in sessionData.entries) {
        print('  • ${entry.key}: ${entry.value}');
      }
    } else {
      print('❌ No session data found');
    }

    // Check for expiry information
    final expiryInfo = _extractExpiryData(response);
    if (expiryInfo.isNotEmpty) {
      print('\n⏰ Expiry information:');
      for (final entry in expiryInfo.entries) {
        print('  • ${entry.key}: ${entry.value}');
        if (entry.key.toLowerCase().contains('expiry') ||
            entry.key.toLowerCase().contains('expires')) {
          final timeLeft = _calculateTimeLeft(entry.value.toString());
          if (timeLeft != null) {
            print('    Time left: $timeLeft');
          }
        }
      }
    }
    print('');
  }

  static Future<void> _analyzeTimestamps(Map<String, dynamic> response) async {
    print('🕐 TIMESTAMP ANALYSIS:');
    print('-' * 40);

    final timestamps = _extractTimestamps(response);
    if (timestamps.isNotEmpty) {
      print('📅 Found ${timestamps.length} timestamp(s):');
      for (final timestamp in timestamps) {
        print('  • ${timestamp['key']}: ${timestamp['value']}');
        final parsed = DateTime.tryParse(timestamp['value']?.toString() ?? '');
        if (parsed != null) {
          final now = DateTime.now();
          final diff = now.difference(parsed);
          print('    Age: ${_formatDuration(diff)}');
          print('    Type: ${diff.isNegative ? 'Future' : 'Past'}');
        }
      }
    } else {
      print('❌ No timestamps found');
    }
    print('');
  }

  // Helper methods
  static String _getSizeCategory(double sizeKB) {
    if (sizeKB < 1) return 'Tiny (< 1KB)';
    if (sizeKB < 10) return 'Small (< 10KB)';
    if (sizeKB < 100) return 'Medium (< 100KB)';
    return 'Large (>= 100KB)';
  }

  static void _printStructure(dynamic obj, int indent) {
    final spaces = '  ' * indent;
    if (obj is Map) {
      for (final entry in obj.entries) {
        if (entry.value is Map || entry.value is List) {
          print('$spaces${entry.key}:');
          _printStructure(entry.value, indent + 1);
        } else {
          final valueType = entry.value.runtimeType.toString();
          final preview = entry.value.toString();
          final shortPreview = preview.length > 50
              ? '${preview.substring(0, 47)}...'
              : preview;
          print('$spaces${entry.key}: $shortPreview ($valueType)');
        }
      }
    } else if (obj is List) {
      for (int i = 0; i < obj.length; i++) {
        print('$spaces[$i]:');
        _printStructure(obj[i], indent + 1);
      }
    }
  }

  static List<Map<String, dynamic>> _findTokens(Map<String, dynamic> obj) {
    final tokens = <Map<String, dynamic>>[];
    _findTokensRecursive(obj, '', tokens);
    return tokens;
  }

  static void _findTokensRecursive(
    dynamic obj,
    String path,
    List<Map<String, dynamic>> tokens,
  ) {
    if (obj is Map) {
      for (final entry in obj.entries) {
        final newPath = path.isEmpty ? entry.key : '$path.${entry.key}';
        if (entry.key.toLowerCase().contains('token') &&
            entry.value is String) {
          tokens.add({'key': newPath, 'value': entry.value});
        }
        _findTokensRecursive(entry.value, newPath, tokens);
      }
    } else if (obj is List) {
      for (int i = 0; i < obj.length; i++) {
        _findTokensRecursive(obj[i], '$path[$i]', tokens);
      }
    }
  }

  static Map<String, String> _analyzeToken(String token) {
    if (token.startsWith('eyJ')) {
      return {'type': 'JWT (JSON Web Token)', 'summary': 'JWT Token'};
    } else if (token.startsWith('temp_')) {
      return {'type': 'Temporary Token', 'summary': 'Session Token'};
    } else if (token.length > 50) {
      return {'type': 'Long Token', 'summary': 'API Token'};
    } else {
      return {'type': 'Short Token', 'summary': 'Simple Token'};
    }
  }

  static void _findSensitiveData(
    dynamic obj,
    String path,
    List<String> sensitiveFields,
    List<String> found,
  ) {
    if (obj is Map) {
      for (final entry in obj.entries) {
        final newPath = path.isEmpty ? entry.key : '$path.${entry.key}';
        final keyLower = entry.key.toLowerCase();

        for (final sensitive in sensitiveFields) {
          if (keyLower.contains(sensitive)) {
            found.add(newPath);
            break;
          }
        }

        _findSensitiveData(entry.value, newPath, sensitiveFields, found);
      }
    } else if (obj is List) {
      for (int i = 0; i < obj.length; i++) {
        _findSensitiveData(obj[i], '$path[$i]', sensitiveFields, found);
      }
    }
  }

  static Map<String, String> _extractUserData(Map<String, dynamic> response) {
    final userData = <String, String>{};
    final userFields = ['name', 'email', 'phone', 'id', 'username'];

    _extractDataByFields(response, '', userFields, userData);
    return userData;
  }

  static Map<String, String> _extractSessionData(
    Map<String, dynamic> response,
  ) {
    final sessionData = <String, String>{};
    final sessionFields = ['session', 'token', 'auth', 'login'];

    _extractDataByFields(response, '', sessionFields, sessionData);
    return sessionData;
  }

  static Map<String, String> _extractExpiryData(Map<String, dynamic> response) {
    final expiryData = <String, String>{};
    final expiryFields = ['expiry', 'expires', 'exp', 'valid_until'];

    _extractDataByFields(response, '', expiryFields, expiryData);
    return expiryData;
  }

  static void _extractDataByFields(
    dynamic obj,
    String path,
    List<String> fields,
    Map<String, String> result,
  ) {
    if (obj is Map) {
      for (final entry in obj.entries) {
        final newPath = path.isEmpty ? entry.key : '$path.${entry.key}';
        final keyLower = entry.key.toLowerCase();

        for (final field in fields) {
          if (keyLower.contains(field) &&
              entry.value is! Map &&
              entry.value is! List) {
            result[newPath] = entry.value.toString();
            break;
          }
        }

        _extractDataByFields(entry.value, newPath, fields, result);
      }
    }
  }

  static List<Map<String, String>> _extractTimestamps(
    Map<String, dynamic> response,
  ) {
    final timestamps = <Map<String, String>>[];
    _extractTimestampsRecursive(response, '', timestamps);
    return timestamps;
  }

  static void _extractTimestampsRecursive(
    dynamic obj,
    String path,
    List<Map<String, String>> timestamps,
  ) {
    if (obj is Map) {
      for (final entry in obj.entries) {
        final newPath = path.isEmpty ? entry.key : '$path.${entry.key}';

        if (entry.value is String && _isTimestamp(entry.value)) {
          timestamps.add({'key': newPath, 'value': entry.value});
        }

        _extractTimestampsRecursive(entry.value, newPath, timestamps);
      }
    }
  }

  static bool _isTimestamp(String value) {
    // Check for common timestamp formats
    final timestampPatterns = [
      RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}'), // ISO format
      RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}'), // MySQL format
      RegExp(r'.*_at$'), // Fields ending with _at
      RegExp(r'.*_time$'), // Fields ending with _time
    ];

    return timestampPatterns.any((pattern) => pattern.hasMatch(value));
  }

  static String? _calculateTimeLeft(String timestamp) {
    final parsed = DateTime.tryParse(timestamp);
    if (parsed != null) {
      final now = DateTime.now();
      final diff = parsed.difference(now);
      if (diff.isNegative) {
        return 'Expired ${_formatDuration(-diff)} ago';
      } else {
        return _formatDuration(diff);
      }
    }
    return null;
  }

  static String _formatDuration(Duration duration) {
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    final parts = <String>[];
    if (days > 0) parts.add('${days}d');
    if (hours > 0) parts.add('${hours}h');
    if (minutes > 0) parts.add('${minutes}m');
    if (seconds > 0) parts.add('${seconds}s');

    return parts.isEmpty ? '0s' : parts.join(' ');
  }
}
