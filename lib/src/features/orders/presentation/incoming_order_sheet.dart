// lib/src/features/orders/presentation/incoming_order_sheet.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import '../../../core/services/order_alert_sound_service.dart';
import '../../../core/services/push_notification_service.dart';
import '../data/order_model.dart';
import '../data/orders_api.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../core/theme.dart';

enum IncomingOrderResult { accepted, declined, later }

/// New-order sheet: what was ordered, how much, how it's paid, then
/// Accept / Decline. Rings (system alert sound + haptics) until acted on.
class IncomingOrderSheet extends StatefulWidget {
  final Order order;
  const IncomingOrderSheet({super.key, required this.order});

  @override
  State<IncomingOrderSheet> createState() => _IncomingOrderSheetState();
}

class _IncomingOrderSheetState extends State<IncomingOrderSheet> {
  Timer? _ring;
  Timer? _clock;
  bool _busy = false;
  String? _error;
  late final DateTime _placedAt;

  @override
  void initState() {
    super.initState();
    _placedAt = DateTime.tryParse(widget.order.createdAt)?.toLocal() ??
        DateTime.now();
    OrderAlertSoundService.instance.play(); // looping alarm until the vendor acts
    _ring = Timer.periodic(const Duration(seconds: 4), (_) => HapticFeedback.heavyImpact());
    _clock = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    OrderAlertSoundService.instance.stop();
    _ring?.cancel();
    _clock?.cancel();
    super.dispose();
  }

  String get _waiting {
    final m = DateTime.now().difference(_placedAt).inMinutes;
    if (m < 1) return 'Just now';
    return '$m min ago';
  }

  Future<void> _accept() async {
    OrderAlertSoundService.instance.stop();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await OrdersApi.updateStatus(widget.order.orderId, 'confirmed');
      _close(IncomingOrderResult.accepted);
    } catch (e) {
      // The request may have succeeded even though the reply failed (slow
      // network), or someone else handled the order. Ask the server before
      // telling the vendor it failed, so the sheet never lingers on a done order.
      if (await _alreadyHandled()) {
        _close(IncomingOrderResult.accepted);
        return;
      }
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _messageFrom(e) ??
              "Couldn't accept this order. Check your connection and try again.";
        });
      }
    }
  }

  /// True when the order is no longer waiting for the vendor.
  Future<bool> _alreadyHandled() async {
    try {
      final fresh = await OrdersApi.byId(widget.order.orderId);
      return !fresh.needsVendorAction;
    } catch (_) {
      return false;
    }
  }

  String? _messageFrom(Object e) {
    if (e is DioException) {
      final d = e.response?.data;
      if (d is Map && d['error'] != null) return d['error'].toString();
    }
    return null;
  }

  void _close(IncomingOrderResult result) {
    OrderAlertSoundService.instance.stop();
    PushNotificationService.cancelOrderAlert(widget.order.orderId);
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(result);
  }

  Future<void> _decline() async {
    final reason = await askCancelReason(context,
        paid: widget.order.paymentStatus.toLowerCase() == 'paid');
    if (reason == null) return;
    OrderAlertSoundService.instance.stop();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await OrdersApi.updateStatus(widget.order.orderId, 'canceled',
          reason: reason);
      _close(IncomingOrderResult.declined);
    } catch (e) {
      if (await _alreadyHandled()) {
        _close(IncomingOrderResult.declined);
        return;
      }
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _messageFrom(e) ?? "Couldn't decline this order. Check Orders.";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  liveRegion: true,
                  label: 'New order ${o.orderNumber}',
                  child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: AppColors.warningSoft,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.notifications_active,
                          color: AppColors.warning),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('New order ${o.orderNumber}',
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800)),
                    ),
                    Text(_waiting, style: theme.textTheme.bodySmall),
                  ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: o.isCod ? AppColors.warningSoft : AppColors.successSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(o.isCod ? Icons.payments_outlined : Icons.verified,
                          color: o.isCod ? AppColors.warning : AppColors.success),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          o.isCod
                              ? 'Cash on delivery — KES ${o.totalAmount.toStringAsFixed(0)} collected by the rider'
                              : 'Paid — KES ${o.totalAmount.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                for (final i in o.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Text('${i.quantity} ×  ',
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        Expanded(child: Text(i.productName)),
                        Text('KES ${i.totalPrice.toStringAsFixed(0)}'),
                      ],
                    ),
                  ),
                if (o.deliveryAddress != null &&
                    o.deliveryAddress!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.place_outlined, size: 18),
                      const SizedBox(width: 6),
                      Expanded(child: Text(o.deliveryAddress!)),
                    ],
                  ),
                ],
                if (o.customerNote != null && o.customerNote!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Note: ${o.customerNote}',
                      style: theme.textTheme.bodySmall),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: const TextStyle(color: AppColors.danger)),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : _decline,
                        style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            minimumSize: const Size.fromHeight(56)),
                        child: const Text('Decline'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: _busy ? null : _accept,
                        style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(56)),
                        child: _busy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: Colors.white))
                            : const Text('Accept order'),
                      ),
                    ),
                  ],
                ),
                Center(
                  child: TextButton(
                    onPressed: _busy
                        ? null
                        : () =>
                            Navigator.pop(context, IncomingOrderResult.later),
                    child: const Text('Remind me in 1 minute'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
