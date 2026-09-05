import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

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

  /// Call in main(), before runApp — registering the background handler
  /// only works before the widget tree exists.
  static void registerBackgroundHandler() {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  /// Call once the app's widget tree exists (e.g. MyApp.initState) — requests
  /// notification permission and wires up foreground/tap-to-open handling.
  static Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    await FirebaseMessaging.instance.requestPermission();

    FirebaseMessaging.onMessage.listen(
      (message) => _showForegroundModal(navigatorKey, message),
    );
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

  /// FCM does not show a system-tray notification while the app is in the
  /// foreground, so a message arriving here would otherwise go unnoticed —
  /// show it as an in-app modal instead, since the user is already looking
  /// at the app.
  static void _showForegroundModal(
    GlobalKey<NavigatorState> navigatorKey,
    RemoteMessage message,
  ) {
    final notification = message.notification;
    if (notification == null) return;
    final context = navigatorKey.currentState?.overlay?.context;
    if (context == null) return;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(notification.title ?? 'Notifikasi'),
        content: Text(notification.body ?? ''),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Tutup'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _openInbox(navigatorKey);
            },
            child: const Text('Lihat'),
          ),
        ],
      ),
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
