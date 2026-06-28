import '../../../core/api/dio_client.dart';

/// A platform-wide or vendor-targeted promotion that currently applies to
/// this vendor. Promotions are admin/platform-managed (see backend
/// vendorController.getVendorPromotions) — vendors can see which ones
/// apply to them, but can't create or edit promotions themselves.
class VendorPromotion {
  final int promotionId;
  final String code;
  final String name;
  final String discountType;
  final double discountValue;
  final double? maximumDiscount;
  final double minimumOrderAmount;
  final int currentUsageCount;
  final int? totalUsageLimit;
  final DateTime validFrom;
  final DateTime? validTo;
  final bool isActive;
  final String? termsAndConditions;

  VendorPromotion({
    required this.promotionId,
    required this.code,
    required this.name,
    required this.discountType,
    required this.discountValue,
    required this.maximumDiscount,
    required this.minimumOrderAmount,
    required this.currentUsageCount,
    required this.totalUsageLimit,
    required this.validFrom,
    required this.validTo,
    required this.isActive,
    required this.termsAndConditions,
  });

  /// Human-readable discount, e.g. "10% off" or "KES 200 off".
  String get discountLabel {
    switch (discountType) {
      case 'percentage':
        return '${discountValue.toStringAsFixed(0)}% off';
      case 'fixed_amount':
        return 'KES ${discountValue.toStringAsFixed(0)} off';
      case 'free_delivery':
        return 'Free delivery';
      case 'buy_one_get_one':
        return 'Buy one, get one';
      default:
        return discountType;
    }
  }

  factory VendorPromotion.fromJson(Map<String, dynamic> json) {
    return VendorPromotion(
      promotionId: int.tryParse(json['promotion_id']?.toString() ?? '') ?? 0,
      code: json['promotion_code']?.toString() ?? '',
      name: json['promotion_name']?.toString() ?? '',
      discountType: json['discount_type']?.toString() ?? 'percentage',
      discountValue:
          double.tryParse(json['discount_value']?.toString() ?? '') ?? 0,
      maximumDiscount: json['maximum_discount'] == null
          ? null
          : double.tryParse(json['maximum_discount'].toString()),
      minimumOrderAmount:
          double.tryParse(json['minimum_order_amount']?.toString() ?? '') ??
              0,
      currentUsageCount:
          int.tryParse(json['current_usage_count']?.toString() ?? '') ?? 0,
      totalUsageLimit: json['total_usage_limit'] == null
          ? null
          : int.tryParse(json['total_usage_limit'].toString()),
      validFrom: DateTime.tryParse(json['valid_from']?.toString() ?? '') ??
          DateTime.now(),
      validTo: json['valid_to'] == null
          ? null
          : DateTime.tryParse(json['valid_to'].toString()),
      isActive: json['is_active'] == true || json['is_active'] == 1,
      termsAndConditions: json['terms_and_conditions']?.toString(),
    );
  }
}

class PromotionsApi {
  /// Active promotions that currently apply to this vendor — either
  /// platform-wide, or explicitly targeted at this vendor_id.
  /// Backed by GET /vendors/promotions.
  static Future<List<VendorPromotion>> list() async {
    final res = await ApiClient.dio.get('/vendors/promotions');
    final List<dynamic> data = res.data is List ? res.data : [];
    return data
        .map((e) => VendorPromotion.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
