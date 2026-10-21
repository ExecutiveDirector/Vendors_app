import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vendorapp/src/core/theme.dart';
import 'package:vendorapp/src/core/widgets/shared_widgets.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('ButtonPair places both buttons on the same row', (tester) async {
    await tester.pumpWidget(_wrap(ButtonPair(
      secondary: OutlinedButton(onPressed: () {}, child: const Text('Cancel')),
      primary: ElevatedButton(onPressed: () {}, child: const Text('Confirm')),
    )));

    final left = tester.getRect(find.widgetWithText(OutlinedButton, 'Cancel'));
    final right = tester.getRect(find.widgetWithText(ElevatedButton, 'Confirm'));
    expect(left.center.dy, closeTo(right.center.dy, 0.5));
    expect(left.right, lessThan(right.left));
    expect(left.width, closeTo(right.width, 0.5));
  });

  testWidgets('ButtonPair primaryFlex gives the main action more width',
      (tester) async {
    await tester.pumpWidget(_wrap(ButtonPair(
      primaryFlex: 2,
      secondary: OutlinedButton(onPressed: () {}, child: const Text('No')),
      primary: ElevatedButton(onPressed: () {}, child: const Text('Yes')),
    )));
    final left = tester.getRect(find.widgetWithText(OutlinedButton, 'No'));
    final right = tester.getRect(find.widgetWithText(ElevatedButton, 'Yes'));
    expect(right.width, greaterThan(left.width));
  });

  group('friendlyError', () {
    test('explains connection problems', () {
      expect(friendlyError('SocketException: Failed host lookup'),
          contains('No internet'));
    });
    test('explains timeouts', () {
      expect(friendlyError('connection timeout'), contains('too long'));
    });
    test('keeps short human messages from the server', () {
      expect(friendlyError(Exception('Out of stock')), 'Out of stock');
    });
    test('hides raw Dio exceptions', () {
      expect(
          friendlyError(
              'DioException [bad response]: This exception was thrown because'),
          isNot(contains('DioException')));
    });
  });

  group('looksLikePhone', () {
    test('accepts Kenyan numbers', () {
      expect(looksLikePhone('0712 345 678'), isTrue);
      expect(looksLikePhone('+254712345678'), isTrue);
    });
    test('rejects names and short strings', () {
      expect(looksLikePhone('Jane Wanjiku'), isFalse);
      expect(looksLikePhone('12345'), isFalse);
    });
  });

  test('status colours are shared and known statuses are not the fallback', () {
    expect(AppTheme.statusColor('delivered'), AppColors.success);
    expect(AppTheme.statusColor('cancelled'), AppColors.danger);
    expect(AppTheme.statusColor('canceled'), AppColors.danger);
    expect(AppTheme.statusColor('in_transit'), isNot(AppTheme.statusColor('nonsense')));
  });

  testWidgets('StatusBadge shows a readable label', (tester) async {
    await tester.pumpWidget(_wrap(const StatusBadge(status: 'in_transit')));
    expect(find.text('In Transit'), findsOneWidget);
  });
}
