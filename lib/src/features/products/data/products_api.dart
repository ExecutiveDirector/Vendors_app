import '../../../core/api/dio_client.dart';
import 'product_model.dart';

class ProductsApi {
  static Future<List<Product>> list() async {
    final res = await ApiClient.dio.get('/vendors/inventory');
    final data = res.data;
    if (data is List) return data.map((e) => Product.fromJson(e)).toList();
    return [];
  }

  static Future<List<Product>> listCatalog() async {
    final res = await ApiClient.dio.get('/vendors/products');
    final data = res.data;
    if (data is List) return data.map((e) => Product.fromJson(e)).toList();
    return [];
  }

  static Future<Product> create(Map<String, dynamic> payload) async {
    final res = await ApiClient.dio.post('/vendors/products', data: payload);
    return Product.fromJson(
        res.data['product'] ?? res.data['data'] ?? res.data);
  }

  static Future<void> update(int id, Map<String, dynamic> payload) async {
    // Was PUT /admin/products/$id — that's an admin-only route
    // (requireAdminRole) and would 403 for every real vendor. The vendor
    // self-service endpoint is PUT /vendors/products/:productId
    // (vendorController.updateProduct).
    await ApiClient.dio.put('/vendors/products/$id', data: payload);
  }

  static Future<void> delete(String id) async {
    await ApiClient.dio.delete('/vendors/products/$id');
  }

  static Future<List<Category>> categories() async {
    final res = await ApiClient.dio.get('/vendors/product_categories');
    final data = res.data;
    if (data is List) return data.map((e) => Category.fromJson(e)).toList();
    return [];
  }

  static Future<List<dynamic>> outlets() async {
    final res = await ApiClient.dio.get('/vendors/outlets');
    return res.data is List ? res.data : [];
  }
}
