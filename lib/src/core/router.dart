// lib/src/core/router.dart
//
// Changes:
//  1. Added `redirect` to GoRouter — auth guard wired in properly.
//  2. Dashboard wrapped in PopScope to intercept back button — shows
//     "Exit app?" confirmation instead of going back to /login.
//  3. All protected routes now redirect to /login when token missing.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'services/local_storage.dart';
import 'navigation/app_navigator_key.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/dashboard/presentation/vendor_dashboard.dart';
import '../features/orders/presentation/orders_screen.dart';
import '../features/orders/presentation/order_detail_screen.dart';
import '../features/products/presentation/products_screen.dart';
import '../features/inventory/presentation/inventory_screen.dart';
import '../features/outlets/presentation/outlets_screen.dart';
import '../features/riders/presentation/riders_screen.dart';
import '../features/promotions/presentation/promotions_screen.dart';
import '../features/reviews/presentation/reviews_screen.dart';
import '../features/notifications/presentation/notifications_screen.dart';
import '../features/analytics/presentation/analytics_screen.dart';
import '../features/support/presentation/support_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/transactions/presentation/transactions_screen.dart';
import '../features/subscriptions/presentation/subscriptions_screen.dart';
import '../features/tracking/presentation/track_order_screen.dart';

// ─── Simple token check (no network call — avoids logout on bad connectivity) ─
Future<String?> _authRedirect(BuildContext ctx, GoRouterState state) async {
  final token = await LocalStorage.getToken();
  final onLogin = state.matchedLocation == '/login';
  if (token == null && !onLogin) return '/login';
  if (token != null && onLogin) return '/dashboard';
  return null;
}

// ─── Dashboard shell with exit-on-back instead of navigate-back-to-login ─────
class _DashboardShell extends StatelessWidget {
  const _DashboardShell();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // canPop: false means we intercept all back presses ourselves
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Exit App?'),
            content: const Text('Do you want to exit AquaGas Vendor?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8A00),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Exit'),
              ),
            ],
          ),
        );
        if (shouldExit == true) {
          // Cleanly exit the app
          await SystemNavigator.pop();
        }
      },
      child: const VendorDashboardScreen(),
    );
  }
}

GoRouter createRouter() => GoRouter(
      navigatorKey: appNavigatorKey,
      initialLocation: '/login',
      redirect: _authRedirect,
      routes: [
        GoRoute(
          path: '/login',
          builder: (c, s) => LoginScreen(
              sessionExpired: s.uri.queryParameters['reason'] ==
                  'session_expired'),
        ),
        GoRoute(
          path: '/dashboard',
          // ← Shell intercepts back button; shows exit dialog instead of logout
          builder: (c, s) => const _DashboardShell(),
        ),
        GoRoute(path: '/orders', builder: (c, s) => const OrdersScreen()),
        GoRoute(
          path: '/orders/:id',
          builder: (c, s) =>
              OrderDetailScreen(id: s.pathParameters['id']!),
        ),
        GoRoute(
          path: '/orders/:id/track',
          builder: (c, s) =>
              TrackOrderScreen(orderId: s.pathParameters['id']!),
        ),
        GoRoute(path: '/products', builder: (c, s) => const ProductsScreen()),
        GoRoute(
            path: '/inventory', builder: (c, s) => const InventoryScreen()),
        GoRoute(path: '/outlets', builder: (c, s) => const OutletsScreen()),
        GoRoute(path: '/riders', builder: (c, s) => const RidersScreen()),
        GoRoute(
            path: '/promotions',
            builder: (c, s) => const PromotionsScreen()),
        GoRoute(path: '/reviews', builder: (c, s) => const ReviewsScreen()),
        GoRoute(
            path: '/notifications',
            builder: (c, s) => const NotificationsScreen()),
        GoRoute(
            path: '/analytics', builder: (c, s) => const AnalyticsScreen()),
        GoRoute(path: '/support', builder: (c, s) => const SupportScreen()),
        GoRoute(
            path: '/settings', builder: (c, s) => const SettingsScreen()),
        GoRoute(
            path: '/transactions',
            builder: (c, s) => const TransactionsScreen()),
        GoRoute(
            path: '/subscriptions',
            builder: (c, s) => const SubscriptionsScreen()),
      ],
    );

/// Single global instance used by MaterialApp.router
final appRouter = createRouter();
