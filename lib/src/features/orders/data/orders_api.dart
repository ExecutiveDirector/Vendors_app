import 'dart:async';

import '../../../core/api/dio_client.dart';
import 'order_model.dart';

class OrdersApi {
  static Future<List<Order>> list({String? status}) async {
    final params = <String, dynamic>{};
    if (status != null) params['status'] = status;
    final res = await ApiClient.dio.get(
      '/vendors/orders',
      queryParameters: params,
    );
    final data = res.data;
    if (data is List) return data.map((e) => Order.fromJson(e)).toList();
    return [];
  }

  static Future<Order> byId(String id) async {
    final res = await ApiClient.dio.get('/vendors/orders/$id');
    final data = res.data;
    if (data is Map) return Order.fromJson(data as Map<String, dynamic>);
    return Order.fromJson(data);
  }

  static Future<void> updateStatus(String orderId, String status) async {
    await ApiClient.dio.put(
      '/vendors/orders/$orderId/status',
      data: {'status': status},
    );
  }

  static Future<void> assignRider(String orderId, String riderId) async {
    await ApiClient.dio.put(
      '/orders/$orderId/assign-rider',
      data: {'rider_id': riderId},
    );
  }

  /// Polls GET /vendors/orders/:id on an interval so a tracking screen can
  /// reflect status/rider changes without the vendor manually refreshing.
  /// Mirrors the consumer app's OrderService.trackOrderStatus pattern.
  static Stream<Order> trackOrder(String orderId, {int interval = 8}) {
    late StreamController<Order> controller;
    Timer? timer;

    Future<void> poll() async {
      try {
        final order = await byId(orderId);
        if (!controller.isClosed) controller.add(order);
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    }

    controller = StreamController<Order>(
      onListen: () {
        poll();
        timer = Timer.periodic(Duration(seconds: interval), (_) => poll());
      },
      onCancel: () {
        timer?.cancel();
      },
    );

    return controller.stream;
  }
}
