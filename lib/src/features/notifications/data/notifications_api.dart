import '../../../core/api/dio_client.dart';
class NotificationsApi {
  static Future<List<dynamic>> list() async {
    final res = await ApiClient.dio.get('/vendors/notifications');
    return res.data;
  }
}
