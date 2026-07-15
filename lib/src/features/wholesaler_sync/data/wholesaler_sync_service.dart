// lib/src/features/wholesaler_sync/data/wholesaler_sync_service.dart
//
// Vendor self-service API calls for the WhatsApp wholesaler -> catalog
// automation. Endpoint map (see backend routes/catalogStaging.js):
//   GET    /vendors/wholesaler-sources
//   POST   /vendors/wholesaler-sources
//   PATCH  /vendors/wholesaler-sources/:sourceId
//   GET    /vendors/catalog-staging?status=pending_review
//   POST   /vendors/catalog-staging/:stagingId/approve
//   POST   /vendors/catalog-staging/:stagingId/reject
//
// Mirrors the style of ../../inventory/presentation/inventory_service.dart
// (plain service class over ApiClient.dio, defensive response unwrapping,
// friendly error messages).

import 'dart:convert';
import 'package:dio/dio.dart';
import '../../../core/api/dio_client.dart';
import 'wholesaler_sync_models.dart';

class WholesalerSyncService {
  final Dio _dio = ApiClient.dio;

  // ── Sources ──────────────────────────────────────────────────────────────

  Future<List<WholesalerSource>> fetchSources() async {
    try {
      final res = await _dio.get('/vendors/wholesaler-sources');
      final raw = _unwrap(res.data);
      return (raw as List)
          .map((e) => WholesalerSource.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _friendlyError('load WhatsApp sources', e);
    }
  }

  Future<WholesalerSource> createSource({
    required String whatsappGroupJid,
    String? sourceLabel,
    String? wholesalerName,
    String? outletId,
    bool autoApplyKnownProducts = true,
  }) async {
    try {
      final res = await _dio.post('/vendors/wholesaler-sources', data: {
        'whatsapp_group_jid': whatsappGroupJid,
        if (sourceLabel != null) 'source_label': sourceLabel,
        if (wholesalerName != null) 'wholesaler_name': wholesalerName,
        if (outletId != null) 'outlet_id': outletId,
        'auto_apply_known_products': autoApplyKnownProducts,
      });
      return WholesalerSource.fromJson(_unwrap(res.data) as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _friendlyError('register WhatsApp group', e);
    }
  }

  Future<void> updateSource(
    String sourceId, {
    String? status,
    bool? autoApplyKnownProducts,
  }) async {
    try {
      await _dio.patch('/vendors/wholesaler-sources/$sourceId', data: {
        if (status != null) 'status': status,
        if (autoApplyKnownProducts != null)
          'auto_apply_known_products': autoApplyKnownProducts,
      });
    } on DioException catch (e) {
      throw _friendlyError('update WhatsApp source', e);
    }
  }

  // ── Review queue ─────────────────────────────────────────────────────────

  Future<List<CatalogStagingItem>> fetchStagingItems({
    String status = 'pending_review',
  }) async {
    try {
      final res = await _dio.get(
        '/vendors/catalog-staging',
        queryParameters: {'status': status},
      );
      final raw = _unwrap(res.data);
      return (raw as List)
          .map((e) => CatalogStagingItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _friendlyError('load review queue', e);
    }
  }

  /// Approve a staged item — publishes it to the live catalog.
  /// For brand-new products, pass [categoryId] to confirm/correct the
  /// suggested category, and optionally [marginPctOverride] to override the
  /// category's default margin for this one item.
  Future<void> approveStagingItem(
    String stagingId, {
    int? categoryId,
    double? marginPctOverride,
    String? outletId,
  }) async {
    try {
      await _dio.post('/vendors/catalog-staging/$stagingId/approve', data: {
        if (categoryId != null) 'category_id': categoryId,
        if (marginPctOverride != null) 'margin_pct_override': marginPctOverride,
        if (outletId != null) 'outlet_id': outletId,
      });
    } on DioException catch (e) {
      throw _friendlyError('approve item', e);
    }
  }

  Future<void> rejectStagingItem(String stagingId) async {
    try {
      await _dio.post('/vendors/catalog-staging/$stagingId/reject');
    } on DioException catch (e) {
      throw _friendlyError('reject item', e);
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  dynamic _unwrap(dynamic raw) {
    if (raw is String) {
      try {
        raw = jsonDecode(raw);
      } catch (_) {}
    }
    if (raw is Map && raw.containsKey('data')) return raw['data'];
    return raw;
  }

  String _friendlyError(String op, DioException e) {
    final status = e.response?.statusCode;
    final msg = e.response?.data is Map
        ? e.response!.data['message'] ?? e.response!.data['error']
        : null;
    if (msg != null) return 'Failed to $op: $msg';
    if (status != null) return 'Failed to $op (HTTP $status)';
    return 'Failed to $op: ${e.message}';
  }
}
