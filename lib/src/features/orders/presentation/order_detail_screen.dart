import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../data/order_model.dart';
import '../data/orders_api.dart';
import '../../../core/widgets/shared_widgets.dart';

class OrderDetailScreen extends StatefulWidget {
  final String id;
  const OrderDetailScreen({super.key, required this.id});
  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Order? _order;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final o = await OrdersApi.byId(widget.id);
      if (mounted)
        setState(() {
          _order = o;
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
    }
  }

  Future<void> _updateStatus(String status) async {
    try {
      await OrdersApi.updateStatus(widget.id, status);
      _load();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Status updated to $status'),
            backgroundColor: Colors.teal));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(_order != null ? _order!.orderNumber : 'Order Details'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load)
        ],
      ),
      body: _loading
          ? const AppLoading()
          : _error != null
              ? AppError(message: _error!, onRetry: _load)
              : _OrderDetail(order: _order!, onUpdateStatus: _updateStatus),
    );
  }
}

class _OrderDetail extends StatelessWidget {
  final Order order;
  final void Function(String) onUpdateStatus;
  const _OrderDetail({required this.order, required this.onUpdateStatus});

  static const _allStatuses = [
    'pending',
    'confirmed',
    'preparing',
    'ready',
    'dispatched',
    'delivered',
    'canceled'
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // FIX: totalAmount and deliveryFee are already doubles from Order.fromJson
    final subtotal = order.totalAmount - order.deliveryFee;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(order.orderNumber,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(_formatDate(order.createdAt),
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 13)),
                    ])),
                StatusBadge(status: order.orderStatus),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                _AmountBox(
                    label: 'Subtotal',
                    value: 'KES ${subtotal.toStringAsFixed(0)}',
                    color: cs.surfaceContainerLow),
                const SizedBox(width: 8),
                _AmountBox(
                    label: 'Delivery',
                    value: 'KES ${order.deliveryFee.toStringAsFixed(0)}',
                    color: cs.surfaceContainerLow),
                const SizedBox(width: 8),
                _AmountBox(
                    label: 'Total',
                    value: 'KES ${order.totalAmount.toStringAsFixed(0)}',
                    color: cs.primary.withOpacity(0.12),
                    bold: true),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: order.paymentStatus == 'paid'
                        ? Colors.green.shade50
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: order.paymentStatus == 'paid'
                            ? Colors.green
                            : Colors.orange),
                  ),
                  child: Text('Payment: ${order.paymentStatus}',
                      style: TextStyle(
                        fontSize: 12,
                        color: order.paymentStatus == 'paid'
                            ? Colors.green.shade700
                            : Colors.orange.shade700,
                        fontWeight: FontWeight.w600,
                      )),
                ),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        if (order.items.isNotEmpty) ...[
          const SectionHeader(title: 'Order Items'),
          Card(
              child: Column(
                  children: order.items.asMap().entries.map((e) {
            final i = e.key;
            final item = e.value;
            return Column(children: [
              if (i > 0) const Divider(height: 1),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                        color: cs.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8)),
                    alignment: Alignment.center,
                    child: Text('${item.quantity}×',
                        style: TextStyle(
                            color: cs.primary, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(item.productName,
                            style:
                                const TextStyle(fontWeight: FontWeight.w500)),
                        Text('KES ${item.unitPrice.toStringAsFixed(0)} each',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                      ])),
                  Text('KES ${item.totalPrice.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ]),
              ),
            ]);
          }).toList())),
        ],
        const SizedBox(height: 12),
        const SectionHeader(title: 'Delivery Info'),
        Card(
            child: Column(children: [
          if (order.deliveryAddress != null)
            InfoTile(
                icon: Icons.location_on_outlined,
                label: 'Address',
                value: order.deliveryAddress!),
          if (order.deliveryContact != null)
            InfoTile(
                icon: Icons.phone_outlined,
                label: 'Contact',
                value: order.deliveryContact!),
          if (order.riderName != null)
            InfoTile(
                icon: Icons.delivery_dining,
                label: 'Rider',
                value: order.riderName!),
          if (order.customerNote != null)
            InfoTile(
                icon: Icons.note_outlined,
                label: 'Note',
                value: order.customerNote!),
        ])),
        if (order.orderStatus != 'delivered' &&
            order.orderStatus != 'canceled' &&
            order.orderStatus != 'pending') ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/orders/${order.orderId}/track'),
              icon: const Icon(Icons.map_outlined),
              label: const Text('Track Delivery'),
            ),
          ),
        ],
        const SizedBox(height: 20),
        if (order.orderStatus != 'delivered' &&
            order.orderStatus != 'canceled') ...[
          const Text('Update Status',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.grey)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allStatuses
                .where((s) => s != order.orderStatus)
                .map((s) => ActionChip(
                      label: Text(_capitalize(s)),
                      onPressed: () => _confirmStatus(context, s),
                      backgroundColor:
                          s == 'canceled' ? Colors.red.shade50 : null,
                      labelStyle:
                          TextStyle(color: s == 'canceled' ? Colors.red : null),
                    ))
                .toList(),
          ),
          const SizedBox(height: 32),
        ],
      ],
    );
  }

  Future<void> _confirmStatus(BuildContext context, String status) async {
    final ok = await showConfirmDialog(context,
        title: 'Update Status',
        content: 'Change order to "${_capitalize(status)}"?',
        confirmLabel: 'Update',
        confirmColor: status == 'canceled' ? Colors.red : null);
    if (ok == true) onUpdateStatus(status);
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }
}

class _AmountBox extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool bold;
  const _AmountBox(
      {required this.label,
      required this.value,
      required this.color,
      this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration:
            BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
        child: Column(children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: bold ? FontWeight.bold : FontWeight.w500)),
        ]),
      ),
    );
  }
}
