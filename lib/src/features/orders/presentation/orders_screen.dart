import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../data/order_model.dart';
import '../data/orders_api.dart';
import '../../../core/widgets/shared_widgets.dart';

// FIX: safe numeric helpers — API may return money as String ("1700.00")
double _safeDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _statuses = [
    'all',
    'pending',
    'confirmed',
    'preparing',
    'dispatched',
    'delivered'
  ];
  final _statusLabels = [
    'All',
    'Pending',
    'Confirmed',
    'Preparing',
    'Dispatched',
    'Delivered'
  ];
  List<Order> _all = [];
  bool _loading = true;
  String? _error;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _statuses.length, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await OrdersApi.list();
      if (mounted)
        setState(() {
          _all = data;
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

  List<Order> _forStatus(String status) {
    var list = status == 'all'
        ? _all
        : _all.where((o) => o.orderStatus == status).toList();
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list
          .where((o) =>
              o.orderNumber.toLowerCase().contains(q) ||
              (o.deliveryContact?.toLowerCase().contains(q) ?? false))
          .toList();
    }
    return list;
  }

  int _count(String status) => status == 'all'
      ? _all.length
      : _all.where((o) => o.orderStatus == status).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Orders'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load)
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: List.generate(
              _statuses.length,
              (i) => Tab(
                    child: Row(children: [
                      Text(_statusLabels[i]),
                      const SizedBox(width: 4),
                      if (!_loading)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(_count(_statuses[i]).toString(),
                              style: TextStyle(
                                  fontSize: 11,
                                  color:
                                      Theme.of(context).colorScheme.primary)),
                        ),
                    ]),
                  )),
        ),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: const InputDecoration(
              hintText: 'Search orders...',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const AppLoading()
              : _error != null
                  ? AppError(message: _error!, onRetry: _load)
                  : TabBarView(
                      controller: _tabs,
                      children: _statuses
                          .map((s) => _OrderList(
                              orders: _forStatus(s), onRefresh: _load))
                          .toList(),
                    ),
        ),
      ]),
    );
  }
}

class _OrderList extends StatelessWidget {
  final List<Order> orders;
  final VoidCallback onRefresh;
  const _OrderList({required this.orders, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const AppEmpty(
          icon: Icons.receipt_long_outlined, message: 'No orders found.');
    }
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        itemCount: orders.length,
        itemBuilder: (_, i) =>
            _OrderCard(order: orders[i], onRefresh: onRefresh),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback onRefresh;
  const _OrderCard({required this.order, required this.onRefresh});

  static const _nextStatus = {
    'pending': 'confirmed',
    'confirmed': 'preparing',
    'preparing': 'ready',
    'ready': 'dispatched',
    'dispatched': 'delivered',
  };
  static const _nextLabel = {
    'pending': 'Confirm',
    'confirmed': 'Start Preparing',
    'preparing': 'Mark Ready',
    'ready': 'Dispatch',
    'dispatched': 'Mark Delivered',
  };

  Future<void> _advance(BuildContext context, String next) async {
    try {
      await OrdersApi.updateStatus(order.orderId, next);
      onRefresh();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Order ${order.orderNumber} → $next'),
          backgroundColor: Colors.teal,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final next = _nextStatus[order.orderStatus];
    final nextLabel = _nextLabel[order.orderStatus];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => context.push('/orders/${order.orderId}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text(order.orderNumber,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15))),
              StatusBadge(status: order.orderStatus),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(_formatDate(order.createdAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const Spacer(),
              // FIX: totalAmount is already a double from Order.fromJson — safe to use directly
              Text('KES ${order.totalAmount.toStringAsFixed(0)}',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                      fontSize: 15)),
            ]),
            if (order.deliveryAddress != null || order.deliveryContact != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(children: [
                  Icon(Icons.location_on_outlined,
                      size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Expanded(
                      child: Text(
                    order.deliveryAddress ?? order.deliveryContact ?? '',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )),
                  if (order.orderStatus != 'delivered' &&
                      order.orderStatus != 'canceled' &&
                      order.orderStatus != 'pending')
                    InkWell(
                      onTap: () =>
                          context.push('/orders/${order.orderId}/track'),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Row(children: [
                          Icon(Icons.map_outlined, size: 14, color: cs.primary),
                          const SizedBox(width: 3),
                          Text('Track',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: cs.primary,
                                  fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ),
                ]),
              ),
            if (order.items.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  order.items
                      .map((i) => '${i.quantity}× ${i.productName}')
                      .join(', '),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (next != null && nextLabel != null) ...[
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: OutlinedButton(
                  onPressed: () => context.push('/orders/${order.orderId}'),
                  child: const Text('View Details'),
                )),
                const SizedBox(width: 8),
                Expanded(
                    child: ElevatedButton(
                  onPressed: () => _advance(context, next),
                  child: Text(nextLabel),
                )),
              ]),
            ],
          ]),
        ),
      ),
    );
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }
}
