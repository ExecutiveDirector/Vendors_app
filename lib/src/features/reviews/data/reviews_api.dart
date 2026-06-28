import '../../../core/api/dio_client.dart';

class VendorReview {
  final int reviewId;
  final int orderId;
  final double overallRating;
  final double? serviceRating;
  final double? qualityRating;
  final double? deliveryRating;
  final String? title;
  final String? reviewText;
  final bool isAnonymous;
  final String? vendorResponse;
  final DateTime? vendorResponseAt;
  final DateTime createdAt;

  VendorReview({
    required this.reviewId,
    required this.orderId,
    required this.overallRating,
    required this.serviceRating,
    required this.qualityRating,
    required this.deliveryRating,
    required this.title,
    required this.reviewText,
    required this.isAnonymous,
    required this.vendorResponse,
    required this.vendorResponseAt,
    required this.createdAt,
  });

  bool get hasResponse => vendorResponse != null && vendorResponse!.isNotEmpty;

  factory VendorReview.fromJson(Map<String, dynamic> json) {
    return VendorReview(
      reviewId: int.tryParse(json['review_id']?.toString() ?? '') ?? 0,
      orderId: int.tryParse(json['order_id']?.toString() ?? '') ?? 0,
      overallRating:
          double.tryParse(json['overall_rating']?.toString() ?? '') ?? 0,
      serviceRating: json['service_rating'] == null
          ? null
          : double.tryParse(json['service_rating'].toString()),
      qualityRating: json['quality_rating'] == null
          ? null
          : double.tryParse(json['quality_rating'].toString()),
      deliveryRating: json['delivery_rating'] == null
          ? null
          : double.tryParse(json['delivery_rating'].toString()),
      title: json['review_title']?.toString(),
      reviewText: json['review_text']?.toString(),
      isAnonymous: json['is_anonymous'] == true || json['is_anonymous'] == 1,
      vendorResponse: json['vendor_response']?.toString(),
      vendorResponseAt: json['vendor_response_at'] == null
          ? null
          : DateTime.tryParse(json['vendor_response_at'].toString()),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

/// Self-service "my reviews" — backed by GET /vendors/reviews, which
/// resolves the vendor's own id server-side rather than taking one in the
/// URL (see vendors.js route registration).
class ReviewsApi {
  static Future<List<VendorReview>> list() async {
    final res = await ApiClient.dio.get('/vendors/reviews');
    final List<dynamic> data = res.data is List ? res.data : [];
    return data
        .map((e) => VendorReview.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Backed by POST /vendors/reviews/:reviewId/respond.
  static Future<void> respond(int reviewId, String response) async {
    await ApiClient.dio.post(
      '/vendors/reviews/$reviewId/respond',
      data: {'response': response},
    );
  }
}
