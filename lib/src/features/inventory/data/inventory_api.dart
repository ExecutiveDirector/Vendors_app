// lib/src/features/inventory/data/inventory_api.dart
//
// API paths align with:  POST /vendors/inventory/:inventoryId/adjust
//                        GET  /vendors/inventory
//                        GET  /vendors/inventory/summary
//                        GET  /vendors/inventory/:inventoryId/movements
//                        PUT  /vendors/inventory/:inventoryId
//                        POST /vendors/inventory/bulk-adjust

import '../../../core/api/dio_client.dart';

class InventoryApi {
  // ── List with optional filters ──────────────────────────────────────────
  static Future<Map<String, dynamic>> list({
    int page = 1,
    int limit = 50,
    String? search,
    String? outletId,
    String? categoryId,
    bool? lowStock,
    bool? outOfStock,
    bool? needsReorder,
    bool? isAvailable,
    bool? expiringSoon,
    int expiryDays = 30,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'limit': limit,
    };
    if (search != null) params['search'] = search;
    if (outletId != null) params['outlet_id'] = outletId;
    if (categoryId != null) params['category_id'] = categoryId;
    if (lowStock == true) params['low_stock'] = 'true';
    if (outOfStock == true) params['out_of_stock'] = 'true';
    if (needsReorder == true) params['needs_reorder'] = 'true';
    if (isAvailable != null) params['is_available'] = isAvailable.toString();
    if (expiringSoon == true) {
      params['expiring_soon'] = 'true';
      params['expiry_days'] = expiryDays;
    }

    final res = await ApiClient.dio.get(
      '/vendors/inventory',
      queryParameters: params,
    );
    return res.data as Map<String, dynamic>;
  }

  // ── Summary stats (for dashboard widget) ────────────────────────────────
  static Future<Map<String, dynamic>> summary() async {
    final res = await ApiClient.dio.get('/vendors/inventory/summary');
    return (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
  }

  // ── Single item ──────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getItem(String inventoryId) async {
    final res = await ApiClient.dio.get('/vendors/inventory/$inventoryId');
    return (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
  }

  // ── Adjust stock (add or remove) ─────────────────────────────────────────
  // quantityChange: positive = add, negative = remove
  static Future<Map<String, dynamic>> adjust(
    String inventoryId,
    int quantityChange, {
    String?
        movementType, // 'stock_in'|'stock_out'|'adjustment'|'transfer'|'damaged'|'expired'
    String reason = 'manual',
    double? unitCost,
    String? notes,
    String? referenceType,
    String? referenceId,
  }) async {
    final data = <String, dynamic>{
      'quantity_change': quantityChange,
      'reason': reason,
    };
    if (movementType != null) data['movement_type'] = movementType;
    if (unitCost != null) data['unit_cost'] = unitCost;
    if (notes != null) data['notes'] = notes;
    if (referenceType != null) data['reference_type'] = referenceType;
    if (referenceId != null) data['reference_id'] = referenceId;

    final res = await ApiClient.dio.post(
      '/vendors/inventory/$inventoryId/adjust',
      data: data,
    );
    return res.data as Map<String, dynamic>;
  }

  // ── Update price / thresholds / availability ─────────────────────────────
  static Future<Map<String, dynamic>> updateItem(
    String inventoryId,
    Map<String, dynamic> updates,
  ) async {
    final res = await ApiClient.dio.put(
      '/vendors/inventory/$inventoryId',
      data: updates,
    );
    return res.data as Map<String, dynamic>;
  }

  // ── Movement history ─────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> movements(
    String inventoryId, {
    int page = 1,
    int limit = 20,
  }) async {
    final res = await ApiClient.dio.get(
      '/vendors/inventory/$inventoryId/movements',
      queryParameters: {'page': page, 'limit': limit},
    );
    return res.data as Map<String, dynamic>;
  }

  // ── Bulk adjust ──────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> bulkAdjust(
    List<Map<String, dynamic>> adjustments,
  ) async {
    final res = await ApiClient.dio.post(
      '/vendors/inventory/bulk-adjust',
      data: {'adjustments': adjustments},
    );
    return res.data as Map<String, dynamic>;
  }

  // ── Add new inventory record ──────────────────────────────────────────────
  static Future<Map<String, dynamic>> addItem({
    required String productId,
    required String outletId,
    required double sellingPrice,
    int currentStock = 0,
    double costPrice = 0,
    int minimumStockLevel = 5,
    int maximumStockLevel = 100,
    int reorderPoint = 10,
    String? expiryDate,
    String? batchNumber,
  }) async {
    final res = await ApiClient.dio.post(
      '/vendors/inventory',
      data: {
        'product_id': productId,
        'outlet_id': outletId,
        'selling_price': sellingPrice,
        'current_stock': currentStock,
        'cost_price': costPrice,
        'minimum_stock_level': minimumStockLevel,
        'maximum_stock_level': maximumStockLevel,
        'reorder_point': reorderPoint,
        if (expiryDate != null) 'expiry_date': expiryDate,
        if (batchNumber != null) 'batch_number': batchNumber,
      },
    );
    return res.data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> create(
      Map<String, dynamic> payload) async {
    final res = await ApiClient.dio.post('/vendors/outlets', data: payload);
    return res.data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> update(
      String outletId, Map<String, dynamic> payload) async {
    final res =
        await ApiClient.dio.put('/vendors/outlets/$outletId', data: payload);
    return res.data as Map<String, dynamic>;
  }
}
