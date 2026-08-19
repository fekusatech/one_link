import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../services/auth_debug_service.dart';
import '../services/auth_json_analyzer.dart';

class AuthJsonAnalysisScreen extends StatefulWidget {
  const AuthJsonAnalysisScreen({super.key});

  @override
  State<AuthJsonAnalysisScreen> createState() => _AuthJsonAnalysisScreenState();
}

class _AuthJsonAnalysisScreenState extends State<AuthJsonAnalysisScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _authData;
  Map<String, dynamic>? _fileInfo;
  String _analysisReport = '';

  @override
  void initState() {
    super.initState();
    _loadAuthData();
  }

  Future<void> _loadAuthData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authResponse = await AuthDebugService.getAuthResponse();
      final fileInfo = await AuthDebugService.getAuthFileInfo();

      // Generate console analysis
      await _generateConsoleAnalysis();

      setState(() {
        _authData = authResponse;
        _fileInfo = fileInfo;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading auth data: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _generateConsoleAnalysis() async {
    // This will print detailed analysis to console
    await AuthJsonAnalyzer.analyzeAuthFile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Auth.json Analysis',
          style: AppTextStyles.h6.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppColors.primaryGreen),
            onPressed: _loadAuthData,
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: AppColors.textPrimary),
            onSelected: (value) async {
              switch (value) {
                case 'console':
                  await AuthJsonAnalyzer.analyzeAuthFile();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('📊 Analysis printed to console'),
                      backgroundColor: AppColors.primaryGreen,
                    ),
                  );
                  break;
                case 'copy':
                  if (_authData != null) {
                    final jsonString = const JsonEncoder.withIndent(
                      '  ',
                    ).convert(_authData);
                    await Clipboard.setData(ClipboardData(text: jsonString));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('📋 JSON copied to clipboard'),
                      ),
                    );
                  }
                  break;
                case 'clear':
                  final confirmed = await _showClearConfirmation();
                  if (confirmed) {
                    await AuthDebugService.clearAuthFile();
                    await _loadAuthData();
                  }
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'console',
                child: Row(
                  children: [
                    Icon(Icons.terminal),
                    SizedBox(width: 8),
                    Text('Print to Console'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'copy',
                child: Row(
                  children: [
                    Icon(Icons.copy),
                    SizedBox(width: 8),
                    Text('Copy JSON'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Clear File', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            )
          : _authData == null
          ? _buildNoDataView()
          : _buildAnalysisView(),
    );
  }

  Widget _buildNoDataView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.description_outlined, size: 64, color: AppColors.grey),
          const SizedBox(height: 16),
          Text(
            'No Auth Data Found',
            style: AppTextStyles.h5.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Login first to generate auth.json file',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('Go to Login', style: AppTextStyles.button),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // File Info Card
          _buildFileInfoCard(),
          const SizedBox(height: 16),

          // Quick Stats Card
          _buildQuickStatsCard(),
          const SizedBox(height: 16),

          // Security Analysis Card
          _buildSecurityCard(),
          const SizedBox(height: 16),

          // Data Structure Card
          _buildDataStructureCard(),
          const SizedBox(height: 16),

          // Raw JSON Card
          _buildRawJsonCard(),
        ],
      ),
    );
  }

  Widget _buildFileInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.primaryGreen),
                const SizedBox(width: 8),
                Text(
                  'File Information',
                  style: AppTextStyles.h6.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_fileInfo != null) ...[
              _buildInfoRow(
                'Status',
                _fileInfo!['exists'] ? '✅ Found' : '❌ Not Found',
              ),
              if (_fileInfo!['exists']) ...[
                _buildInfoRow('Size', '${_fileInfo!['size']} bytes'),
                _buildInfoRow('Modified', '${_fileInfo!['modified']}'),
                _buildInfoRow('Path', '${_fileInfo!['path']}'),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStatsCard() {
    final stats = _calculateStats();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: AppColors.accentOrange),
                const SizedBox(width: 8),
                Text(
                  'Quick Stats',
                  style: AppTextStyles.h6.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _buildStatChip('Fields', '${stats['fieldCount']}'),
                _buildStatChip('Tokens', '${stats['tokenCount']}'),
                _buildStatChip('Timestamps', '${stats['timestampCount']}'),
                _buildStatChip('Objects', '${stats['objectCount']}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityCard() {
    final tokens = _findTokens(_authData!);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.security, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  'Security Analysis',
                  style: AppTextStyles.h6.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (tokens.isNotEmpty) ...[
              Text(
                'Tokens Found:',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ...tokens
                  .map(
                    (token) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            token['key'],
                            style: AppTextStyles.bodySmall.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.red[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${token['value'].toString().substring(0, 20)}...',
                            style: AppTextStyles.bodySmall.copyWith(
                              fontFamily: 'monospace',
                              color: AppColors.grey,
                            ),
                          ),
                          Text(
                            'Length: ${token['value'].toString().length} chars',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'No sensitive tokens detected',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDataStructureCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_tree, color: AppColors.info),
                const SizedBox(width: 8),
                Text(
                  'Data Structure',
                  style: AppTextStyles.h6.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.grey.withOpacity(0.3)),
              ),
              child: Text(
                _generateStructurePreview(_authData!, 0, 3), // Max depth 3
                style: AppTextStyles.bodySmall.copyWith(
                  fontFamily: 'monospace',
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRawJsonCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.code, color: AppColors.grey),
                const SizedBox(width: 8),
                Text(
                  'Raw JSON Data',
                  style: AppTextStyles.h6.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () async {
                    final jsonString = const JsonEncoder.withIndent(
                      '  ',
                    ).convert(_authData);
                    await Clipboard.setData(ClipboardData(text: jsonString));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('📋 JSON copied to clipboard'),
                      ),
                    );
                  },
                  icon: Icon(
                    Icons.copy,
                    size: 16,
                    color: AppColors.primaryGreen,
                  ),
                  label: Text(
                    'Copy',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              height: 200,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.grey.withOpacity(0.3)),
              ),
              child: SingleChildScrollView(
                child: Text(
                  const JsonEncoder.withIndent('  ').convert(_authData),
                  style: AppTextStyles.bodySmall.copyWith(
                    fontFamily: 'monospace',
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.primaryGreen,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, int> _calculateStats() {
    int fieldCount = 0;
    int tokenCount = 0;
    int timestampCount = 0;
    int objectCount = 0;

    void countFields(dynamic obj) {
      if (obj is Map) {
        objectCount++;
        for (final entry in obj.entries) {
          fieldCount++;
          if (entry.key.toLowerCase().contains('token')) {
            tokenCount++;
          }
          if (entry.value is String && _isTimestamp(entry.value)) {
            timestampCount++;
          }
          countFields(entry.value);
        }
      } else if (obj is List) {
        for (final item in obj) {
          countFields(item);
        }
      }
    }

    countFields(_authData);

    return {
      'fieldCount': fieldCount,
      'tokenCount': tokenCount,
      'timestampCount': timestampCount,
      'objectCount': objectCount,
    };
  }

  List<Map<String, dynamic>> _findTokens(Map<String, dynamic> obj) {
    final tokens = <Map<String, dynamic>>[];

    void findTokensRecursive(dynamic obj, String path) {
      if (obj is Map) {
        for (final entry in obj.entries) {
          final newPath = path.isEmpty ? entry.key : '$path.${entry.key}';
          if (entry.key.toLowerCase().contains('token') &&
              entry.value is String) {
            tokens.add({'key': newPath, 'value': entry.value});
          }
          findTokensRecursive(entry.value, newPath);
        }
      } else if (obj is List) {
        for (int i = 0; i < obj.length; i++) {
          findTokensRecursive(obj[i], '$path[$i]');
        }
      }
    }

    findTokensRecursive(obj, '');
    return tokens;
  }

  String _generateStructurePreview(dynamic obj, int indent, int maxDepth) {
    if (indent > maxDepth) return '...';

    final spaces = '  ' * indent;
    final buffer = StringBuffer();

    if (obj is Map) {
      for (final entry in obj.entries) {
        if (entry.value is Map || entry.value is List) {
          buffer.writeln('$spaces${entry.key}:');
          buffer.write(
            _generateStructurePreview(entry.value, indent + 1, maxDepth),
          );
        } else {
          final valueType = entry.value.runtimeType.toString();
          final preview = entry.value.toString();
          final shortPreview = preview.length > 30
              ? '${preview.substring(0, 27)}...'
              : preview;
          buffer.writeln('$spaces${entry.key}: $shortPreview ($valueType)');
        }
      }
    } else if (obj is List) {
      buffer.writeln('${spaces}Array[${obj.length}]');
      if (obj.isNotEmpty && indent < maxDepth) {
        buffer.writeln('$spaces[0]:');
        buffer.write(_generateStructurePreview(obj[0], indent + 1, maxDepth));
      }
    }

    return buffer.toString();
  }

  bool _isTimestamp(String value) {
    final timestampPatterns = [
      RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}'),
      RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}'),
    ];

    return timestampPatterns.any((pattern) => pattern.hasMatch(value));
  }

  Future<bool> _showClearConfirmation() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Clear Auth File'),
            content: const Text(
              'Are you sure you want to delete the auth.json file? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }
}

