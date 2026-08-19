import 'package:flutter/material.dart';
import 'dart:convert';
import 'auth_debug_service.dart';
import '../constants/app_colors.dart';
import '../screens/auth_json_analysis_screen.dart';
import 'auth_json_analyzer.dart';

/// Global debug utilities for authentication
class GlobalDebugUtils {
  /// Show auth response in a dialog from anywhere in the app
  static Future<void> showAuthResponseDialog(BuildContext context) async {
    final authResponse = await AuthDebugService.getAuthResponse();
    final fileInfo = await AuthDebugService.getAuthFileInfo();

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.bug_report, color: Colors.green),
              SizedBox(width: 8),
              Text('Auth Response Debug'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // File info section
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '📄 File Information:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (fileInfo != null) ...[
                        Text(
                          'Status: ${fileInfo['exists'] ? '✅ Found' : '❌ Not Found'}',
                        ),
                        if (fileInfo['exists']) ...[
                          Text('Path: ${fileInfo['path']}'),
                          Text('Size: ${fileInfo['size']} bytes'),
                          Text('Modified: ${fileInfo['modified']}'),
                        ],
                      ] else ...[
                        const Text('❌ Unable to get file info'),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Response content section
                if (authResponse != null) ...[
                  const Text(
                    '📋 Response Content:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: SingleChildScrollView(
                      child: Text(
                        const JsonEncoder.withIndent(
                          '  ',
                        ).convert(authResponse),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: const Text('❌ No auth response found or saved yet'),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AuthJsonAnalysisScreen(),
                  ),
                );
              },
              child: const Text(
                'Open Analysis',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (authResponse != null)
              TextButton(
                onPressed: () async {
                  await AuthDebugService.clearAuthFile();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('🗑️ Auth file cleared successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                child: const Text(
                  'Clear File',
                  style: TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      );
    }
  }

  /// Quick method to print auth response to console
  static Future<void> printAuthToConsole() async {
    print('\n🔍 =================================');
    print('🔍 AUTH DEBUG - CONSOLE OUTPUT');
    print('🔍 =================================');

    final fileInfo = await AuthDebugService.getAuthFileInfo();
    if (fileInfo != null) {
      print('📄 File Status: ${fileInfo['exists'] ? 'Found' : 'Not Found'}');
      if (fileInfo['exists']) {
        print('📄 Path: ${fileInfo['path']}');
        print('📄 Size: ${fileInfo['size']} bytes');
        print('📄 Modified: ${fileInfo['modified']}');
      }
    }

    final authResponse = await AuthDebugService.getAuthResponse();
    if (authResponse != null) {
      print('\n📋 AUTH RESPONSE:');
      print(const JsonEncoder.withIndent('  ').convert(authResponse));
    } else {
      print('\n❌ No auth response found');
    }

    print('\n🔍 =================================\n');
  }

  /// Run full analysis to console
  static Future<void> runFullAnalysis() async {
    await AuthJsonAnalyzer.analyzeAuthFile();
  }

  /// Debug floating action button that can be added to any screen
  static Widget debugFloatingActionButton(BuildContext context) {
    // Only show in debug mode
    if (const bool.fromEnvironment('dart.vm.product')) {
      return const SizedBox.shrink();
    }

    return FloatingActionButton(
      mini: true,
      backgroundColor: AppColors.primaryGreen,
      onPressed: () => showAuthResponseDialog(context),
      child: const Icon(Icons.bug_report, color: Colors.white),
    );
  }
}
