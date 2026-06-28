import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/shared_widgets.dart';
import '../data/riders_api.dart';

/// Shows riders currently delivering this vendor's active orders.
///
/// There's no vendor-managed rider roster in this platform (riders are
/// shared/assigned by the system across vendors), so this is intentionally
/// "who's out delivering for me right now" rather than a staff directory.
class RidersScreen extends StatefulWidget {
  const RidersScreen({super.key});

  @override
  State<RidersScreen> createState() => _RidersScreenState();
}

class _RidersScreenState extends State<RidersScreen> {
  List<ActiveRider> _riders = [];
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
      final riders = await VendorRidersApi.listActive();
      if (!mounted) return;
      setState(() {
        _riders = riders;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load riders. Pull down to retry.';
        _loading = false;
      });
    }
  }

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  IconData _vehicleIcon(String type) {
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
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Riders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const AppLoading(message: 'Loading active riders…')
            : _error != null
                ? AppError(message: _error!, onRetry: _load)
                : _riders.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 80),
                          AppEmpty(
                            icon: Icons.pedal_bike_outlined,
                            message:
                                'No riders are currently delivering your orders.\nThey\'ll show up here once one is assigned.',
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: _riders.length,
                        itemBuilder: (context, i) {
                          final rider = _riders[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: cs.primary.withOpacity(0.12),
                                    child: Icon(
                                      _vehicleIcon(rider.vehicleType),
                                      color: cs.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                rider.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ),
                                            StatusBadge(
                                                status: rider.currentStatus),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${rider.vehicleType.replaceAll('_', ' ')} • ${rider.rating.toStringAsFixed(1)} ★ • ${rider.totalDeliveries} deliveries',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: cs.onSurface.withOpacity(0.6),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: [
                                            Chip(
                                              visualDensity:
                                                  VisualDensity.compact,
                                              materialTapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                              label: Text(
                                                rider.activeOrderCount == 1
                                                    ? 'Order ${rider.orderNumbers.first}'
                                                    : '${rider.activeOrderCount} of your orders',
                                                style: const TextStyle(
                                                    fontSize: 11.5),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (rider.phone != null &&
                                      rider.phone!.isNotEmpty)
                                    IconButton(
                                      onPressed: () => _call(rider.phone!),
                                      icon: Icon(Icons.phone,
                                          color: cs.primary),
                                      tooltip: 'Call ${rider.name}',
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
