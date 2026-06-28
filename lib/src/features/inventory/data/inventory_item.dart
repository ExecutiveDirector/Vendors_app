// lib/src/features/inventory/data/inventory_item.dart

class InventoryItem {
  final String inventoryId;
  final String productId;
  final String productName;
  final String? sku; // product_code
  final String? brand;
  final String? description;
  final String? categoryName;
  final String? outletId;
  final String? outletName;
  final String? imageUrl;

  final int currentStock;
  final int reservedStock;
  final int availableStock;
  final int minimumStockLevel;
  final int maximumStockLevel;
  final int? reorderPoint;

  final double sellingPrice;
  final double costPrice;
  final double basePrice;

  final bool isAvailable;
  final String stockStatus; // 'in_stock' | 'low_stock' | 'out_of_stock'
  final bool needsReorder;

  final String? expiryDate;
  final String? batchNumber;
  final String? lastRestockedAt;
  final String? lastSoldAt;

  const InventoryItem({
    required this.inventoryId,
    required this.productId,
    required this.productName,
    this.sku,
    this.brand,
    this.description,
    this.categoryName,
    this.outletId,
    this.outletName,
    this.imageUrl,
    required this.currentStock,
    required this.reservedStock,
    required this.availableStock,
    required this.minimumStockLevel,
    required this.maximumStockLevel,
    this.reorderPoint,
    required this.sellingPrice,
    required this.costPrice,
    required this.basePrice,
    required this.isAvailable,
    required this.stockStatus,
    required this.needsReorder,
    this.expiryDate,
    this.batchNumber,
    this.lastRestockedAt,
    this.lastSoldAt,
  });

  bool get isOutOfStock => currentStock == 0;
  bool get isLowStock => currentStock > 0 && currentStock <= minimumStockLevel;
  bool get isInStock => currentStock > minimumStockLevel;

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      inventoryId: json['inventory_id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      productName: json['product_name']?.toString() ?? 'Unknown Product',
      sku: json['product_code']?.toString(),
      brand: json['brand']?.toString(),
      description: json['description']?.toString(),
      categoryName: json['category_name']?.toString(),
      outletId: json['outlet_id']?.toString(),
      outletName: json['outlet_name']?.toString(),
      imageUrl: json['image_url']?.toString(),
      currentStock: _parseInt(json['current_stock']),
      reservedStock: _parseInt(json['reserved_stock']),
      availableStock: _parseInt(json['available_stock']),
      minimumStockLevel: _parseInt(json['minimum_stock_level']),
      maximumStockLevel: _parseInt(json['maximum_stock_level']),
      reorderPoint: json['reorder_point'] != null
          ? _parseInt(json['reorder_point'])
          : null,
      sellingPrice: _parseDouble(json['selling_price']),
      costPrice: _parseDouble(json['cost_price']),
      basePrice: _parseDouble(json['base_price']),
      isAvailable: json['is_available'] == true || json['is_available'] == 1,
      stockStatus: json['stock_status']?.toString() ?? 'in_stock',
      needsReorder: json['needs_reorder'] == true || json['needs_reorder'] == 1,
      expiryDate: json['expiry_date']?.toString(),
      batchNumber: json['batch_number']?.toString(),
      lastRestockedAt: json['last_restocked_at']?.toString(),
      lastSoldAt: json['last_sold_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'inventory_id': inventoryId,
        'product_id': productId,
        'product_name': productName,
        'product_code': sku,
        'brand': brand,
        'category_name': categoryName,
        'outlet_id': outletId,
        'outlet_name': outletName,
        'image_url': imageUrl,
        'current_stock': currentStock,
        'reserved_stock': reservedStock,
        'available_stock': availableStock,
        'minimum_stock_level': minimumStockLevel,
        'maximum_stock_level': maximumStockLevel,
        'reorder_point': reorderPoint,
        'selling_price': sellingPrice,
        'cost_price': costPrice,
        'base_price': basePrice,
        'is_available': isAvailable,
        'stock_status': stockStatus,
        'needs_reorder': needsReorder,
        'expiry_date': expiryDate,
        'batch_number': batchNumber,
        'last_restocked_at': lastRestockedAt,
        'last_sold_at': lastSoldAt,
      };

  static int _parseInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }

  static double _parseDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
}
