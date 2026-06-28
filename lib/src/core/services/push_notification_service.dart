// lib/src/core/services/push_notification_service.dart
//
// Handles:
//  - Requesting notification permission (required on Android 13+ and iOS)
//  - Registering this device's FCM token with the backend
//    (POST /vendors/push-token/register)
//  - Showing a local notification WITH SOUND when a push arrives while the
//    app is in the FOREGROUND (FCM does not do this automatically — only
//    background/killed-app notifications are shown by the OS without help)
//  - A top-level background message handler, required by firebase_messaging
//    to be a top-level (or static) function, not a class method
//
// Channel id "orders" matches AndroidManifest.xml's
// com.google.firebase.messaging.default_notification_channel_id, which is
// what the real backend (services/pushNotificationService.js) relies on —
// that file's FCM messages don't set a per-message channelId, so the
// manifest default is what actually renders for background/killed-app
// notifications. Keeping the same id here keeps foreground notifications
// visually consistent with those.
//
// Call PushNotificationService.init() once, early in main() after
// Firebase.initializeApp(), and call
// PushNotificationService.registerTokenWithBackend() after the vendor logs
// in (once an auth token exists, since the registration call needs one).

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../api/dio_client.dart';

const String _ordersChannelId = 'orders';
const String _ordersChannelName = 'Orders';
const String _ordersChannelDescription =
    'Notifications for new paid orders that need vendor action';

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

/// MUST be a top-level function (not a class method, not a closure) —
/// this is a hard requirement of firebase_messaging's background handler,
/// because it runs in a separate isolate when the app is killed.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Intentionally minimal: when the app is backgrounded or killed, the OS
  // already shows the notification (title/body/sound) using the
  // `notification` payload and the AndroidManifest default channel —
  // no action needed here for that to work.
}

class PushNotificationService {
  static bool _initialized = false;

  /// Call once, early in main(), AFTER Firebase.initializeApp() has
  /// completed.
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _requestPermission();
    await _initLocalNotifications();

    // Foreground messages: FCM does NOT show a system notification by
    // itself while the app is open — we must do it manually here so the
    // vendor hears the same sound whether the app is open or not.
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);

    // When the vendor taps a notification that arrived while the app was
    // backgrounded (not killed), this fires. Left as a no-op — wire up
    // navigation to /orders/${message.data['order_id']} here if desired.
    FirebaseMessaging.onMessageOpenedApp.listen((message) {});
  }

  static Future<void> _requestPermission() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    assert(() {
      debugPrint('🔔 Push permission status: ${settings.authorizationStatus}');
      return true;
    }());
  }

  static Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        _ordersChannelId,
        _ordersChannelName,
        description: _ordersChannelDescription,
        importance: Importance.max,
        playSound: true,
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  static void _showForegroundNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _ordersChannelId,
          _ordersChannelName,
          channelDescription: _ordersChannelDescription,
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(presentSound: true),
      ),
    );
  }

  /// Call after the vendor is logged in. Gets this device's FCM token and
  /// registers it with the backend so order-paid pushes can reach this
  /// device. Matches the real route: POST /vendors/push-token/register
  /// (vendorController.registerVendorPushToken).
  static Future<void> registerTokenWithBackend() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      await ApiClient.dio.post('/vendors/push-token/register', data: {
        'token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
      });

      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        ApiClient.dio.post('/vendors/push-token/register', data: {
          'token': newToken,
          'platform': Platform.isIOS ? 'ios' : 'android',
        }).catchError((_) {
          // Best-effort — if this fails, the old token simply goes stale.
        });
      });
    } catch (e) {
      debugPrint('⚠️ Failed to register push token: $e');
    }
  }

  /// Call on logout. Matches DELETE /vendors/push-token/unregister
  /// (vendorController.unregisterVendorPushToken).
  static Future<void> unregisterToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await ApiClient.dio.delete('/vendors/push-token/unregister', data: {
        'token': token,
      });
    } catch (_) {
      // Best-effort on logout.
    }
  }
}
