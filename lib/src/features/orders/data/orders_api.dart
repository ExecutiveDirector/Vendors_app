import 'dart:async';

import 'package:dio/dio.dart';

import '../../../core/api/dio_client.dart';
import '../../../core/services/local_storage.dart';
import 'order_model.dart';

class OrdersApi {
  /// True when the last [list] call could not reach the server and the
  /// result came from the offline cache instead.
  static bool lastListFromCache = false;

  static Future<List<Order>> list({String? status}) async {
    final params = <String, dynamic>{};
    if (status != null) params['status'] = status;
    final cacheKey = 'orders_${status ?? 'all'}';
    try {
      final res = await ApiClient.dio.get(
        '/vendors/orders',
        queryParameters: params,
      );
      lastListFromCache = false;
      final data = res.data;
      if (data is List) {
        LocalStorage.cacheJson(cacheKey, data);
        return data.map((e) => Order.fromJson(e)).toList();
      }
      return [];
    } on DioException catch (e) {
      final offline = e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout;
      final cached = offline ? LocalStorage.readCachedJson(cacheKey) : null;
      if (cached is List) {
        lastListFromCache = true;
        return cached.map((e) => Order.fromJson(e)).toList();
      }
      rethrow;
    }
  }

  static Future<Order> byId(String id) async {
    final res = await ApiClient.dio.get('/vendors/orders/$id');
    final data = res.data;
    if (data is Map) return Order.fromJson(data as Map<String, dynamic>);
    return Order.fromJson(data);
  }

  /// [reason] is required by the server when [status] is 'canceled'.
  static Future<void> updateStatus(String orderId, String status,
      {String? reason}) async {
    await ApiClient.dio.put(
      '/vendors/orders/$orderId/status',
      data: {'status': status, if (reason != null) 'reason': reason},
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
