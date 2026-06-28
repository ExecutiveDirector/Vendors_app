import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/local_storage.dart';
import '../api/dio_client.dart';
import 'dart:async';

class AuthGuard {
  /// Check if user is authenticated
  static Future<bool> isAuthenticated() async {
    final token = await LocalStorage.getToken();
    if (token == null) return false;

    // Optionally verify token with backend
    try {
      final response = await ApiClient.dio.get('/auth/verify');
      return response.data['authenticated'] == true;
    } catch (e) {
      // If verification fails, assume unauthenticated
      return false;
    }
  }

  /// Redirect handler for GoRouter
  static Future<String?> redirect(
      BuildContext context, GoRouterState state) async {
    final isAuth = await isAuthenticated();
    final isLoginRoute = state.matchedLocation == '/login';

    // If not authenticated and trying to access protected route
    if (!isAuth && !isLoginRoute) {
      return '/login';
    }

    // If authenticated and trying to access login
    if (isAuth && isLoginRoute) {
      return '/dashboard';
    }

    // No redirect needed
    return null;
  }

  /// Logout and clear all stored data
  static Future<void> logout(BuildContext context) async {
    try {
      // Call logout API
      await ApiClient.dio.post('/auth/vendor/logout');
    } catch (e) {
      // Continue with logout even if API call fails
      debugPrint('Logout API call failed: $e');
    }

    // Clear all local storage
    await LocalStorage.clearAll();

    // Navigate to login
    if (context.mounted) {
      context.go('/login');
    }
  }
}

/// Widget wrapper for protected routes
class AuthenticatedRoute extends StatelessWidget {
  final Widget child;

  const AuthenticatedRoute({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: AuthGuard.isAuthenticated(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF8A00)),
              ),
            ),
          );
        }

        if (snapshot.data == true) {
          return child;
        }

        // Not authenticated, redirect to login
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context.go('/login');
        });

        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}
