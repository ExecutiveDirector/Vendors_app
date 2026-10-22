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
import 'session_manager.dart';
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

      // ── 401 handling: stay signed in ────────────────────────────────────
      // A 401 usually just means the short-lived access token ran out. Renew
      // it with the refresh token and retry the request once, invisibly.
      // The vendor is sent back to login ONLY when the server rejects the
      // refresh token itself (signed out elsewhere, password reset, account
      // disabled) or when there is no refresh token. Being offline, slow or
      // hitting a 5xx never signs anyone out.
      InterceptorsWrapper(
        onError: (DioException err, handler) async {
          final path = err.requestOptions.path;
          final isAuthCall =
              path.contains('/auth/login') || path.contains('/auth/refresh');
          if (err.response?.statusCode != 401 ||
              isAuthCall ||
              err.requestOptions.extra['session_retried'] == true) {
            return handler.next(err);
          }

          final outcome = await SessionManager.refresh();
          if (outcome == RefreshOutcome.renewed) {
            final token = await LocalStorage.getToken();
            final opts = err.requestOptions
              ..headers['Authorization'] = 'Bearer $token'
              ..extra['session_retried'] = true;
            try {
              return handler.resolve(await _dio.fetch(opts));
            } on DioException catch (retryError) {
              return handler.next(retryError);
            }
          }
          if (outcome == RefreshOutcome.rejected) {
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
