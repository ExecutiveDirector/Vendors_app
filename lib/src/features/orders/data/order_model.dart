// order_model.dart
// ALL numeric fields parsed defensively — API may return Strings for numbers.

class OrderItem {
  final String productName;
  final int quantity;
  final double unitPrice;
  final double totalPrice;

  const OrderItem({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        productName: json['product_name']?.toString() ?? '',
        quantity: _parseInt(json['quantity']),
        unitPrice: _parseDouble(json['unit_price']),
        totalPrice: _parseDouble(json['total_price']),
      );
}

class Order {
  final String orderId;
  final String orderNumber;
  final String orderStatus;
  final String paymentStatus;
  final double totalAmount;
  final double deliveryFee;
  final String? deliveryAddress;
  final String? deliveryContact;
  final String? customerNote;
  final String? riderName;
  final String? riderPhone;
  final String? riderVehicleType;
  final String? vendorName;
  final double? deliveryLatitude;
  final double? deliveryLongitude;
  final String createdAt;
  final String? deliveredAt;
  final List<OrderItem> items;

  const Order({
    required this.orderId,
    required this.orderNumber,
    required this.orderStatus,
    required this.paymentStatus,
    required this.totalAmount,
    this.deliveryFee = 0,
    this.deliveryAddress,
    this.deliveryContact,
    this.customerNote,
    this.riderName,
    this.riderPhone,
    this.riderVehicleType,
    this.vendorName,
    this.deliveryLatitude,
    this.deliveryLongitude,
    required this.createdAt,
    this.deliveredAt,
    this.items = const [],
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    // rider, when present, is the riders row plus a nested `account` for
    // phone_number (see vendorController.getVendorOrderDetails /
    // orderController.getOrderById) — riders itself has first_name/
    // last_name but no phone column of its own.
    final rider = json['rider'] as Map<String, dynamic>?;
    final riderAccount = rider?['account'] as Map<String, dynamic>?;
    final riderFullName = rider == null
        ? null
        : [rider['first_name'], rider['last_name']]
            .where((e) => e != null && e.toString().trim().isNotEmpty)
            .join(' ')
            .trim();

    return Order(
        orderId: json['order_id']?.toString() ?? json['id']?.toString() ?? '',
        orderNumber: json['order_number']?.toString() ?? '#—',
        orderStatus: json['order_status']?.toString() ?? 'pending',
        paymentStatus: json['payment_status']?.toString() ?? 'pending',
        // FIX: all money fields use _parseDouble — safe for String/int/double/null
        totalAmount: _parseDouble(json['total_amount']),
        deliveryFee: _parseDouble(json['delivery_fee']),
        deliveryAddress: json['delivery_address']?.toString(),
        deliveryContact: json['delivery_contact']?.toString(),
        customerNote: json['customer_note']?.toString(),
        riderName: (riderFullName != null && riderFullName.isNotEmpty)
            ? riderFullName
            : (json['rider']?['name']?.toString() ??
                json['rider']?['full_name']?.toString()),
        riderPhone: riderAccount?['phone_number']?.toString() ??
            json['rider']?['phone']?.toString(),
        riderVehicleType: rider?['vehicle_type']?.toString(),
        vendorName: json['vendor_name']?.toString(),
        deliveryLatitude: json['delivery_latitude'] != null
            ? _parseDouble(json['delivery_latitude'])
            : null,
        deliveryLongitude: json['delivery_longitude'] != null
            ? _parseDouble(json['delivery_longitude'])
            : null,
        createdAt: json['created_at']?.toString() ?? '',
        deliveredAt: json['delivered_at']?.toString(),
        items: (json['order_items'] as List? ?? [])
            .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
  }

  bool get hasDeliveryLocation =>
      deliveryLatitude != null && deliveryLongitude != null;

  double get grandTotal => totalAmount + deliveryFee;

  String get displayStatus {
    switch (orderStatus.toLowerCase()) {
      case 'draft':
        return 'Draft';
      case 'pending':
        return 'Pending';
      case 'confirmed':
        return 'Confirmed';
      case 'preparing':
        return 'Preparing';
      case 'ready':
        return 'Ready';
      case 'dispatched':
        return 'Dispatched';
      case 'delivered':
        return 'Delivered';
      case 'canceled':
      case 'cancelled':
        return 'Cancelled';
      default:
        return orderStatus;
    }
  }
}

// ── Private parse helpers ─────────────────────────────────────────────────────
double _parseDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

int _parseInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is double) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}
