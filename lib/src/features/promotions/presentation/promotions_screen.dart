import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/shared_widgets.dart';
import '../data/promotions_api.dart';

/// Read-only view of promotions currently running on AquaGas that apply
/// to this vendor. Promotions are managed centrally by the platform team —
/// vendors can see what's active and how it's performing, but creating or
/// editing promotions happens on the admin side, not here.
class PromotionsScreen extends StatefulWidget {
  const PromotionsScreen({super.key});

  @override
  State<PromotionsScreen> createState() => _PromotionsScreenState();
}

class _PromotionsScreenState extends State<PromotionsScreen> {
  List<VendorPromotion> _promotions = [];
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
      final promos = await PromotionsApi.list();
      if (!mounted) return;
      setState(() {
        _promotions = promos;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load promotions. Pull down to retry.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dateFmt = DateFormat('MMM d');

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Promotions'),
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
            ? const AppLoading(message: 'Loading promotions…')
            : _error != null
                ? AppError(message: _error!, onRetry: _load)
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: cs.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline,
                                color: cs.primary, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Promotions are set up by the AquaGas team. '
                                'These are the ones currently live that '
                                'apply to your store.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: cs.onSurface.withOpacity(0.75),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_promotions.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 60),
                          child: AppEmpty(
                            icon: Icons.local_offer_outlined,
                            message:
                                'No promotions are currently running for your store.',
                          ),
                        )
                      else
                        ..._promotions.map((promo) {
                          final usagePct = promo.totalUsageLimit != null &&
                                  promo.totalUsageLimit! > 0
                              ? (promo.currentUsageCount /
                                      promo.totalUsageLimit!)
                                  .clamp(0.0, 1.0)
                              : null;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: cs.primary.withOpacity(0.12),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          promo.code,
                                          style: TextStyle(
                                            color: cs.primary,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        promo.discountLabel,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    promo.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    promo.minimumOrderAmount > 0
                                        ? 'Min. order KES ${promo.minimumOrderAmount.toStringAsFixed(0)} • '
                                            'Valid until ${promo.validTo != null ? dateFmt.format(promo.validTo!) : 'further notice'}'
                                        : 'Valid until ${promo.validTo != null ? dateFmt.format(promo.validTo!) : 'further notice'}',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: cs.onSurface.withOpacity(0.6),
                                    ),
                                  ),
                                  if (usagePct != null) ...[
                                    const SizedBox(height: 10),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: usagePct,
                                        minHeight: 6,
                                        backgroundColor:
                                            cs.primary.withOpacity(0.1),
                                        color: cs.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${promo.currentUsageCount} / ${promo.totalUsageLimit} uses',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: cs.onSurface.withOpacity(0.5),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
      ),
    );
  }
}
