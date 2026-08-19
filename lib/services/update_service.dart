import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../config/app_config.dart';

class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  static UpdateService get instance => _instance;
  UpdateService._internal();

  final Dio _dio = Dio();
  bool _isDialogShowing = false;
  bool _hasCheckedOnThisLoad = false;

  void startMonitoring(BuildContext context) {
    // Only check once per app load (not spam)
    // Flag hanya di-reset dari luar (misal: saat splash screen), bukan di sini
    if (_hasCheckedOnThisLoad) {
      debugPrint('Update check skipped - already checked on this load');
      return;
    }
    _hasCheckedOnThisLoad = true;
    _checkForUpdate(context);
  }

  /// Reset flag - dipanggil saat app baru dibuka (splash screen)
  void resetForNewLoad() {
    _hasCheckedOnThisLoad = false;
    _isDialogShowing = false;
  }

  void resetCheck() {
    _hasCheckedOnThisLoad = false;
  }

  Future<void> _checkForUpdate(BuildContext context) async {
    if (_isDialogShowing || !context.mounted) return;

    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version;
      int currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;

      debugPrint(
        'Checking for update. Current version: $currentVersion (build $currentBuildNumber)',
      );

      // Call API with current version parameter
      final response = await _dio.get(
        '${AppConfig.baseUrl}/check_version',
        queryParameters: {'version': currentVersion},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'];

        // Check maintenance mode first
        final isMaintenance =
            data['is_maintenance'] == '1' || data['is_maintenance'] == 1;
        if (isMaintenance) {
          _showMaintenanceDialog(
            context,
            data['release_notes'] ?? 'Aplikasi sedang dalam maintenance',
          );
          return;
        }

        final serverVersion = data['version'];
        final serverBuildNumber =
            int.tryParse(data['build_number']?.toString() ?? '0') ?? 0;
        final String url = data['url'] ?? '';
        final bool isForceUpdate =
            data['force_update'] == true ||
            data['force_update'] == '1' ||
            data['force_update'] == 1;
        final String releaseNotes =
            data['release_notes'] ?? 'Versi baru tersedia';
        final noUpdate = data['no_update'] == '1' || data['no_update'] == 1;

        debugPrint(
          'Server version: $serverVersion (build $serverBuildNumber), Force: $isForceUpdate, NoUpdate: $noUpdate',
        );

        // Check if newer version or force update
        // no_update: "0" means there's a newer version
        // no_update: "1" means current version is already the latest
        final hasNewerVersion =
            noUpdate == false || serverVersion != currentVersion;

        if (hasNewerVersion || isForceUpdate) {
          debugPrint(
            'Update available: server=$serverVersion (build $serverBuildNumber), current=$currentVersion (build $currentBuildNumber)',
          );
          _showUpdateDialog(
            context,
            serverVersion,
            url,
            isForceUpdate,
            releaseNotes,
          );
        } else {
          debugPrint(
            'No update available - version $currentVersion is already latest (no_update=$noUpdate)',
          );
        }
      } else {
        debugPrint('Failed to check version: ${response.data}');
      }
    } catch (e) {
      debugPrint("Update check failed: $e");
    }
  }

  void _showMaintenanceDialog(BuildContext context, String message) {
    _isDialogShowing = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.build_circle, color: Colors.orange, size: 28),
            SizedBox(width: 10),
            Text('Maintenance'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 15),
            const Text(
              'Hubungi admin untuk info lebih lanjut.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              // Exit app
              exit(0);
            },
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  void _showUpdateDialog(
    BuildContext context,
    String version,
    String url,
    bool isMandatory,
    String notes,
  ) {
    _isDialogShowing = true;

    showDialog(
      context: context,
      barrierDismissible: !isMandatory,
      builder: (dialogContext) {
        return PopScope(
          canPop: !isMandatory,
          child: AlertDialog(
            title: Text("Update Tersedia v$version"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(notes),
                const SizedBox(height: 10),
                const Text(
                  "Versi terbaru diperlukan untuk performa terbaik.",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                if (isMandatory)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      "* Update ini Wajib",
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            actions: [
              if (!isMandatory)
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _isDialogShowing = false;
                    // Don't reschedule - only check on app open
                  },
                  child: const Text("Nanti Saja"),
                ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  _isDialogShowing = false;
                  await _downloadAndInstallApk(context, url);
                },
                child: const Text("Update Sekarang"),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _downloadAndInstallApk(BuildContext context, String url) async {
    if (!context.mounted) return;

    debugPrint('Starting download from: $url');

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _DownloadProgressDialog(downloadUrl: url),
    );
  }

  bool _isNewerVersion(String current, String server) {
    List<int> currentParts = current
        .split('.')
        .map((e) => int.tryParse(e) ?? 0)
        .toList();
    List<int> serverParts = server
        .split('.')
        .map((e) => int.tryParse(e) ?? 0)
        .toList();

    for (int i = 0; i < 3; i++) {
      int c = i < currentParts.length ? currentParts[i] : 0;
      int s = i < serverParts.length ? serverParts[i] : 0;
      if (s > c) return true;
      if (s < c) return false;
    }
    return false;
  }
}

class _DownloadProgressDialog extends StatefulWidget {
  final String downloadUrl;

  const _DownloadProgressDialog({required this.downloadUrl});

  @override
  State<_DownloadProgressDialog> createState() =>
      _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<_DownloadProgressDialog> {
  double _progress = 0;
  String _status = 'Memulai download...';
  bool _isComplete = false;
  bool _isInstalling = false;
  String? _filePath;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    try {
      setState(() => _status = 'Menghubungi server...');

      final url = widget.downloadUrl;

      String filePath;

      if (Platform.isAndroid) {
        final downloadsDir = Directory('/storage/emulated/0/Download');
        if (await downloadsDir.exists()) {
          filePath = '${downloadsDir.path}/one_link_update.apk';
        } else {
          final dir = await getApplicationDocumentsDirectory();
          filePath = '${dir.path}/one_link_update.apk';
        }
      } else {
        final directory = await getApplicationDocumentsDirectory();
        filePath = '${directory.path}/one_link_update.apk';
      }

      _filePath = filePath;

      debugPrint('Download path: $filePath');
      setState(() => _status = 'Mengunduh...');

      final dio = Dio();
      await dio.download(
        url,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            debugPrint('Progress: ${(progress * 100).toStringAsFixed(0)}%');
            if (mounted) {
              setState(() {
                _progress = progress;
                _status =
                    'Mengunduh... ${(progress * 100).toStringAsFixed(0)}%';
              });
            }
          }
        },
      );

      final file = File(filePath);
      final exists = await file.exists();
      final length = exists ? await file.length() : 0;
      debugPrint(
        'Download complete! File exists: $exists, Size: $length bytes',
      );

      if (mounted) {
        setState(() {
          _progress = 1.0;
          _status = 'Download selesai!';
          _isComplete = true;
        });
      }
    } catch (e) {
      debugPrint('Download error: $e');
      if (mounted) {
        setState(() => _status = 'Gagal: $e');
      }
    }
  }

  Future<void> _installApk() async {
    if (_filePath == null) return;

    setState(() => _isInstalling = true);

    try {
      final tempPath = '/data/local/tmp/one_link_update.apk';
      final sourceFile = File(_filePath!);

      await sourceFile.copy(tempPath);
      debugPrint('Copied APK to temp: $tempPath');

      final result = await Process.run('pm', ['install', '-r', tempPath]);

      debugPrint('Install result: ${result.exitCode}');
      debugPrint('stdout: ${result.stdout}');
      debugPrint('stderr: ${result.stderr}');

      try {
        await File(tempPath).delete();
      } catch (e) {}

      if (mounted) {
        if (result.exitCode == 0) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Berhasil install!')));
          Navigator.of(context).pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Install gagal: ${result.stderr}')),
          );
        }
      }
    } catch (e) {
      debugPrint('Install error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal install. Silakan install manual.'),
          ),
        );
      }
    }

    if (mounted) {
      setState(() => _isInstalling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isComplete ? 'Update Selesai' : 'Mengunduh Update'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_isComplete) ...[
            Text(_status),
            const SizedBox(height: 20),
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 10),
            Text('${(_progress * 100).toStringAsFixed(0)}%'),
          ] else ...[
            const Icon(Icons.check_circle, color: Colors.green, size: 48),
            const SizedBox(height: 15),
            const Text(
              'APK berhasil diunduh!',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text('Lokasi: $_filePath', style: const TextStyle(fontSize: 11)),
            const SizedBox(height: 10),
            const Text('Klik tombol di bawah untuk install otomatis'),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Tutup'),
        ),
        if (_isComplete && !_isInstalling)
          ElevatedButton.icon(
            onPressed: _installApk,
            icon: const Icon(Icons.install_desktop),
            label: const Text('Install Sekarang'),
          ),
        if (_isInstalling)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      ],
    );
  }
}
