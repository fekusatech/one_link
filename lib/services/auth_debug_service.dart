import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Service for debugging authentication responses
class AuthDebugService {
  /// Get the auth.json file path
  static Future<String?> getAuthFilePath() async {
    if (kIsWeb) return null;
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/auth.json';
  }

  /// Read the saved auth response from auth.json
  static Future<Map<String, dynamic>?> getAuthResponse() async {
    try {
      if (kIsWeb) return null;
      final filePath = await getAuthFilePath();
      if (filePath == null) return null;
      final file = File(filePath);

      if (await file.exists()) {
        final jsonString = await file.readAsString();
        return jsonDecode(jsonString) as Map<String, dynamic>;
      } else {
        print('📄 No auth.json file found');
        return null;
      }
    } catch (e) {
      print('❌ Error reading auth.json: $e');
      return null;
    }
  }

  /// Print the auth response in a readable format
  static Future<void> printAuthResponse() async {
    final response = await getAuthResponse();
    if (response != null) {
      print('📋 === AUTH RESPONSE FROM auth.json ===');
      print(const JsonEncoder.withIndent('  ').convert(response));
      print('📋 === END AUTH RESPONSE ===');
    } else {
      print('📄 No auth response found');
    }
  }

  /// Check if auth.json file exists
  static Future<bool> hasAuthFile() async {
    try {
      final filePath = await getAuthFilePath();
      final file = File(filePath);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  /// Delete auth.json file
  static Future<bool> clearAuthFile() async {
    try {
      final filePath = await getAuthFilePath();
      final file = File(filePath);

      if (await file.exists()) {
        await file.delete();
        print('🗑️ auth.json file deleted');
        return true;
      } else {
        print('📄 No auth.json file to delete');
        return false;
      }
    } catch (e) {
      print('❌ Error deleting auth.json: $e');
      return false;
    }
  }

  /// Get file info
  static Future<Map<String, dynamic>?> getAuthFileInfo() async {
    try {
      final filePath = await getAuthFilePath();
      final file = File(filePath);

      if (await file.exists()) {
        final stat = await file.stat();
        return {
          'path': filePath,
          'size': stat.size,
          'modified': stat.modified.toIso8601String(),
          'exists': true,
        };
      } else {
        return {'path': filePath, 'exists': false};
      }
    } catch (e) {
      print('❌ Error getting file info: $e');
      return null;
    }
  }
}
