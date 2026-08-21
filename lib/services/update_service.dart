import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';
import '../constants/app_colors.dart';
import 'geu/geu_api_client.dart';

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

  /// Manual "Cek Pembaruan" entry point (Profile screen) — same check as
  /// the silent startup one, but bypasses the once-per-load throttle and
  /// gives feedback either way (update dialog, maintenance dialog, or a
  /// "already latest" / error snackbar) since a user who explicitly asked
  /// shouldn't get silence as the answer.
  Future<void> checkNow(BuildContext context) =>
      _checkForUpdate(context, manual: true);

  Future<void> _checkForUpdate(
    BuildContext context, {
    bool manual = false,
  }) async {
    if (_isDialogShowing || !context.mounted) return;

    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version;
      int currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;

      debugPrint(
        'Checking for update. Current version: $currentVersion (build $currentBuildNumber)',
      );

      // Mobile release policy is maintained by the Go API. It is checked
      // first so Play Store force-updates do not rely on the legacy ERP API.
      final mobileConfig = await _dio.get(
        '${GeuApiClient.baseUrl}/api/mobile/config',
      );
      if (mobileConfig.statusCode == 200 && mobileConfig.data is Map) {
        final config = mobileConfig.data as Map;
        final minimum = config['min_version']?.toString() ?? '';
        final latest = config['latest_version']?.toString() ?? '';
        final force = config['force_update'] == true;
        final storeUrl = config['store_url']?.toString() ?? '';
        if (force &&
            minimum.isNotEmpty &&
            _isNewerVersion(currentVersion, minimum)) {
          _showStoreUpdateDialog(
            context,
            latest.isEmpty ? minimum : latest,
            storeUrl,
          );
          return;
        }
      }

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
          if (manual) _showSnackBar(context, 'Aplikasi sudah versi terbaru.');
        }
      } else {
        debugPrint('Failed to check version: ${response.data}');
        if (manual) {
          _showSnackBar(context, 'Gagal memeriksa pembaruan. Coba lagi.');
        }
      }
    } catch (e) {
      debugPrint("Update check failed: $e");
      if (manual) {
        _showSnackBar(context, 'Gagal memeriksa pembaruan. Coba lagi.');
      }
    }
  }

  void _showSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
        content: SizedBox(
          width: double.maxFinite,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(dialogContext).size.height * 0.6,
            ),
            child: SingleChildScrollView(
              child: Column(
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
            ),
          ),
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

  void _showStoreUpdateDialog(
    BuildContext context,
    String version,
    String url,
  ) {
    _isDialogShowing = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text('Update wajib v$version'),
          content: const Text(
            'Versi aplikasi ini sudah tidak didukung. Perbarui melalui Play Store untuk melanjutkan.',
          ),
          actions: [
            ElevatedButton(
              onPressed: url.isEmpty
                  ? null
                  : () => launchUrl(
                      Uri.parse(url),
                      mode: LaunchMode.externalApplication,
                    ),
              child: const Text('Buka Play Store'),
            ),
          ],
        ),
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
            // Release notes can be a long multi-line changelog (see
            // screenshot report: unbounded Column overflowed the dialog by
            // 1500+ px, rendered as Flutter's black/yellow debug hazard
            // stripes). Cap the dialog's content height and let the notes
            // scroll inside it instead.
            content: SizedBox(
              width: double.maxFinite,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(dialogContext).size.height * 0.6,
                ),
                child: SingleChildScrollView(
                  child: Column(
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
                ),
              ),
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
    if (kIsWeb) {
      setState(() => _status = 'Update APK hanya didukung di Android');
      return;
    }
    try {
      setState(() => _status = 'Menghubungi server...');

      final url = widget.downloadUrl;

      // Save in temporary/cache directory where FileProvider has full read access
      Directory directory;
      try {
        directory = await getTemporaryDirectory();
      } catch (_) {
        directory = await getApplicationDocumentsDirectory();
      }
      final filePath = '${directory.path}/one_link_update.apk';

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
        _installApk();
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
      final file = File(_filePath!);
      if (!await file.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Berkas APK tidak ditemukan. Silakan unduh ulang.')),
          );
        }
        return;
      }

      final result = await OpenFilex.open(
        _filePath!,
        type: 'application/vnd.android.package-archive',
      );
      debugPrint('OpenFilex result: ${result.type} - ${result.message}');

      if (mounted) {
        if (result.type == ResultType.done) {
          Navigator.of(context).pop();
        } else {
          // If OpenFilex returned error, try launchUrl fallback
          try {
            final uri = Uri.file(_filePath!);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri);
              Navigator.of(context).pop();
              return;
            }
          } catch (_) {}

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal membuka installer: ${result.message}'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Install error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal membuka installer. Silakan install manual.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isInstalling = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_isComplete) ...[
            // Downloading State Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_download_rounded,
                color: AppColors.primaryGreen,
                size: 42,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Mengunduh Pembaruan',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              _status.isNotEmpty ? _status : 'Sedang mengunduh berkas aplikasi...',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
                minHeight: 10,
                backgroundColor: AppColors.lightGrey,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Mohon tunggu sebentar',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                Text(
                  '${(_progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryGreen),
                ),
              ],
            ),
          ] else ...[
            // Completed State
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppColors.primaryGreen,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Pembaruan Siap Dipasang',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              _isInstalling
                  ? 'Membuka paket instalasi Android...'
                  : 'Versi terbaru berhasil diunduh. Tekan "Install Sekarang" untuk memasang.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        if (!_isComplete)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Batalkan', style: TextStyle(color: AppColors.grey)),
          )
        else ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Batal', style: TextStyle(color: AppColors.grey)),
          ),
          if (!_isInstalling)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _installApk,
              icon: const Icon(Icons.system_update, size: 18),
              label: const Text('Install Sekarang', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          if (_isInstalling)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primaryGreen),
              ),
            ),
        ],
      ],
    );
  }
}
