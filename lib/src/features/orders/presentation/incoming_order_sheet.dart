// lib/src/features/orders/presentation/incoming_order_sheet.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/order_model.dart';
import '../data/orders_api.dart';
import '../../../core/widgets/shared_widgets.dart';

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
    _beep();
    _ring = Timer.periodic(const Duration(seconds: 4), (_) => _beep());
    _clock = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  void _beep() {
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.heavyImpact();
  }

  @override
  void dispose() {
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
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await OrdersApi.updateStatus(widget.order.orderId, 'confirmed');
      if (mounted) Navigator.pop(context, IncomingOrderResult.accepted);
    } catch (e) {
      // Most likely already accepted/cancelled elsewhere.
      if (mounted) {
        setState(() {
          _busy = false;
          _error = "Couldn't accept this order. It may have changed — check Orders.";
        });
      }
    }
  }

  Future<void> _decline() async {
    final reason = await askCancelReason(context,
        paid: widget.order.paymentStatus.toLowerCase() == 'paid');
    if (reason == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await OrdersApi.updateStatus(widget.order.orderId, 'canceled',
          reason: reason);
      if (mounted) Navigator.pop(context, IncomingOrderResult.declined);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = "Couldn't decline this order. Check Orders.";
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
                Row(
                  children: [
                    const Icon(Icons.notifications_active, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('New order ${o.orderNumber}',
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800)),
                    ),
                    Text(_waiting, style: theme.textTheme.bodySmall),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: o.isCod ? Colors.amber.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(o.isCod ? Icons.payments_outlined : Icons.verified,
                          color: o.isCod ? Colors.amber.shade800 : Colors.green),
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
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : _decline,
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            minimumSize: const Size.fromHeight(52)),
                        child: const Text('Decline'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: _busy ? null : _accept,
                        style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52)),
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
