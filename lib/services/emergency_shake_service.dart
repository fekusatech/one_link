import 'dart:async';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shake/shake.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_colors.dart';
import 'geu/geu_api_client.dart';
import 'user_storage.dart';

class EmergencyShakeService {
  static final EmergencyShakeService _instance = EmergencyShakeService._internal();
  static EmergencyShakeService get instance => _instance;
  EmergencyShakeService._internal();

  ShakeDetector? _shakeDetector;
  bool _isListening = false;
  bool _isDialogShowing = false;
  DateTime? _lastShakeTime;

  /// Start listening for shake events (call on login / dashboard init)
  void startListening(BuildContext context) {
    if (_isListening) return;

    _shakeDetector = ShakeDetector.autoStart(
      shakeThresholdGravity: 3.5,
      minimumShakeCount: 3,
      shakeSlopTimeMS: 500,
      shakeCountResetTime: 3000,
      onPhoneShake: (event) {
        final now = DateTime.now();
        if (_lastShakeTime != null && now.difference(_lastShakeTime!).inSeconds < 8) {
          return; // Cooldown 8s
        }
        _lastShakeTime = now;
        _onShakeDetected(context);
      },
    );
    _isListening = true;
    debugPrint('🚨 Emergency Shake Detector started (Requirement: 3 shakes, Threshold: 3.5g)!');
  }

  /// Stop listening for shake events (call on logout)
  void stopListening() {
    _shakeDetector?.stopListening();
    _shakeDetector = null;
    _isListening = false;
    debugPrint('🚨 Emergency Shake Detector stopped.');
  }

  void _onShakeDetected(BuildContext context) {
    if (_isDialogShowing) return;

    // Heavy haptic vibration
    HapticFeedback.vibrate();

    _showEmergencyConfirmationDialog(context);
  }

  void _showEmergencyConfirmationDialog(BuildContext context) {
    _isDialogShowing = true;
    int countdown = 5;
    Timer? timer;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            timer ??= Timer.periodic(const Duration(seconds: 1), (t) {
              if (countdown > 1) {
                setDialogState(() => countdown--);
              } else {
                t.cancel();
                Navigator.of(dialogContext).pop();
                _isDialogShowing = false;
                _sendEmergencySOS(context);
              }
            });

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Sinyal Darurat (SOS)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  const Text(
                    'Ponsel dikocok 3 kali! Pesan WhatsApp Darurat lokasi & data diri Anda akan otomatis dikirim ke Admin/PIC.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.error.withValues(alpha: 0.4),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '$countdown',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Mengirim otomatis dalam $countdown detik...',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.error),
                  ),
                ],
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.grey,
                          side: const BorderSide(color: AppColors.borderColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          timer?.cancel();
                          Navigator.of(dialogContext).pop();
                          _isDialogShowing = false;
                        },
                        child: const Text('BATALKAN'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          timer?.cancel();
                          Navigator.of(dialogContext).pop();
                          _isDialogShowing = false;
                          _sendEmergencySOS(context);
                        },
                        icon: const Icon(Icons.send_rounded, size: 18),
                        label: const Text('KIRIM SOS', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      timer?.cancel();
      _isDialogShowing = false;
    });
  }

  Future<void> _sendEmergencySOS(BuildContext context) async {
    // Show loading banner
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('Mengirim pesan WhatsApp Darurat (SOS)...'),
            ],
          ),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 4),
        ),
      );
    }

    try {
      // 1. Get GPS Location
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );
      } catch (_) {
        position = await Geolocator.getLastKnownPosition();
      }

      final lat = position?.latitude ?? 0.0;
      final lng = position?.longitude ?? 0.0;

      // 2. Get Device Info
      String deviceModel = 'HP Mobile';
      String osVersion = '';
      try {
        final deviceInfo = DeviceInfoPlugin();
        if (Platform.isAndroid) {
          final androidInfo = await deviceInfo.androidInfo;
          deviceModel = '${androidInfo.brand} ${androidInfo.model}';
          osVersion = 'Android ${androidInfo.version.release} (API ${androidInfo.version.sdkInt})';
        } else if (Platform.isIOS) {
          final iosInfo = await deviceInfo.iosInfo;
          deviceModel = iosInfo.name;
          osVersion = 'iOS ${iosInfo.systemVersion}';
        }
      } catch (e) {
        debugPrint('Error reading device info: $e');
      }

      // 3. Send API request to /api/emergency/sos via Go REST API
      final dio = await GeuApiClient.instance;
      final response = await dio.post(
        '/api/emergency/sos',
        data: {
          'device_model': deviceModel,
          'os_version': osVersion,
          'latitude': lat,
          'longitude': lng,
          'message_extra': 'Sinyal darurat dikirim otomatis dengan mengocok ponsel.',
        },
      );

      final isSuccess = response.statusCode == 200 && response.data['status'] == 'success';

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isSuccess
                  ? '✅ Sinyal Darurat berhasil dikirim via WhatsApp!'
                  : '⚠️ Status: ${response.data['message'] ?? "Selesai"}',
            ),
            backgroundColor: isSuccess ? AppColors.success : AppColors.accentOrange,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error sending SOS API: $e');
      // Offline fallback: open WhatsApp URL scheme directly
      if (context.mounted) {
        _openDirectWhatsAppSOS(context);
      }
    }
  }

  Future<void> _openDirectWhatsAppSOS(BuildContext context) async {
    try {
      final user = await UserStorage.getUser();
      final userName = user?['userName'] ?? 'User';
      final userPhone = user?['userPhone'] ?? '';

      Position? pos = await Geolocator.getLastKnownPosition();
      final lat = pos?.latitude ?? 0.0;
      final lng = pos?.longitude ?? 0.0;

      final mapsUrl = 'https://maps.google.com/?q=$lat,$lng';
      final message = Uri.encodeComponent(
        '🚨 *PERINGATAN DARURAT (SOS)* 🚨\n\n'
        'Pengirim: $userName ($userPhone)\n'
        'Lokasi: $lat, $lng\n'
        'Maps: $mapsUrl\n\n'
        'Mohon bantuan segera!',
      );

      final waUrl = Uri.parse('https://wa.me/?text=$message');
      if (await canLaunchUrl(waUrl)) {
        await launchUrl(waUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching direct WA: $e');
    }
  }
}
