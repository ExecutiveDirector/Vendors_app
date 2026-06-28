// lib/src/core/navigation/app_navigator_key.dart
//
// A standalone global navigator key, deliberately kept free of any
// dependency on router.dart or bootstrap.dart, so that low-level code like
// the Dio 401 interceptor can trigger navigation (e.g. force logout ->
// /login) without creating an import cycle:
//   dio_client.dart -> bootstrap.dart -> router.dart -> screens -> *_api.dart -> dio_client.dart
//
// Wire this in by passing `navigatorKey: appNavigatorKey` to
// MaterialApp.router(...) in main.dart.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final GlobalKey<NavigatorState> appNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'appNavigatorKey');

/// Navigate to [location] using the app's root navigator's own context.
/// Safe to call from anywhere, including interceptors that run outside a
/// widget's build phase. No-op if the navigator isn't mounted yet.
void navigateTo(String location) {
  final context = appNavigatorKey.currentState?.context;
  if (context == null) return;
  context.go(location);
}
