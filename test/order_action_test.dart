import 'package:flutter_test/flutter_test.dart';
import 'package:vendorapp/src/features/orders/data/order_model.dart';

Order _o(Map<String, dynamic> j) =>
    Order.fromJson({'order_id': 1, 'order_number': 'A1', ...j});

void main() {
  test('paid pending order needs vendor action', () {
    expect(_o({'order_status': 'pending', 'payment_status': 'paid'}).needsVendorAction, isTrue);
  });
  test('unpaid pending card order does not', () {
    expect(_o({'order_status': 'pending', 'payment_status': 'pending'}).needsVendorAction, isFalse);
  });
  test('COD pending order needs action even though unpaid', () {
    final o = _o({'order_status': 'pending', 'payment_status': 'pending', 'cod_amount': '1850.00'});
    expect(o.isCod, isTrue);
    expect(o.codAmount, 1850);
    expect(o.needsVendorAction, isTrue);
  });
  test('confirmed order no longer needs action', () {
    expect(_o({'order_status': 'confirmed', 'payment_status': 'paid'}).needsVendorAction, isFalse);
  });
}
