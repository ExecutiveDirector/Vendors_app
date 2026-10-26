import 'package:dio/dio.dart';

import '../../../core/api/dio_client.dart';

class VendorEarnings {
  final double earned;
  final double committed;
  final double available;
  final double minPayout;
  const VendorEarnings({
    required this.earned,
    required this.committed,
    required this.available,
    required this.minPayout,
  });

  static double _d(Object? v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

  factory VendorEarnings.fromJson(Map<String, dynamic> j) => VendorEarnings(
        earned: _d(j['earned']),
        committed: _d(j['withdrawn_or_pending']),
        available: _d(j['available']),
        minPayout: _d(j['min_payout']),
      );
}

class VendorPayout {
  final String id;
  final double amount;
  final String status;
  final String method;
  final String? rejectionReason;
  final DateTime? createdAt;
  const VendorPayout({
    required this.id,
    required this.amount,
    required this.status,
    required this.method,
    this.rejectionReason,
    this.createdAt,
  });

  factory VendorPayout.fromJson(Map<String, dynamic> j) => VendorPayout(
        id: '${j['id']}',
        amount: VendorEarnings._d(j['amount']),
        status: '${j['status']}',
        method: '${j['method']}',
        rejectionReason: j['rejection_reason'] as String?,
        createdAt: DateTime.tryParse('${j['created_at']}'),
      );
}

class PayoutsApi {
  static Future<VendorEarnings> earnings() async {
    final res = await ApiClient.dio.get('/vendors/earnings');
    return VendorEarnings.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  static Future<List<VendorPayout>> list() async {
    final res = await ApiClient.dio.get('/vendors/payouts');
    final rows = (res.data is Map ? res.data['payouts'] : null) as List? ?? [];
    return rows.map((e) => VendorPayout.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  /// Returns null on success, otherwise a message to show.
  static Future<String?> request({
    required double amount,
    required bool bank,
    String mpesaPhone = '',
    String bankName = '',
    String bankAccountNumber = '',
    String bankAccountName = '',
  }) async {
    try {
      await ApiClient.dio.post('/vendors/payouts/request', data: {
        'amount': amount,
        'method': bank ? 'bank_transfer' : 'mpesa',
        if (!bank && mpesaPhone.isNotEmpty) 'mpesa_phone': mpesaPhone,
        if (bank) 'bank_name': bankName,
        if (bank) 'bank_account_number': bankAccountNumber,
        if (bank) 'bank_account_name': bankAccountName,
      });
      return null;
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['error'] != null) return '${data['error']}';
      return 'Could not send the request. Check your connection and try again.';
    }
  }
}
