// lib/src/features/tracking/presentation/track_order_screen.dart
//
// Live order tracking for the AquaGas vendor app.
// • Fetches the order via OrdersApi.byId, then polls via OrdersApi.trackOrder
// • Shows delivery destination on a map (flutter_map / OpenStreetMap —
//   no API key required, unlike google_maps_flutter, which isn't wired
//   into this app's Android/iOS build config)
// • Shows rider name, phone, and tap-to-call once a rider is assigned
// • Uses the AquaGas green palette throughout
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/shared_widgets.dart';
import '../../orders/data/order_model.dart';
import '../../orders/data/orders_api.dart';

class TrackOrderScreen extends StatefulWidget {
  final String orderId;
  const TrackOrderScreen({super.key, required this.orderId});

  @override
  State<TrackOrderScreen> createState() => _TrackOrderScreenState();
}

class _TrackOrderScreenState extends State<TrackOrderScreen> {
  Order? _order;
  bool _loading = true;
  String? _error;
  StreamSubscription<Order>? _sub;
  final MapController _mapController = MapController();

  // Default centre when an order has no delivery coordinates yet: Nairobi CBD.
  static const LatLng _kNairobi = LatLng(-1.2921, 36.8219);

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _start() {
    _sub = OrdersApi.trackOrder(widget.orderId, interval: 8).listen(
      (order) {
        if (!mounted) return;
        final wasLoading = _loading;
        setState(() {
          _order = order;
          _loading = false;
          _error = null;
        });
        // Recenter the map the first time we get real coordinates, but
        // don't fight the vendor if they've panned around since.
        if (wasLoading && order.hasDeliveryLocation) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _mapController.move(
              LatLng(order.deliveryLatitude!, order.deliveryLongitude!),
              15,
            );
          });
        }
      },
      onError: (e) {
        if (!mounted) return;
        if (_order == null) {
          setState(() {
            _error = 'Could not load this order.';
            _loading = false;
          });
        }
        // If we already have an order on screen, a single failed poll is
        // silent — the next poll will likely succeed.
      },
    );
  }

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Color _statusColor(BuildContext context, String status) {
    final cs = Theme.of(context).colorScheme;
    switch (status.toLowerCase()) {
      case 'delivered':
        return const Color(0xFF059669);
      case 'dispatched':
        return cs.primary;
      case 'preparing':
      case 'confirmed':
      case 'ready':
        return const Color(0xFF0EA5E9);
      case 'canceled':
      case 'cancelled':
        return const Color(0xFFEF4444);
      default:
        return Colors.grey;
    }
  }

  IconData _vehicleIcon(String? type) {
    switch (type) {
      case 'bicycle':
        return Icons.pedal_bike;
      case 'tuk_tuk':
        return Icons.airport_shuttle;
      case 'van':
      case 'pickup':
        return Icons.local_shipping;
      default:
        return Icons.two_wheeler;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            const Text('Live Tracking'),
          ],
        ),
      ),
      body: _loading
          ? const AppLoading(message: 'Loading order…')
          : _error != null && _order == null
              ? AppError(message: _error!, onRetry: _start)
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final order = _order!;
    final target = order.hasDeliveryLocation
        ? LatLng(order.deliveryLatitude!, order.deliveryLongitude!)
        : _kNairobi;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: target,
            initialZoom: 14,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.aquagas.vendorapp',
            ),
            if (order.hasDeliveryLocation)
              MarkerLayer(markers: [
                Marker(
                  point: target,
                  width: 44,
                  height: 44,
                  child: Icon(
                    Icons.location_pin,
                    color: Theme.of(context).colorScheme.primary,
                    size: 44,
                  ),
                ),
              ]),
          ],
        ),

        if (!order.hasDeliveryLocation)
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 8),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No delivery location on file for this order yet.',
                      style: TextStyle(fontSize: 12.5, color: Colors.grey[700]),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Recenter FAB
        Positioned(
          right: 16,
          bottom: 300,
          child: FloatingActionButton.small(
            heroTag: 'recenter',
            backgroundColor: Colors.white,
            onPressed: () => _mapController.move(target, 15),
            child: Icon(Icons.my_location,
                color: Theme.of(context).colorScheme.primary),
          ),
        ),

        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _InfoPanel(
            order: order,
            statusColor: _statusColor(context, order.orderStatus),
            vehicleIcon: _vehicleIcon(order.riderVehicleType),
            onCallRider: order.riderPhone != null
                ? () => _call(order.riderPhone!)
                : null,
          ),
        ),
      ],
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.order,
    required this.statusColor,
    required this.vehicleIcon,
    this.onCallRider,
  });

  final Order order;
  final Color statusColor;
  final IconData vehicleIcon;
  final VoidCallback? onCallRider;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currencyFmt =
        NumberFormat.currency(locale: 'en_KE', symbol: 'KES ', decimalDigits: 0);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.local_fire_department_outlined,
                    color: cs.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order ${order.orderNumber}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    Text(
                      order.deliveryAddress ?? 'No address on file',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: cs.onSurface.withOpacity(0.6), fontSize: 13),
                    ),
                  ],
                ),
              ),
              Text(
                currencyFmt.format(order.grandTotal),
                style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 15, color: cs.primary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.circle, size: 10, color: statusColor),
              const SizedBox(width: 8),
              Text(order.displayStatus,
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: statusColor)),
              const Spacer(),
              if (order.deliveryContact != null)
                Text(order.deliveryContact!,
                    style: TextStyle(
                        fontSize: 12.5, color: cs.onSurface.withOpacity(0.6))),
            ],
          ),

          if (order.riderName != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: cs.primary,
                    child: Icon(vehicleIcon, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Rider',
                            style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurface.withOpacity(0.5),
                                fontWeight: FontWeight.w500)),
                        Text(order.riderName!,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                      ],
                    ),
                  ),
                  if (onCallRider != null)
                    GestureDetector(
                      onTap: onCallRider,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration:
                            BoxDecoration(color: cs.primary, shape: BoxShape.circle),
                        child: const Icon(Icons.phone, color: Colors.white, size: 18),
                      ),
                    ),
                ],
              ),
            ),
          ] else if (order.orderStatus != 'delivered' &&
              order.orderStatus != 'canceled') ...[
            const SizedBox(height: 14),
            Text(
              'No rider assigned yet.',
              style: TextStyle(fontSize: 12.5, color: cs.onSurface.withOpacity(0.5)),
            ),
          ],
        ],
      ),
    );
  }
}
