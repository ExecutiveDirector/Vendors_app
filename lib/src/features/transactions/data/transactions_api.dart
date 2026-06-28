import '../../../core/api/dio_client.dart';

class VendorTransaction {
  final int transactionId;
  final String transactionRef;
  final String transactionType;
  final double amount;
  final String currency;
  final String status;
  final String paymentGateway;
  final DateTime initiatedAt;
  final DateTime? completedAt;
  final String? orderNumber;
  final String? orderStatus;

  VendorTransaction({
    required this.transactionId,
    required this.transactionRef,
    required this.transactionType,
    required this.amount,
    required this.currency,
    required this.status,
    required this.paymentGateway,
    required this.initiatedAt,
    required this.completedAt,
    required this.orderNumber,
    required this.orderStatus,
  });

  factory VendorTransaction.fromJson(Map<String, dynamic> json) {
    final order = json['order'] as Map<String, dynamic>?;
    return VendorTransaction(
      transactionId:
          int.tryParse(json['transaction_id']?.toString() ?? '') ?? 0,
      transactionRef: json['transaction_ref']?.toString() ?? '',
      transactionType: json['transaction_type']?.toString() ?? 'payment',
      amount: double.tryParse(json['amount']?.toString() ?? '') ?? 0,
      currency: json['currency']?.toString() ?? 'KES',
      status: json['status']?.toString() ?? 'pending',
      paymentGateway: json['payment_gateway']?.toString() ?? '',
      initiatedAt:
          DateTime.tryParse(json['initiated_at']?.toString() ?? '') ??
              DateTime.now(),
      completedAt: json['completed_at'] == null
          ? null
          : DateTime.tryParse(json['completed_at'].toString()),
      orderNumber: order?['order_number']?.toString(),
      orderStatus: order?['order_status']?.toString(),
    );
  }
}

class TransactionsPage {
  final List<VendorTransaction> transactions;
  final int total;
  final int page;
  final int pages;

  TransactionsPage({
    required this.transactions,
    required this.total,
    required this.page,
    required this.pages,
  });
}

class TransactionsApi {
  /// Backed by GET /vendors/transactions — joins through orders since the
  /// transactions table has no vendor_id column of its own.
  static Future<TransactionsPage> list({
    int page = 1,
    int limit = 20,
    String? status,
    String? type,
  }) async {
    final res = await ApiClient.dio.get('/vendors/transactions', queryParameters: {
      'page': page,
      'limit': limit,
      if (status != null) 'status': status,
      if (type != null) 'type': type,
    });

    final data = res.data;
    final List<dynamic> rows = data is Map ? (data['transactions'] ?? []) : (data is List ? data : []);

    return TransactionsPage(
      transactions: rows
          .map((e) => VendorTransaction.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: data is Map ? (data['total'] ?? rows.length) : rows.length,
      page: data is Map ? (data['page'] ?? page) : page,
      pages: data is Map ? (data['pages'] ?? 1) : 1,
    );
  }
}
