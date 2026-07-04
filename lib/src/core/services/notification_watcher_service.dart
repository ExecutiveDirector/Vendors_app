// lib/src/core/services/notification_watcher_service.dart
//
// Why this file exists:
//  FCM (see push_notification_service.dart) only ever pushes for "new paid
//  orders". Every other kind of notification the backend creates
//  (delivery_update, payment_update, promotional, system_alert, reminder,
//  ...) only ever lived in the `/vendors/notifications` table and, before
//  this file, only surfaced silently — as a badge count, or as a row in
//  NotificationsScreen if the vendor happened to have that screen open.
//  Nothing made a sound or showed up in the phone's notification shade.
//
// This service polls GET /vendors/notifications in the background — for as
// long as the app process is alive, independent of which screen is open —
// diffs against the highest notification_id it has already alerted the
// vendor about, and fires a real native notification (system tray + sound,
// via PushNotificationService.showLocalNotification) for every new one.
//
// Start once, right after a valid auth token exists (fresh login, or app
// launch when a token is already stored). Call reset() on logout so a
// different vendor logging in on the same device doesn't inherit the
// previous vendor's "already seen" watermark.

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../api/dio_client.dart';
import 'local_storage.dart';
import 'push_notification_service.dart';

/// Global unread notification count — listen from anywhere (app bar badges,
/// dashboard, etc.) with a ValueListenableBuilder.
final notificationUnreadCount = ValueNotifier<int>(0);

class NotificationWatcherService {
  NotificationWatcherService._();
  static final NotificationWatcherService instance =
      NotificationWatcherService._();

  static const _pollInterval = Duration(seconds: 30);
  static const _lastSeenKey = 'last_seen_notification_id';

  Timer? _timer;
  int _lastSeenId = 0;
  bool _watermarkLoaded = false;
  bool _needsBaseline = false;
  bool _polling = false;

  /// Begins polling immediately and then every [_pollInterval]. Safe to
  /// call multiple times (e.g. once at app launch, once after login) — it
  /// just restarts the timer.
  Future<void> start() async {
    if (!_watermarkLoaded) {
      final stored = await LocalStorage.getString(_lastSeenKey);
      if (stored == null) {
        // First time ever running on this device for this vendor: don't
        // blast every historic notification as a "new" push. Establish a
        // baseline on the first poll instead, then alert only for
        // anything after that.
        _needsBaseline = true;
        _lastSeenId = 0;
      } else {
        _lastSeenId = int.tryParse(stored) ?? 0;
      }
      _watermarkLoaded = true;
    }

    _timer?.cancel();
    unawaited(_poll());
    _timer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Call on logout — stops polling and wipes the in-memory watermark so
  /// the next vendor to log in on this device gets a clean baseline
  /// (LocalStorage.clearAll() on logout already wipes the persisted key).
  void reset() {
    stop();
    _lastSeenId = 0;
    _watermarkLoaded = false;
    _needsBaseline = false;
    notificationUnreadCount.value = 0;
  }

  Future<void> _poll() async {
    if (_polling) return; // avoid overlapping polls if one is slow
    _polling = true;
    try {
      final res = await ApiClient.dio.get('/vendors/notifications',
          queryParameters: {'page': 1, 'limit': 100});
      final data = res.data;
      final List<dynamic> raw = data is Map
          ? (data['notifications'] as List? ?? [])
          : (data as List? ?? []);

      var unread = 0;
      var highestId = _lastSeenId;
      final newItems = <Map<String, dynamic>>[];

      for (final entry in raw) {
        if (entry is! Map) continue;
        final item = Map<String, dynamic>.from(entry);
        final id = _asInt(item['notification_id']);
        final isRead = item['is_read'] == 1 || item['is_read'] == true;
        if (!isRead) unread++;
        if (id > highestId) highestId = id;
        if (id > _lastSeenId) newItems.add(item);
      }

      notificationUnreadCount.value = unread;

      if (_needsBaseline) {
        // First-ever poll on this device: just record the watermark,
        // don't fire a flood of notifications for pre-existing history.
        _needsBaseline = false;
        _lastSeenId = highestId;
        await LocalStorage.setString(_lastSeenKey, _lastSeenId.toString());
        return;
      }

      if (newItems.isEmpty) return;

      // Oldest first, so they land in the notification shade in the order
      // they actually happened.
      newItems.sort((a, b) =>
          _asInt(a['notification_id']).compareTo(_asInt(b['notification_id'])));

      for (final item in newItems) {
        final title = (item['title'] as String?)?.trim();
        PushNotificationService.showLocalNotification(
          id: _asInt(item['notification_id']),
          title: (title == null || title.isEmpty) ? 'New notification' : title,
          body: (item['message'] as String?) ?? '',
          type: (item['notification_type'] as String?) ?? 'system_alert',
        );
      }

      _lastSeenId = highestId;
      await LocalStorage.setString(_lastSeenKey, _lastSeenId.toString());
    } catch (e) {
      debugPrint('⚠️ NotificationWatcherService poll failed: $e');
    } finally {
      _polling = false;
    }
  }

  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }
}