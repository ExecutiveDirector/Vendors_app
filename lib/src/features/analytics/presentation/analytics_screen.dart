import 'package:flutter/material.dart';
import '../data/analytics_api.dart';
import '../../../core/widgets/shared_widgets.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  AnalyticsSummary? _summary;

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final summary = await AnalyticsApi.summary();

      setState(() {
        _summary = summary;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _loading = true;
                _error = null;
              });

              _load();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _error != null
              ? _ErrorView(
                  error: _error!,
                  onRetry: () {
                    setState(() {
                      _loading = true;
                      _error = null;
                    });

                    _load();
                  },
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _section(
                        'Overview',
                        [
                          _StatCard(
                            label: 'Total Orders',
                            value: '${_summary?.orderCount ?? 0}',
                            icon: Icons.receipt_long,
                            color: cs.primary,
                          ),
                          _StatCard(
                            label: 'Revenue',
                            value: _formatCurrency(_summary?.revenue ?? 0),
                            icon: Icons.attach_money,
                            color: Colors.green,
                          ),
                          _StatCard(
                            label: 'Period',
                            value: (_summary?.period ?? 'month').toUpperCase(),
                            icon: Icons.calendar_month,
                            color: Colors.orange,
                          ),
                          _StatCard(
                            label: 'Start Date',
                            value: _summary?.startDate != null
                                ? _formatDate(_summary!.startDate!)
                                : '—',
                            icon: Icons.date_range,
                            color: cs.tertiary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _InfoCard(
                        title: 'Analytics Period',
                        value: _summary?.period ?? 'All time',
                      ),
                      if (_summary?.startDate != null)
                        _InfoCard(
                          title: 'From',
                          value: _formatDate(_summary!.startDate!),
                        ),
                      const SizedBox(height: 20),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Insights',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              _InsightTile(
                                icon: Icons.trending_up,
                                title: 'Sales Performance',
                                subtitle:
                                    'Your store analytics are based on delivered orders.',
                              ),
                              const Divider(),
                              _InsightTile(
                                icon: Icons.bar_chart,
                                title: 'Revenue Tracking',
                                subtitle:
                                    'Revenue is automatically calculated from successful orders.',
                              ),
                              const Divider(),
                              _InsightTile(
                                icon: Icons.inventory_2_outlined,
                                title: 'Product Analytics',
                                subtitle:
                                    'Top-selling products can be integrated from /analytics/products.',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  String _formatCurrency(dynamic val) {
    if (val == null) return '—';

    final n = double.tryParse(val.toString()) ?? 0;

    return 'KES ${n.toStringAsFixed(0)}';
  }

  String _formatDate(dynamic val) {
    try {
      if (val is DateTime) {
        return val.toLocal().toString().substring(0, 10);
      }

      return DateTime.parse(val.toString())
          .toLocal()
          .toString()
          .substring(0, 10);
    } catch (_) {
      return val.toString();
    }
  }

  Widget _section(
    String title,
    List<Widget> cards,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.5,
          children: cards,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: color,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String value;

  const _InfoCard({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

class _InsightTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _InsightTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red,
            ),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
