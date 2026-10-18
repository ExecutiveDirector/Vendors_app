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
import 'dart:typed_data';
import 'dart:ui';
import 'package:dio/dio.dart' show DioException;
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../api/dio_client.dart';
import 'incoming_order_service.dart';

const String _ordersChannelId = 'orders';
const String _ordersChannelName = 'Orders';
const String _ordersChannelDescription =
    'Notifications for new paid orders that need vendor action';

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

/// One Android notification channel per backend `notification_type`
/// (matches the types used in NotificationsScreen / the
/// GET /vendors/notifications payload), so EVERY notification the vendor
/// gets — not just "new paid order" pushes from FCM — rings/vibrates the
/// phone the same way a normal push notification would.
///
/// 'order_update' intentionally reuses the pre-existing `orders` channel id
/// so it still lines up with AndroidManifest.xml's
/// com.google.firebase.messaging.default_notification_channel_id.
class _NotificationChannel {
  final String id;
  final String name;
  final String description;
  const _NotificationChannel(this.id, this.name, this.description);
}

const Map<String, _NotificationChannel> _channelsByType = {
  'order_update': _NotificationChannel(
      _ordersChannelId, _ordersChannelName, _ordersChannelDescription),
  'delivery_update': _NotificationChannel(
      'delivery_updates', 'Delivery Updates', 'Updates about order deliveries'),
  'payment_update': _NotificationChannel(
      'payment_updates', 'Payment Updates', 'Updates about payments and payouts'),
  'promotional': _NotificationChannel(
      'promotions', 'Promotions', 'Promotional offers and announcements'),
  'system_alert': _NotificationChannel(
      'system_alerts', 'System Alerts', 'Important system alerts'),
  'reminder': _NotificationChannel(
      'reminders', 'Reminders', 'Reminders that need your attention'),
};
const _NotificationChannel _defaultChannel =
    _NotificationChannel('general', 'General', 'Other app notifications');

/// MUST be a top-level function (not a class method, not a closure) —
/// this is a hard requirement of firebase_messaging's background handler,
/// because it runs in a separate isolate when the app is killed.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Messages with a `notification` block are shown by the OS itself. New-order
  // alerts are data-only (type: new_order) so the app can raise a loud
  // full-screen alert here — a plain notification never woke a sleeping phone.
  if (message.notification != null ||
      (message.data['type'] != 'new_order' && message.data['type'] != 'test_alert')) {
    return;
  }
  DartPluginRegistrant.ensureInitialized();
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(const InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(),
  ));
  await plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_ordersChannel);
  await plugin.show(
    ((int.tryParse(message.data['order_id'] ?? '') ?? message.hashCode) &
        0x7fffffff),
    message.data['title'] ?? 'New order',
    message.data['body'] ?? 'A customer order needs your approval',
    _orderAlertDetails(),
    payload: message.data['order_id'],
  );
}

final Int64List _alarmVibration =
    Int64List.fromList([0, 800, 400, 800, 400, 800, 400, 800]);

// A NEW channel id: Android never lets an existing channel's sound change, and the
// old 'orders' channel had the default tone. This one carries the custom order alarm.
const String _alertChannelId = 'new_order_alert';

final AndroidNotificationChannel _ordersChannel = AndroidNotificationChannel(
  _alertChannelId,
  'New order alerts',
  description: 'Loud alarm when a customer order needs your approval',
  importance: Importance.max,
  playSound: true,
  sound: const RawResourceAndroidNotificationSound('order_alert'),
  audioAttributesUsage: AudioAttributesUsage.alarm,
  enableVibration: true,
  vibrationPattern: _alarmVibration,
);

NotificationDetails _orderAlertDetails() => NotificationDetails(
      android: AndroidNotificationDetails(
        _alertChannelId,
        'New order alerts',
        channelDescription: 'Loud alarm when a customer order needs your approval',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('order_alert'),
        // FLAG_INSISTENT: keep repeating the sound until the alert is opened/dismissed.
        additionalFlags: Int32List.fromList(<int>[4]),
        ongoing: true,
        autoCancel: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        enableVibration: true,
        vibrationPattern: _alarmVibration,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        timeoutAfter: 120000,
      ),
      iOS: const DarwinNotificationDetails(
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );

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
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      if (message.data['type'] == 'new_order') {
        IncomingOrderService.instance.showFor(message.data['order_id']);
      }
    });

    // App was launched (from killed) by tapping an order alert.
    try {
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial?.data['type'] == 'new_order') {
        IncomingOrderService.instance.showFor(initial!.data['order_id']);
      }
      final launch = await _localNotifications.getNotificationAppLaunchDetails();
      final payload = launch?.notificationResponse?.payload;
      if (launch?.didNotificationLaunchApp == true && payload != null) {
        IncomingOrderService.instance.showFor(payload);
      }
    } catch (e) {
      debugPrint('⚠️ launch details failed: $e');
    }
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
      onDidReceiveNotificationResponse: (response) {
        final id = response.payload;
        if (id != null && id.isNotEmpty) {
          IncomingOrderService.instance.showFor(id);
        }
      },
    );

    if (Platform.isAndroid) {
      final androidImpl = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.createNotificationChannel(_ordersChannel);
      // Android 14+: full-screen order alerts need an explicit grant.
      await androidImpl?.requestFullScreenIntentPermission();
      for (final ch in [..._channelsByType.values, _defaultChannel]) {
        final isOrdersChannel = ch.id == _ordersChannelId;
        await androidImpl?.createNotificationChannel(AndroidNotificationChannel(
          ch.id,
          ch.name,
          description: ch.description,
          importance: Importance.max,
          playSound: true,
          audioAttributesUsage: isOrdersChannel
              ? AudioAttributesUsage.alarm
              : AudioAttributesUsage.notification,
          enableVibration: true,
          vibrationPattern: isOrdersChannel
              ? Int64List.fromList([0, 800, 400, 800, 400, 800, 400, 800])
              : null,
        ));
      }
    }
  }

  static void _showForegroundNotification(RemoteMessage message) {
    // Data-only new-order alert while the app is open: raise the accept sheet.
    if (message.data['type'] == 'new_order') {
      // The accept sheet rings (looping alarm) itself; no tray notification needed in the foreground.
      IncomingOrderService.instance.showFor(message.data['order_id']);
      return;
    }
    final notification = message.notification;
    if (notification == null) return;

    // This FCM channel is currently only used for "new paid order" pushes
    // (see file header), so default the type accordingly if the payload
    // doesn't say otherwise.
    showLocalNotification(
      id: message.hashCode,
      title: notification.title ?? 'New notification',
      body: notification.body ?? '',
      type: message.data['type'] as String? ?? 'order_update',
    );
  }

  /// Same event can legitimately reach this method from two independent
  /// paths for a new paid order: FCM foreground messages and the notifications
  /// poller. The dedupe map prevents duplicate sounds and shade entries.
  static final Map<String, DateTime> _recentlyShown = {};
  static const _dedupeWindow = Duration(seconds: 20);

  /// Shows a native phone notification (system tray entry + sound) for ANY
  /// notification in the app — order updates, delivery updates, payment
  /// updates, promotions, system alerts, reminders, etc. — not just the
  /// "new paid order" pushes FCM delivers. Call this from anywhere a
  /// notification is surfaced to the vendor (e.g. NotificationWatcherService
  /// after polling GET /vendors/notifications) so it's always heard, whether
  /// it arrived via push or was picked up from the in-app notifications
  /// list.
  static void showLocalNotification({
    required int id,
    required String title,
    required String body,
    String type = 'system_alert',
  }) {
    final signature = '$type|$title|$body';
    final now = DateTime.now();
    final lastShown = _recentlyShown[signature];
    if (lastShown != null && now.difference(lastShown) < _dedupeWindow) {
      return;
    }
    _recentlyShown[signature] = now;
    _recentlyShown.removeWhere((_, shownAt) => now.difference(shownAt) > _dedupeWindow);

    final channel = _channelsByType[type] ?? _defaultChannel;
    final isOrderAlert = channel.id == _ordersChannelId;
    _localNotifications.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          audioAttributesUsage: isOrderAlert
              ? AudioAttributesUsage.alarm
              : AudioAttributesUsage.notification,
          enableVibration: true,
          vibrationPattern: isOrderAlert
              ? Int64List.fromList([0, 800, 400, 800, 400, 800, 400, 800])
              : null,
          fullScreenIntent: isOrderAlert,
          category: isOrderAlert ? AndroidNotificationCategory.alarm : null,
        ),
        iOS: DarwinNotificationDetails(
          presentSound: true,
          interruptionLevel: isOrderAlert
              ? InterruptionLevel.timeSensitive
              : InterruptionLevel.active,
        ),
      ),
    );
  }

  /// The sheet is now on screen and rings by itself — silence the tray alert
  /// (which would otherwise keep repeating its insistent sound).
  static Future<void> cancelOrderAlert(String orderId) async {
    try {
      final id = (int.tryParse(orderId) ?? orderId.hashCode) & 0x7fffffff;
      await _localNotifications.cancel(id);
    } catch (_) {}
  }

  /// Call after the vendor is logged in. Gets this device's FCM token and
  /// registers it with the backend so order-paid pushes can reach this
  /// device. Matches the real route: POST /vendors/push-token/register
  /// (vendorController.registerVendorPushToken).
  static bool _refreshListening = false;
  static DateTime? _lastRegisteredAt;

  static Future<void> registerTokenWithBackend() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      await ApiClient.dio.post('/vendors/push-token/register', data: {
        'token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
      });

      _lastRegisteredAt = DateTime.now();
      if (_refreshListening) return;
      _refreshListening = true;
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
  /// Cheap to call often: re-sends the token at most once an hour (e.g. on app resume).
  static Future<void> ensureRegistered() async {
    final last = _lastRegisteredAt;
    if (last != null && DateTime.now().difference(last) < const Duration(hours: 1)) return;
    await registerTokenWithBackend();
  }

  /// Ask the server to push a loud test alert to this phone after [delaySeconds]
  /// (lock the phone meanwhile). Returns a message to show the vendor.
  static Future<String> sendTestAlert({int delaySeconds = 10}) async {
    try {
      final res = await ApiClient.dio.post('/vendors/push-test', data: {'delay_seconds': delaySeconds});
      final n = res.data['active_devices'];
      return 'Test alert sends in $delaySeconds seconds to $n device(s). Lock your phone now.';
    } on DioException catch (e) {
      final msg = e.response?.data is Map ? e.response?.data['error'] : null;
      return (msg ?? 'Could not reach the server. Check your internet.').toString();
    } catch (_) {
      return 'Could not send the test alert.';
    }
  }

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