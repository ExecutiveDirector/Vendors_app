// lib/src/features/outlets/data/outlets_api.dart
import '../../../core/api/dio_client.dart';

class OutletsApi {
  static Future<List<dynamic>> list() async {
    final res = await ApiClient.dio.get('/vendors/outlets');
    return res.data as List<dynamic>;
  }

  static Future<Map<String, dynamic>> create(
      Map<String, dynamic> payload) async {
    final res = await ApiClient.dio.post('/vendors/outlets', data: payload);
    return res.data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> update(
      String outletId, Map<String, dynamic> payload) async {
    final res =
        await ApiClient.dio.put('/vendors/outlets/$outletId', data: payload);
    return res.data as Map<String, dynamic>;
  }
}
