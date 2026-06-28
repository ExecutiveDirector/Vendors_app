// subscriptions_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/subscriptions_api.dart';
import './subscription_plan.dart';
import '../../../core/widgets/shared_widgets.dart';

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  List<SubscriptionPlan> _plans = [];
  bool _loading = true;
  String? _error;
  int? _activePlanId;
  int? _subscriptionId;
  int? _inFlightPlanId;

  @override
  void initState() {
    super.initState();
    _fetchPlans();
  }

  Future<void> _fetchPlans() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final plansData = await SubscriptionsApi.getPlans();
      final plans =
          plansData.map((json) => SubscriptionPlan.fromJson(json)).toList();
      final current = await SubscriptionsApi.getCurrent();

      setState(() {
        _plans = plans;
        _subscriptionId = current?['id'];
        _activePlanId = current?['plan_id'];
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  String _formatCurrency(double amount) =>
      NumberFormat.simpleCurrency(locale: 'en_KE', name: 'KSh').format(amount);

  Future<void> _subscribe(SubscriptionPlan plan) async {
    final confirm = await _confirmDialog(
      'Subscribe to ${plan.planName}?',
      'You will be charged ${_formatCurrency(plan.price ?? 0)}.',
    );
    if (!confirm) return;

    setState(() => _inFlightPlanId = plan.planId);
    try {
      await SubscriptionsApi.subscribe(plan.planId.toString());
      // Refresh to get updated subscription info
      await _fetchPlans();
      if (mounted) _showSnackbar('Subscribed to ${plan.planName}');
    } catch (e) {
      if (mounted) _showSnackbar('Subscription failed: $e');
    } finally {
      if (mounted) setState(() => _inFlightPlanId = null);
    }
  }

  Future<void> _upgrade(SubscriptionPlan plan) async {
    if (_subscriptionId == null) {
      _showSnackbar('You have no active subscription.');
      return;
    }

    final confirm = await _confirmDialog(
      'Change to ${plan.planName}?',
      "You'll be moved to this plan immediately.",
    );

    if (!confirm) return;

    setState(() => _inFlightPlanId = plan.planId);
    try {
      await SubscriptionsApi.changeSubscription(_subscriptionId!, plan.planId);
      setState(() => _activePlanId = plan.planId);
      if (mounted) _showSnackbar('Plan changed successfully.');
    } catch (e) {
      if (mounted) _showSnackbar('Upgrade failed: $e');
    } finally {
      if (mounted) setState(() => _inFlightPlanId = null);
    }
  }

  Future<void> _cancel() async {
    if (_subscriptionId == null) {
      _showSnackbar('No active subscription to cancel.');
      return;
    }

    final confirm = await _confirmDialog(
      'Cancel Subscription?',
      'This will stop your current plan.',
    );
    if (!confirm) return;

    setState(() => _loading = true);
    try {
      await SubscriptionsApi.cancel();
      setState(() {
        _subscriptionId = null;
        _activePlanId = null;
      });
      if (mounted) _showSnackbar('Subscription cancelled.');
    } catch (e) {
      if (mounted) _showSnackbar('Cancel failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _confirmDialog(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('No'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Yes'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Subscriptions'),
        actions: [
          if (_subscriptionId != null)
            TextButton(
              onPressed: _cancel,
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.white)),
            ),
          IconButton(
            onPressed: _fetchPlans,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error: $_error', textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchPlans,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _plans.isEmpty
                  ? const Center(
                      child: Text('No subscription plans available'),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchPlans,
                      child: GridView.count(
                        padding: const EdgeInsets.all(12),
                        crossAxisCount: isWide ? 3 : 1,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: isWide ? 0.8 : 1.2,
                        children: _plans.map(_buildPlanCard).toList(),
                      ),
                    ),
    );
  }

  Widget _buildPlanCard(SubscriptionPlan plan) {
    final isActive = _activePlanId == plan.planId;
    final inFlight = _inFlightPlanId == plan.planId;
    final recommended = plan.discountPercentage >= 10;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.green.shade50
            : recommended
                ? Colors.orange.shade50
                : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          width: isActive ? 2 : 1,
          color: isActive
              ? Colors.green
              : recommended
                  ? Colors.orange
                  : Colors.grey.shade300,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Plan header
          Row(
            children: [
              Expanded(
                child: Text(
                  plan.planName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              if (recommended)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'BEST VALUE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Price
          Text(
            plan.price != null
                ? _formatCurrency(plan.price!)
                : 'Custom pricing',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),

          // Frequency
          Text(
            'Every ${plan.frequencyInterval} ${plan.frequency.toLowerCase()}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),

          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),

          // Benefits
          if (plan.discountPercentage > 0)
            _buildBenefit(
              Icons.discount,
              '${plan.discountPercentage.toStringAsFixed(0)}% discount',
            ),
          if (plan.freeDelivery)
            _buildBenefit(Icons.local_shipping, 'Free delivery'),
          if (plan.prioritySupport)
            _buildBenefit(Icons.support_agent, 'Priority support'),
          if (plan.minimumOrderValue > 0)
            _buildBenefit(
              Icons.shopping_cart,
              'Min. order: ${_formatCurrency(plan.minimumOrderValue)}',
            ),

          const Spacer(),

          // Action button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: inFlight || isActive
                  ? null
                  : () {
                      if (_subscriptionId == null) {
                        _subscribe(plan);
                      } else {
                        _upgrade(plan);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: isActive ? Colors.green : null,
                disabledBackgroundColor: isActive ? Colors.green : null,
              ),
              child: inFlight
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      isActive
                          ? 'Active Plan'
                          : _subscriptionId == null
                              ? 'Subscribe'
                              : 'Change Plan',
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefit(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
