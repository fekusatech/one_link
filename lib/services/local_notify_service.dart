import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Wrapper lokal notifikasi (status bar Android).
/// Dipakai untuk memberi tahu user "sedang mendekati supplier" meski
/// aplikasi di background/close.
class LocalNotifyService {
  LocalNotifyService._internal();
  static final LocalNotifyService instance = LocalNotifyService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  static const _channelId = 'proximity_wa_channel';
  static const _channelName = 'Pendekatan Supplier';
  static const _channelDesc = 'Notifikasi saat driver mendekati lokasi supplier';

  /// Init saat app start (main / dashboard). Idempotent.
  Future<void> init() async {
    if (_initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidInit);
    await _plugin.initialize(settings);
    _initialized = true;
  }

  /// Pastikan notifikasi diizinkan (Android 13+).
  Future<bool> ensurePermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    return await android.requestNotificationsPermission() ?? false;
  }

  /// Tampilkan notif "mendekati supplier".
  Future<void> showNearSupplier({
    required String supplierName,
    required String noSuratJalan,
  }) async {
    await init();

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.message,
      visibility: NotificationVisibility.public,
      enableVibration: true,
    );

    await _plugin.show(
      4101, // fixed id → ganti isi, tidak numpuk
      'Mendekati $supplierName 🚚',
      'Surat Jalan $noSuratJalan — segera hubungi supplier via WhatsApp.',
      const NotificationDetails(android: androidDetails),
    );
  }
}
