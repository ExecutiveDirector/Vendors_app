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

      // ── 401 handling: silent refresh, then retry ─────────────────────────
      // Vendors stay signed in. On 401 we exchange the stored refresh token
      // for a new access token (single-flight, so parallel requests share one
      // refresh) and retry. We only sign out when the server definitively
      // rejects the refresh token (401/403) — never on network errors.
      InterceptorsWrapper(
        onError: (DioException err, handler) async {
          final path = err.requestOptions.path;
          if (err.response?.statusCode != 401 ||
              path == '/auth/login' ||
              path == '/auth/refresh' ||
              err.requestOptions.extra['retried'] == true) {
            return handler.next(err);
          }
          final result = await _refreshOnce();
          if (result == _RefreshResult.ok) {
            try {
              final opts = err.requestOptions;
              opts.extra['retried'] = true;
              opts.headers['Authorization'] =
                  'Bearer ${await LocalStorage.getToken()}';
              return handler.resolve(await _dio.fetch(opts));
            } on DioException catch (e) {
              return handler.next(e);
            }
          }
          if (result == _RefreshResult.rejected) {
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

  static Future<_RefreshResult>? _inflight;

  static Future<_RefreshResult> _refreshOnce() =>
      _inflight ??= _doRefresh().whenComplete(() => _inflight = null);

  static Future<_RefreshResult> _doRefresh() async {
    final refresh = await LocalStorage.getRefreshToken();
    // Sessions created before this update have no refresh token: sign in once more.
    if (refresh == null || refresh.isEmpty) return _RefreshResult.rejected;
    try {
      final res = await Dio(BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30),
      )).post('/auth/refresh', data: {'refreshToken': refresh});
      final data = res.data;
      final token = data is Map ? data['token'] : null;
      if (token is! String) return _RefreshResult.failed;
      await LocalStorage.setToken(token);
      final next = data['refreshToken'];
      if (next is String && next.isNotEmpty) {
        await LocalStorage.setRefreshToken(next);
      }
      return _RefreshResult.ok;
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      return (code == 401 || code == 403)
          ? _RefreshResult.rejected
          : _RefreshResult.failed; // offline / server error: stay signed in
    } catch (_) {
      return _RefreshResult.failed;
    }
  }
}

enum _RefreshResult { ok, rejected, failed }
