// ─── Dashboard ───────────────────────────────────────────────────────────────
import '../../../core/api/dio_client.dart';

class DashboardApi {
  DashboardApi._();

  static Future<Map<String, dynamic>> summary() async {
    final res = await ApiClient.dio.get('/vendors/dashboard/stats');
    return Map<String, dynamic>.from(res.data as Map);
  }

  static Future<List<dynamic>> recentOrders({int limit = 10}) async {
    final res = await ApiClient.dio.get(
      '/vendors/dashboard/recent-orders',
      queryParameters: {'limit': limit},
    );
    return res.data as List;
  }
}
