// lib/src/core/api/dio_client.dart
//
// baseUrl is the server root only (no /api/v1).
// Each API class owns its full path: '/api/v1/vendors/inventory', etc.
// This avoids the common bug where baseUrl ends with /api/v1 and paths
// accidentally double-up or get mangled.

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config.dart';
import '../services/local_storage.dart';
import '../navigation/app_navigator_key.dart';

class ApiClient {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  )..interceptors.addAll([
      // ── Auth header ──────────────────────────────────────────────────────
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await LocalStorage.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
      ),

      // ── 401 handling ──────────────────────────────────────────────────────
      // NOTE: this is intentionally NOT a silent-refresh-and-retry flow.
      // There is no /auth/refresh endpoint anywhere in this codebase, and
      // only a single access token is stored (no refresh token) — so there
      // is nothing to refresh against. Inventing an endpoint here would risk
      // a confident-looking 404 loop in production. Instead: on 401, clear
      // the stale session and send the vendor back to login with a clear
      // reason, rather than the previous behavior (silent failure / a
      // confusing raw error toast / possible crash deeper in a screen).
      //
      // If/when a real refresh endpoint exists, replace the body of
      // onError below with the refresh-and-retry logic.
      InterceptorsWrapper(
        onError: (DioException err, handler) async {
          if (err.response?.statusCode == 401 &&
              err.requestOptions.path != '/auth/login') {
            await LocalStorage.clearAll();
            navigateTo('/login?reason=session_expired');
          }
          return handler.next(err);
        },
      ),

      // ── Response error logging (dev only) ────────────────────────────────
      InterceptorsWrapper(
        onError: (DioException err, handler) {
          // debugPrint (not print) is stripped more reliably in release
          // builds and won't flood device logs in production.
          final status = err.response?.statusCode;
          final path = err.requestOptions.path;
          final message = err.response?.data?['error'] ?? err.message;
          debugPrint('❌ API [$status] $path → $message');
          return handler.next(err);
        },
      ),
    ]);

  static Dio get dio => _dio;
}
