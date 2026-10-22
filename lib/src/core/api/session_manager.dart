import 'package:dio/dio.dart';
import '../config.dart';
import '../services/local_storage.dart';

/// What happened when we tried to renew the session.
enum RefreshOutcome {
  /// New tokens were saved; the original request can be retried.
  renewed,

  /// The server said this session is over (or there is nothing to renew
  /// with). The only case in which the vendor should be signed out.
  rejected,

  /// Offline, timeout or server trouble. The session is probably still
  /// fine, so do NOT sign out; just let the request fail and try again later.
  unavailable,
}

/// Keeps vendors signed in by quietly renewing the access token with the
/// long-lived refresh token. Concurrent callers share one renewal.
class SessionManager {
  SessionManager._();

  static Future<RefreshOutcome>? _inFlight;

  /// Test hook: build the Dio used for the renewal call.
  static Dio Function() dioFactory = () => Dio(BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ));

  static Future<RefreshOutcome> refresh() {
    return _inFlight ??= _renew().whenComplete(() => _inFlight = null);
  }

  static Future<RefreshOutcome> _renew() async {
    final refreshToken = await LocalStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return RefreshOutcome.rejected;
    }
    try {
      final res = await dioFactory()
          .post('/auth/refresh', data: {'refreshToken': refreshToken});
      final data = res.data;
      final token = data is Map ? data['token'] : null;
      if (token is! String || token.isEmpty) return RefreshOutcome.unavailable;
      await LocalStorage.setToken(token);
      final newRefresh = data['refreshToken'];
      if (newRefresh is String && newRefresh.isNotEmpty) {
        await LocalStorage.setRefreshToken(newRefresh);
      }
      return RefreshOutcome.renewed;
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) return RefreshOutcome.rejected;
      return RefreshOutcome.unavailable;
    } catch (_) {
      return RefreshOutcome.unavailable;
    }
  }
}
