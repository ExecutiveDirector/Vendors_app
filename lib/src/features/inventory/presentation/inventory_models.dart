// inventory_models.dart
// Aligned to exact DB schema columns.
//
//   vendor_inventory  — no sku/image_url/category_name columns on the table;
//                       those arrive via JOIN to products & product_categories
//   vendor_outlets    — contact_phone (not phone/email), address_line_1/city/county,
//                       operating_hours JSON (not opening_time/closing_time)
//   vendor_analytics  — daily row used by the analytics summary widget

// ─────────────────────────────────────────────────────────────────────────────
// VendorInventory
// ─────────────────────────────────────────────────────────────────────────────
class VendorInventory {
  final int inventoryId;
  final int outletId;
  final String outletName; // denormalized on vendor_inventory
  final int productId;
  final String productName; // denormalized on vendor_inventory
  final String sku; // products.product_code  (JOIN)
  final String categoryName; // product_categories.category_name (JOIN)
  final String? imageUrl; // first item from products.product_images (JOIN)
  final int currentStock;
  final int reservedStock;
  final int minimumStockLevel;
  final int maximumStockLevel;
  final int reorderPoint;
  final double costPrice;
  final double sellingPrice;
  final DateTime? expiryDate;
  final String? batchNumber;
  final bool isAvailable;
  final DateTime? lastRestockedAt;
  final DateTime? lastSoldAt;

  const VendorInventory({
    required this.inventoryId,
    required this.outletId,
    required this.outletName,
    required this.productId,
    required this.productName,
    required this.sku,
    required this.categoryName,
    this.imageUrl,
    required this.currentStock,
    required this.reservedStock,
    required this.minimumStockLevel,
    required this.maximumStockLevel,
    required this.reorderPoint,
    required this.costPrice,
    required this.sellingPrice,
    required this.isAvailable,
    this.expiryDate,
    this.batchNumber,
    this.lastRestockedAt,
    this.lastSoldAt,
  });

  factory VendorInventory.fromJson(Map<String, dynamic> j) => VendorInventory(
        inventoryId: _int(j['inventory_id']),
        outletId: _int(j['outlet_id']),
        outletName: j['outlet_name']?.toString() ?? '',
        productId: _int(j['product_id']),
        productName: j['product_name']?.toString() ?? 'Unknown',
        sku: j['sku']?.toString() ?? j['product_code']?.toString() ?? 'N/A',
        categoryName: j['category_name']?.toString() ?? 'Uncategorized',
        imageUrl: _firstImage(j['product_images'] ?? j['image_url']),
        currentStock: _int(j['current_stock']),
        reservedStock: _int(j['reserved_stock']),
        minimumStockLevel: _int(j['minimum_stock_level']),
        maximumStockLevel: _int(j['maximum_stock_level']),
        reorderPoint: _int(j['reorder_point']),
        costPrice: _double(j['cost_price']),
        sellingPrice: _double(j['selling_price']),
        isAvailable: j['is_available'] == 1 || j['is_available'] == true,
        expiryDate: j['expiry_date'] != null
            ? DateTime.tryParse(j['expiry_date'].toString())
            : null,
        batchNumber: j['batch_number']?.toString(),
        lastRestockedAt: j['last_restocked_at'] != null
            ? DateTime.tryParse(j['last_restocked_at'].toString())
            : null,
        lastSoldAt: j['last_sold_at'] != null
            ? DateTime.tryParse(j['last_sold_at'].toString())
            : null,
      );

  VendorInventory copyWith(
          {int? currentStock, int? reservedStock, bool? isAvailable}) =>
      VendorInventory(
        inventoryId: inventoryId,
        outletId: outletId,
        outletName: outletName,
        productId: productId,
        productName: productName,
        sku: sku,
        categoryName: categoryName,
        imageUrl: imageUrl,
        currentStock: currentStock ?? this.currentStock,
        reservedStock: reservedStock ?? this.reservedStock,
        minimumStockLevel: minimumStockLevel,
        maximumStockLevel: maximumStockLevel,
        reorderPoint: reorderPoint,
        costPrice: costPrice,
        sellingPrice: sellingPrice,
        isAvailable: isAvailable ?? this.isAvailable,
        expiryDate: expiryDate,
        batchNumber: batchNumber,
        lastRestockedAt: lastRestockedAt,
        lastSoldAt: lastSoldAt,
      );

  // ── Derived status flags ──────────────────────────────────────────────────
  bool get isOutOfStock => currentStock == 0;
  bool get isLowStock => currentStock > 0 && currentStock <= minimumStockLevel;
  bool get isAtReorderPoint => currentStock > 0 && currentStock <= reorderPoint;
  bool get isExpiringSoon =>
      expiryDate != null &&
      expiryDate!.isBefore(DateTime.now().add(const Duration(days: 30)));

  /// Stock actually available to promise (excludes reserved)
  int get availableStock =>
      (currentStock - reservedStock).clamp(0, currentStock);

  /// 0.0–1.0 fill level relative to maximum
  double get stockFillRatio =>
      maximumStockLevel > 0 ? currentStock / maximumStockLevel : 0;
}

// ─────────────────────────────────────────────────────────────────────────────
// VendorOutlet  — mirrors vendor_outlets exactly
// ─────────────────────────────────────────────────────────────────────────────
class VendorOutlet {
  final int outletId;
  final int vendorId;
  final String outletName;
  final String outletCode;
  final String addressLine1;
  final String? addressLine2;
  final String city;
  final String county;
  final String? postalCode;
  final double latitude;
  final double longitude;
  final String? contactPhone; // schema: contact_phone
  final String? managerName;
  final Map<String, dynamic>? operatingHours; // schema: operating_hours JSON
  final bool isActive;

  const VendorOutlet({
    required this.outletId,
    required this.vendorId,
    required this.outletName,
    required this.outletCode,
    required this.addressLine1,
    this.addressLine2,
    required this.city,
    required this.county,
    this.postalCode,
    required this.latitude,
    required this.longitude,
    this.contactPhone,
    this.managerName,
    this.operatingHours,
    required this.isActive,
  });

  factory VendorOutlet.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic>? hours;
    final raw = j['operating_hours'];
    if (raw is Map) hours = Map<String, dynamic>.from(raw);

    return VendorOutlet(
      outletId: _int(j['outlet_id']),
      vendorId: _int(j['vendor_id']),
      outletName: j['outlet_name']?.toString() ?? '',
      outletCode: j['outlet_code']?.toString() ?? '',
      addressLine1: j['address_line_1']?.toString() ?? '',
      addressLine2: j['address_line_2']?.toString(),
      city: j['city']?.toString() ?? '',
      county: j['county']?.toString() ?? '',
      postalCode: j['postal_code']?.toString(),
      latitude: _double(j['latitude']),
      longitude: _double(j['longitude']),
      contactPhone: j['contact_phone']?.toString(),
      managerName: j['manager_name']?.toString(),
      operatingHours: hours,
      isActive: j['is_active'] == 1 || j['is_active'] == true,
    );
  }

  String get formattedAddress => [
        addressLine1,
        if (addressLine2 != null) addressLine2!,
        city,
        county
      ].where((s) => s.isNotEmpty).join(', ');
}

// ─────────────────────────────────────────────────────────────────────────────
// ProductCategory
// ─────────────────────────────────────────────────────────────────────────────
class ProductCategory {
  final int categoryId;
  final String categoryName;

  const ProductCategory({required this.categoryId, required this.categoryName});

  factory ProductCategory.fromJson(Map<String, dynamic> j) => ProductCategory(
        categoryId: _int(j['category_id']),
        categoryName: j['category_name']?.toString() ?? 'Uncategorized',
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// VendorAnalytics  — mirrors vendor_analytics daily row
// ─────────────────────────────────────────────────────────────────────────────
class VendorAnalytics {
  final int analyticsId;
  final int vendorId;
  final DateTime reportDate;
  final int completedOrders;
  final double totalRevenue;
  final double avgPrepTimeMinutes;
  final double avgRating;
  final int productsOutOfStock;
  final int lowStockProducts;

  const VendorAnalytics({
    required this.analyticsId,
    required this.vendorId,
    required this.reportDate,
    required this.completedOrders,
    required this.totalRevenue,
    required this.avgPrepTimeMinutes,
    required this.avgRating,
    required this.productsOutOfStock,
    required this.lowStockProducts,
  });

  factory VendorAnalytics.fromJson(Map<String, dynamic> j) => VendorAnalytics(
        analyticsId: _int(j['analytics_id']),
        vendorId: _int(j['vendor_id']),
        reportDate: DateTime.tryParse(j['report_date']?.toString() ?? '') ??
            DateTime.now(),
        completedOrders: _int(j['completed_orders']),
        totalRevenue: _double(j['total_revenue']),
        avgPrepTimeMinutes: _double(j['average_preparation_time_minutes']),
        avgRating: _double(j['average_rating']),
        productsOutOfStock: _int(j['products_out_of_stock']),
        lowStockProducts: _int(j['low_stock_products']),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Private parse helpers
// ─────────────────────────────────────────────────────────────────────────────
int _int(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is double) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

double _double(dynamic v) {
  if (v == null) return 0.0;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

/// Extracts the first image URL from product_images (string URL, JSON array, JSON object).
String? _firstImage(dynamic raw) {
  if (raw == null) return null;
  if (raw is String) {
    if (raw.startsWith('http')) return raw;
    final t = raw.trim();
    if (t.startsWith('[')) {
      final m = RegExp(r'"(https?://[^"]+)"').firstMatch(t);
      return m?.group(1);
    }
    if (t.startsWith('{')) {
      final m = RegExp(r'"url"\s*:\s*"(https?://[^"]+)"').firstMatch(t);
      return m?.group(1);
    }
  }
  if (raw is List && raw.isNotEmpty) return raw.first?.toString();
  return null;
}
