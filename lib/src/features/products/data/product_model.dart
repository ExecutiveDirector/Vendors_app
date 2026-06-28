class Product {
  final int productId;
  final String productName;
  final String? productCode;
  final String? brand;
  final String? description;
  final String? sizeSpecification;
  final double basePrice;
  final bool isActive;
  final bool isFeatured;
  final String? categoryName;
  final int? categoryId;
  final int? currentStock;
  final double? sellingPrice;
  final String? inventoryId;
  final String? outletName;
  final dynamic productImages;

  const Product({
    required this.productId,
    required this.productName,
    this.productCode,
    this.brand,
    this.description,
    this.sizeSpecification,
    required this.basePrice,
    this.isActive = true,
    this.isFeatured = false,
    this.categoryName,
    this.categoryId,
    this.currentStock,
    this.sellingPrice,
    this.inventoryId,
    this.outletName,
    this.productImages,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      productId: json['product_id'] ?? json['id'] ?? 0,
      productName: json['product_name'] ?? json['title'] ?? '',
      productCode: json['product_code'],
      brand: json['brand'],
      description: json['description'],
      sizeSpecification: json['size_specification'],
      basePrice: _toDouble(json['base_price'] ?? json['price'] ?? 0),
      isActive: _toBool(json['is_active'] ?? true),
      isFeatured: _toBool(json['is_featured'] ?? false),
      categoryName: json['category_name'] ?? json['category']?['category_name'],
      categoryId: json['category_id'],
      currentStock: json['current_stock'],
      sellingPrice: _toDouble(json['selling_price']),
      inventoryId: json['inventory_id']?.toString(),
      outletName: json['outlet_name'],
      productImages: json['product_images'],
    );
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  static bool _toBool(dynamic v) {
    if (v is bool) return v;
    if (v is int) return v == 1;
    return false;
  }

  Map<String, dynamic> toJson() => {
        'product_name': productName,
        'product_code': productCode,
        'brand': brand,
        'description': description,
        'size_specification': sizeSpecification,
        'base_price': basePrice,
        'is_active': isActive,
        'is_featured': isFeatured,
        'category_id': categoryId,
      };
}

class Category {
  final int categoryId;
  final String categoryName;
  final String? description;

  const Category({
    required this.categoryId,
    required this.categoryName,
    this.description,
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        categoryId: json['category_id'] ?? 0,
        categoryName: json['category_name'] ?? '',
        description: json['description'],
      );
}
