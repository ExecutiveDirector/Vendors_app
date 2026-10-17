import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('order alert sound ships in both Flutter assets and Android raw resources', () {
    expect(File('assets/sounds/order_alert.wav').existsSync(), isTrue);
    expect(File('android/app/src/main/res/raw/order_alert.wav').existsSync(), isTrue);
  });
}
