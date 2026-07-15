// lib/src/features/wholesaler_sync/data/wholesaler_sync_models.dart

class WholesalerSource {
  final String sourceId;
  final String whatsappGroupJid;
  final String? sourceLabel;
  final String? wholesalerName;
  final bool autoApplyKnownProducts;
  final String status; // active | paused | disconnected
  final String? lastMessageAt;

  WholesalerSource({
    required this.sourceId,
    required this.whatsappGroupJid,
    this.sourceLabel,
    this.wholesalerName,
    required this.autoApplyKnownProducts,
    required this.status,
    this.lastMessageAt,
  });

  factory WholesalerSource.fromJson(Map<String, dynamic> json) {
    return WholesalerSource(
      sourceId: json['source_id'].toString(),
      whatsappGroupJid: json['whatsapp_group_jid'] as String,
      sourceLabel: json['source_label'] as String?,
      wholesalerName: json['wholesaler_name'] as String?,
      autoApplyKnownProducts: json['auto_apply_known_products'] == true ||
          json['auto_apply_known_products'] == 1,
      status: json['status'] as String? ?? 'disconnected',
      lastMessageAt: json['last_message_at']?.toString(),
    );
  }
}

class CatalogStagingItem {
  final String stagingId;
  final String extractedName;
  final String? extractedUnit;
  final String? extractedSize;
  final double wholesaleCost;
  final int? suggestedCategoryId;
  final String? suggestedCategoryName;
  final String? matchedProductId;
  final String? matchedProductName;
  final double? matchConfidence;
  final String matchType; // exact | fuzzy | llm_assisted | none
  final double? computedRetailPrice;
  final String status; // pending_review | auto_applied | approved | rejected
  final String? reviewReason;

  bool get isNewProduct => matchedProductId == null;

  CatalogStagingItem({
    required this.stagingId,
    required this.extractedName,
    this.extractedUnit,
    this.extractedSize,
    required this.wholesaleCost,
    this.suggestedCategoryId,
    this.suggestedCategoryName,
    this.matchedProductId,
    this.matchedProductName,
    this.matchConfidence,
    required this.matchType,
    this.computedRetailPrice,
    required this.status,
    this.reviewReason,
  });

  factory CatalogStagingItem.fromJson(Map<String, dynamic> json) {
    return CatalogStagingItem(
      stagingId: json['staging_id'].toString(),
      extractedName: json['extracted_name'] as String,
      extractedUnit: json['extracted_unit'] as String?,
      extractedSize: json['extracted_size'] as String?,
      wholesaleCost: double.tryParse(json['wholesale_cost'].toString()) ?? 0,
      suggestedCategoryId: json['suggested_category_id'] as int?,
      suggestedCategoryName:
          (json['suggested_category'] as Map<String, dynamic>?)?['category_name']
              as String?,
      matchedProductId: json['matched_product_id']?.toString(),
      matchedProductName:
          (json['matched_product'] as Map<String, dynamic>?)?['product_name']
              as String?,
      matchConfidence: json['match_confidence'] != null
          ? double.tryParse(json['match_confidence'].toString())
          : null,
      matchType: json['match_type'] as String? ?? 'none',
      computedRetailPrice: json['computed_retail_price'] != null
          ? double.tryParse(json['computed_retail_price'].toString())
          : null,
      status: json['status'] as String? ?? 'pending_review',
      reviewReason: json['review_reason'] as String?,
    );
  }

  /// Human-friendly explanation of why this needs a manual look.
  String get friendlyReviewReason {
    switch (reviewReason) {
      case 'new_or_unmatched_product':
        return "Couldn't confidently match an existing product";
      case 'auto_apply_disabled_for_source':
        return 'Auto-apply is off for this WhatsApp group';
      default:
        if (reviewReason?.startsWith('price_jump_over_') == true) {
          final pct = reviewReason!
              .replaceAll('price_jump_over_', '')
              .replaceAll('pct', '');
          return 'Wholesale price jumped more than $pct% — check for a typo';
        }
        return reviewReason ?? '';
    }
  }
}
