import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'geu_api_client.dart';
import '../../screens/notification_screen.dart';

/// Handles messages FCM delivers while the app is fully backgrounded/killed.
/// Must be a top-level (or static) function — Flutter runs it in its own
/// isolate, so it can't close over any app/widget state. There's nothing to
/// do here beyond letting it exist: FCM already renders the system-tray
/// notification itself in this state from the message's `notification`
/// payload; registering this handler is what makes that guaranteed rather
/// than best-effort on some OEM Android builds.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

/// Push notifications triggered from erpmysql's "Kirim Notifikasi" page via
/// go-rest-api (POST /api-internal/notifications/send) — see
/// docs/plans/push-notifications. This only handles receiving/displaying;
/// the existing s_notifications-backed inbox (notification_screen.dart) is
/// unchanged and keeps working independently of whether push delivery
/// succeeds for a given device.
class PushNotificationService {
  PushNotificationService._();

  static final _local = FlutterLocalNotificationsPlugin();
  static const _channelId = 'erp_push_channel';
  static const _channelName = 'Notifikasi';
  static const _channelDesc = 'Notifikasi dari sistem (ERP)';
  static bool _initialized = false;

  /// Call in main(), before runApp — registering the background handler
  /// only works before the widget tree exists.
  static void registerBackgroundHandler() {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  /// Call once the app's widget tree exists (e.g. MyApp.initState) — sets up
  /// the local-notification channel used to actually show foreground
  /// messages (FCM does NOT auto-display a system notification while the
  /// app is in the foreground; that's the whole reason this local-notify
  /// path exists), permission request, and tap-to-open handling.
  static Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    if (!_initialized) {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _local.initialize(
        const InitializationSettings(android: androidInit),
        onDidReceiveNotificationResponse: (_) => _openInbox(navigatorKey),
      );
      _initialized = true;
    }

    await FirebaseMessaging.instance.requestPermission();

    FirebaseMessaging.onMessage.listen((message) => _showForeground(message));
    FirebaseMessaging.onMessageOpenedApp.listen(
      (_) => _openInbox(navigatorKey),
    );
    // App was launched by tapping a notification from a fully-killed state.
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _openInbox(navigatorKey);
  }

  static void _openInbox(GlobalKey<NavigatorState> navigatorKey) {
    // The erpmysql `link` field targets a web route shape, not a Flutter
    // route name, so there's no safe generic mapping yet — landing on the
    // existing notification inbox is the one destination guaranteed to make
    // sense for every push regardless of what `link` contains.
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const NotificationScreen()),
    );
  }

  static Future<void> _showForeground(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
    );
    await _local.show(
      message.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(android: androidDetails),
    );
  }

  /// Call after login succeeds and whenever the token refreshes. Failures
  /// are swallowed — a missing push token degrades to "no push for this
  /// device" (the in-app inbox is unaffected), not a login-blocking error.
  static Future<void> registerToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      final dio = await GeuApiClient.instance;
      await dio.post(
        '/api/devices/fcm-token',
        data: {'token': token, 'platform': 'android'},
      );
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        try {
          final dio = await GeuApiClient.instance;
          await dio.post(
            '/api/devices/fcm-token',
            data: {'token': newToken, 'platform': 'android'},
          );
        } catch (_) {}
      });
    } catch (_) {}
  }

  /// Call on logout so a shared/reset device stops receiving pushes meant
  /// for whoever was previously logged in on it.
  static Future<void> deactivateToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      final dio = await GeuApiClient.instance;
      await dio.delete('/api/devices/fcm-token', data: {'token': token});
    } catch (_) {}
  }
}
