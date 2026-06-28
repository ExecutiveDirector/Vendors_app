import '../../../core/api/dio_client.dart';

/// A rider currently delivering one or more of this vendor's active orders.
///
/// Vendors don't manage a roster of riders directly — riders are
/// platform-wide and assigned by the system/admin (see backend
/// vendorController.getVendorActiveRiders). This model reflects that:
/// it's "who's out delivering my orders right now", not "my employees".
class ActiveRider {
  final int riderId;
  final String name;
  final String? phone;
  final String vehicleType;
  final String currentStatus;
  final double rating;
  final int totalDeliveries;
  final int activeOrderCount;
  final List<String> orderNumbers;

  ActiveRider({
    required this.riderId,
    required this.name,
    required this.phone,
    required this.vehicleType,
    required this.currentStatus,
    required this.rating,
    required this.totalDeliveries,
    required this.activeOrderCount,
    required this.orderNumbers,
  });

  factory ActiveRider.fromJson(Map<String, dynamic> json) {
    return ActiveRider(
      riderId: int.tryParse(json['rider_id']?.toString() ?? '') ?? 0,
      name: json['name']?.toString() ?? 'Rider',
      phone: json['phone']?.toString(),
      vehicleType: json['vehicle_type']?.toString() ?? 'motorcycle',
      currentStatus: json['current_status']?.toString() ?? 'offline',
      rating: double.tryParse(json['rating']?.toString() ?? '') ?? 0,
      totalDeliveries:
          int.tryParse(json['total_deliveries']?.toString() ?? '') ?? 0,
      activeOrderCount:
          int.tryParse(json['active_order_count']?.toString() ?? '') ?? 0,
      orderNumbers: (json['order_numbers'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class VendorRidersApi {
  /// Riders currently on one of this vendor's active (non-terminal) orders.
  /// Backed by GET /vendors/riders/active.
  static Future<List<ActiveRider>> listActive() async {
    final res = await ApiClient.dio.get('/vendors/riders/active');
    final List<dynamic> data = res.data is List ? res.data : [];
    return data
        .map((e) => ActiveRider.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
