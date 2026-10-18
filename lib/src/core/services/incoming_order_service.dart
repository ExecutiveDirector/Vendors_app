// lib/src/core/services/incoming_order_service.dart
//
// Raises the "New order — Accept / Decline" sheet, like the rider app's job
// offer. Sources: foreground/background pushes and alert taps (showFor), plus
// a short poll of pending orders so an order is never missed when a push is
// delayed, and on resume after the phone was asleep.
//
// Start after login, reset on logout.

import 'dart:async';
import 'package:flutter/material.dart';
import '../navigation/app_navigator_key.dart';
import 'push_notification_service.dart';
import '../../features/orders/data/order_model.dart';
import '../../features/orders/data/orders_api.dart';
import '../../features/orders/presentation/incoming_order_sheet.dart';

class IncomingOrderService with WidgetsBindingObserver {
  IncomingOrderService._();
  static final IncomingOrderService instance = IncomingOrderService._();

  static const _pollInterval = Duration(seconds: 8);
  static const _snooze = Duration(seconds: 60);

  Timer? _timer;
  bool _observing = false;
  bool _showing = false;
  bool _polling = false;
  bool _active = false;

  /// orderId -> don't show again before this time (Later / just handled).
  final Map<String, DateTime> _hiddenUntil = {};
  final List<Order> _queue = [];
  String? _pendingPushId; // alert tapped before the UI/login was ready

  void start() {
    _active = true;
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
    _timer?.cancel();
    unawaited(_poll());
    _timer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  void reset() {
    _active = false;
    _timer?.cancel();
    _timer = null;
    _queue.clear();
    _hiddenUntil.clear();
    _pendingPushId = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _active) {
      unawaited(_poll());
      unawaited(PushNotificationService.ensureRegistered());
    }
  }

  /// A push / alert tap named this order: fetch it and raise the sheet now.
  Future<void> showFor(String? orderId) async {
    if (orderId == null || orderId.isEmpty) return;
    if (!_active) {
      _pendingPushId = orderId; // not logged in yet; picked up by start()'s poll
      return;
    }
    try {
      final order = await OrdersApi.byId(orderId);
      if (order.needsVendorAction) {
        _hiddenUntil.remove(order.orderId); // an explicit tap overrides snooze
        _enqueue(order);
      }
    } catch (_) {
      unawaited(_poll());
    }
  }

  Future<void> _poll() async {
    if (_polling || !_active) return;
    _polling = true;
    try {
      final pushId = _pendingPushId;
      _pendingPushId = null;
      if (pushId != null) {
        try {
          final o = await OrdersApi.byId(pushId);
          if (o.needsVendorAction) _enqueue(o);
        } catch (_) {}
      }
      final pending = await OrdersApi.list(status: 'pending');
      final now = DateTime.now();
      for (final o in pending.where((o) => o.needsVendorAction)) {
        final until = _hiddenUntil[o.orderId];
        if (until != null && now.isBefore(until)) continue;
        _enqueue(o);
      }
    } catch (_) {
      // Offline etc. — the next tick retries.
    } finally {
      _polling = false;
    }
  }

  void _enqueue(Order order) {
    if (_queue.any((o) => o.orderId == order.orderId)) return;
    _queue.add(order);
    _showNext();
  }

  Future<void> _showNext() async {
    if (_showing || _queue.isEmpty) return;
    final context = appNavigatorKey.currentContext;
    if (context == null) return; // UI not mounted yet; the next poll retries
    _showing = true;
    final order = _queue.removeAt(0);
    unawaited(PushNotificationService.cancelOrderAlert(order.orderId));
    try {
      final result = await showModalBottomSheet<IncomingOrderResult>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        useRootNavigator: true,
        builder: (_) => IncomingOrderSheet(order: order),
      );
      // Accepted/declined orders leave 'pending'; "Later" or a failed action
      // snoozes so the sheet doesn't instantly reopen in a loop.
      _hiddenUntil[order.orderId] = DateTime.now().add(
          result == IncomingOrderResult.later || result == null
              ? _snooze
              : const Duration(minutes: 10));
    } finally {
      _showing = false;
      if (_queue.isNotEmpty) unawaited(_showNext());
    }
  }
}
