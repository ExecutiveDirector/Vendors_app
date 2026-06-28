// lib/src/features/dashboard/presentation/vendor_dashboard.dart
//
// Redesigned with:
//  • Material 3 design language
//  • Greeting + hero header with gradient
//  • Premium 2×2 KPI cards
//  • Horizontal quick-action chips
//  • Modern order cards
//  • Shimmer skeleton loader
//  • Cleaner spacing system

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/services/local_storage.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../notifications/presentation/notifications_screen.dart'
    show notificationUnreadCount;

// ── Numeric helpers ──────────────────────────────────────────────────────────
double _safeDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

int _safeInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is double) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

// ── Greeting helper ──────────────────────────────────────────────────────────
String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good Morning 👋';
  if (hour < 17) return 'Good Afternoon ☀️';
  return 'Good Evening 🌙';
}

// ─────────────────────────────────────────────────────────────────────────────
//  Screen
// ─────────────────────────────────────────────────────────────────────────────
class VendorDashboardScreen extends StatefulWidget {
  const VendorDashboardScreen({super.key});
  @override
  State<VendorDashboardScreen> createState() => _VendorDashboardScreenState();
}

class _VendorDashboardScreenState extends State<VendorDashboardScreen> {
  Map<String, dynamic>? _stats;
  List<dynamic> _recentOrders = [];
  bool _loading = true;
  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshUnreadCount();
  }

  // Lightweight background fetch just to populate the badge — does not
  // touch _loading/_stats, and fails silently (badge simply stays as-is).
  Future<void> _refreshUnreadCount() async {
    try {
      final res = await ApiClient.dio.get('/vendors/notifications',
          queryParameters: {'page': 1, 'limit': 100});
      final data = res.data;
      final List<dynamic> raw = data is Map
          ? (data['notifications'] as List? ?? [])
          : (data as List? ?? []);
      final unread = raw.where((n) {
        final v = n is Map ? n['is_read'] : null;
        return !(v == 1 || v == true);
      }).length;
      notificationUnreadCount.value = unread;
    } catch (_) {
      // Silent — badge just won't update until Notifications screen is opened.
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiClient.dio.get('/vendors/dashboard/stats'),
        ApiClient.dio.get('/vendors/orders',
            queryParameters: {'limit': '5', 'page': '1'}),
      ]);
      if (mounted) {
        setState(() {
          _stats = results[0].data is Map
              ? Map<String, dynamic>.from(results[0].data)
              : {};
          _recentOrders =
              results[1].data is List ? results[1].data as List : [];
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    // Must run BEFORE clearAll() — needs the still-present auth token to
    // authenticate the unregister request. Best-effort.
    await PushNotificationService.unregisterToken();
    await LocalStorage.clearAll();
    if (mounted) context.go('/login');
  }

  String _formatNum(dynamic v) {
    final n = _safeDouble(v);
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: _buildAppBar(context, cs),
      body: RefreshIndicator(
        onRefresh: _load,
        color: cs.primary,
        child: _loading
            ? const _DashboardSkeleton()
            : ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  _HeroCard(onViewOrders: () => context.push('/orders')),
                  const SizedBox(height: 24),
                  const _SectionLabel(label: 'Overview'),
                  const SizedBox(height: 12),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.25,
                    children: [
                      _KpiCard(
                        icon: Icons.receipt_long_rounded,
                        title: 'Total Orders',
                        value: '${_safeInt(_stats?['totalOrders'])}',
                        color: cs.primary,
                        trend: '+12% vs last week',
                        trendUp: true,
                      ),
                      _KpiCard(
                        icon: Icons.payments_rounded,
                        title: 'Revenue',
                        value: 'KES ${_formatNum(_stats?['revenue'])}',
                        color: const Color(0xFF10B981),
                        trend: '+8% vs last week',
                        trendUp: true,
                      ),
                      _KpiCard(
                        icon: Icons.pending_actions_rounded,
                        title: 'Pending',
                        value: '${_safeInt(_stats?['pendingOrders'])}',
                        color: const Color(0xFFF59E0B),
                        trend: 'Needs attention',
                        trendUp: null,
                      ),
                      _KpiCard(
                        icon: Icons.inventory_2_rounded,
                        title: 'Products',
                        value: '${_safeInt(_stats?['totalProducts'])}',
                        color: const Color(0xFF8B5CF6),
                        trend: 'Across all outlets',
                        trendUp: null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  const _SectionLabel(label: 'Quick Actions'),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 90,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _QuickAction(
                          icon: Icons.receipt_long_rounded,
                          label: 'Orders',
                          color: cs.primary,
                          onTap: () => context.push('/orders'),
                        ),
                        _QuickAction(
                          icon: Icons.fastfood_rounded,
                          label: 'Products',
                          color: const Color(0xFF06B6D4),
                          onTap: () => context.push('/products'),
                        ),
                        _QuickAction(
                          icon: Icons.inventory_2_rounded,
                          label: 'Inventory',
                          color: const Color(0xFF8B5CF6),
                          onTap: () => context.push('/inventory'),
                        ),
                        _QuickAction(
                          icon: Icons.storefront_rounded,
                          label: 'Outlets',
                          color: const Color(0xFFF59E0B),
                          onTap: () => context.push('/outlets'),
                        ),
                        _QuickAction(
                          icon: Icons.delivery_dining_rounded,
                          label: 'Riders',
                          color: const Color(0xFFEF4444),
                          onTap: () => context.push('/riders'),
                        ),
                        _QuickAction(
                          icon: Icons.bar_chart_rounded,
                          label: 'Analytics',
                          color: const Color(0xFF10B981),
                          onTap: () => context.push('/analytics'),
                        ),
                        _QuickAction(
                          icon: Icons.local_offer_rounded,
                          label: 'Promos',
                          color: const Color(0xFFEC4899),
                          onTap: () => context.push('/promotions'),
                        ),
                        _QuickAction(
                          icon: Icons.payments_rounded,
                          label: 'Transactions',
                          color: const Color(0xFF14B8A6),
                          onTap: () => context.push('/transactions'),
                        ),
                        _QuickAction(
                          icon: Icons.support_agent_rounded,
                          label: 'Support',
                          color: const Color(0xFF64748B),
                          onTap: () => context.push('/support'),
                        ),
                        _QuickAction(
                          icon: Icons.star_rounded,
                          label: 'Reviews',
                          color: const Color(0xFFFBBF24),
                          onTap: () => context.push('/reviews'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const _SectionLabel(label: 'Recent Orders'),
                      TextButton(
                        onPressed: () => context.push('/orders'),
                        child: Text('View all',
                            style: TextStyle(
                                color: cs.primary,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_recentOrders.isEmpty)
                    const AppEmpty(
                      icon: Icons.receipt_long_outlined,
                      message: 'No recent orders',
                    )
                  else
                    ..._recentOrders.take(5).map((o) => _OrderCard(order: o)),
                  const SizedBox(height: 32),
                ],
              ),
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, ColorScheme cs) {
    return AppBar(
      titleSpacing: 16,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _greeting(),
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurface.withOpacity(0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
          const Text(
            'Vendor Dashboard',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ],
      ),
      actions: [
        ValueListenableBuilder<int>(
          valueListenable: notificationUnreadCount,
          builder: (_, count, __) => IconButton(
            icon: count > 0
                ? Badge(
                    label: Text(count > 99 ? '99+' : '$count'),
                    child: const Icon(Icons.notifications_outlined),
                  )
                : const Icon(Icons.notifications_outlined),
            onPressed: () => context.push('/notifications'),
            tooltip: 'Notifications',
          ),
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => context.push('/settings'),
          tooltip: 'Settings',
        ),
        PopupMenuButton(
          icon: const CircleAvatar(
            radius: 16,
            backgroundColor: Color(0xFF10B981),
            child: Text('V',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
          ),
          itemBuilder: (_) => [
            PopupMenuItem(
              onTap: () => context.push('/settings'),
              child: const Row(children: [
                Icon(Icons.person_outline, size: 18),
                SizedBox(width: 12),
                Text('Profile'),
              ]),
            ),
            PopupMenuItem(
              onTap: _logout,
              child: const Row(children: [
                Icon(Icons.logout, size: 18, color: Color(0xFFEF4444)),
                SizedBox(width: 12),
                Text('Logout', style: TextStyle(color: Color(0xFFEF4444))),
              ]),
            ),
          ],
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return NavigationBar(
      selectedIndex: _navIndex,
      onDestinationSelected: (i) {
        setState(() => _navIndex = i);
        switch (i) {
          case 1:
            context.push('/orders');
            break;
          case 2:
            context.push('/products');
            break;
          case 3:
            context.push('/analytics');
            break;
        }
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard_rounded),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long_rounded),
          label: 'Orders',
        ),
        NavigationDestination(
          icon: Icon(Icons.inventory_2_outlined),
          selectedIcon: Icon(Icons.inventory_2_rounded),
          label: 'Products',
        ),
        NavigationDestination(
          icon: Icon(Icons.bar_chart_outlined),
          selectedIcon: Icon(Icons.bar_chart_rounded),
          label: 'Analytics',
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Hero card
// ─────────────────────────────────────────────────────────────────────────────
class _HeroCard extends StatelessWidget {
  final VoidCallback onViewOrders;
  const _HeroCard({required this.onViewOrders});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cs.primary, cs.primary.withOpacity(0.75)],
        ),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 20,
            bottom: -30,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '🚀 Business Overview',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Manage Your\nBusiness',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Track orders, revenue & inventory\nin real time.',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.8), fontSize: 13),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onViewOrders,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: cs.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.receipt_long_rounded, size: 18),
                label: const Text('View Orders',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  KPI Card
// ─────────────────────────────────────────────────────────────────────────────
class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final String trend;
  final bool? trendUp;

  const _KpiCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    required this.trend,
    required this.trendUp,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? color.withOpacity(0.12) : color.withOpacity(0.06);
    final border = color.withOpacity(0.18);

    Color trendColor;
    IconData trendIcon;
    if (trendUp == true) {
      trendColor = const Color(0xFF10B981);
      trendIcon = Icons.trending_up_rounded;
    } else if (trendUp == false) {
      trendColor = const Color(0xFFEF4444);
      trendIcon = Icons.trending_down_rounded;
    } else {
      trendColor = color.withOpacity(0.7);
      trendIcon = Icons.info_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Icon(trendIcon, color: trendColor, size: 16),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: trendColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              trend,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: trendColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Quick Action
// ─────────────────────────────────────────────────────────────────────────────
class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      margin: const EdgeInsets.only(right: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.2), width: 1.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color.withOpacity(0.9),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Order Card
// ─────────────────────────────────────────────────────────────────────────────
class _OrderCard extends StatelessWidget {
  final dynamic order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = order['order_status']?.toString() ?? 'pending';
    final amount = _safeDouble(order['total_amount']);
    final orderNum = order['order_number']?.toString() ?? '#—';
    final date = order['created_at']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => context.push('/orders/${order['order_id']}'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.receipt_long_rounded,
                    color: cs.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(orderNum,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    if (date.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(date),
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurface.withOpacity(0.5)),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'KES ${amount.toStringAsFixed(0)}',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: cs.primary),
                  ),
                  const SizedBox(height: 4),
                  StatusBadge(status: status),
                ],
              ),
            ],
          ),
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
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return raw;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Section Label
// ─────────────────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: Theme.of(context).colorScheme.onSurface,
        letterSpacing: -0.3,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Skeleton Loader
// ─────────────────────────────────────────────────────────────────────────────
class _DashboardSkeleton extends StatefulWidget {
  const _DashboardSkeleton();

  @override
  State<_DashboardSkeleton> createState() => _DashboardSkeletonState();
}

class _DashboardSkeletonState extends State<_DashboardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.85).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _shimmer(context, height: 180, radius: 24),
          const SizedBox(height: 24),
          _shimmer(context, width: 120, height: 18, radius: 8),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.25,
            children: List.generate(4, (_) => _shimmer(context, radius: 20)),
          ),
          const SizedBox(height: 24),
          _shimmer(context, width: 120, height: 18, radius: 8),
          const SizedBox(height: 12),
          Row(
            children: List.generate(
              5,
              (i) => Container(
                margin: const EdgeInsets.only(right: 10),
                child: _shimmer(context, width: 76, height: 90, radius: 16),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _shimmer(context, width: 120, height: 18, radius: 8),
          const SizedBox(height: 12),
          ...List.generate(3, (_) => _shimmer(context, height: 72, radius: 16)),
        ],
      ),
    );
  }

  Widget _shimmer(BuildContext context,
      {double? width, double height = 100, double radius = 12}) {
    final base = Theme.of(context).colorScheme.onSurface;
    return Container(
      width: width,
      height: height,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: base.withOpacity(_anim.value * 0.12),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
