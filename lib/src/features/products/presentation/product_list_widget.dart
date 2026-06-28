import 'package:flutter/material.dart';
import 'product_card_widget.dart';

class ProductListWidget extends StatelessWidget {
  // final List<Map<String, dynamic>> products;
  final List<dynamic> products;
  final Future<void> Function() refresh;
  final void Function(int) onDelete;
  final void Function(Map<String, dynamic>) onEdit;
  final void Function(Map<String, dynamic>) onTap;

  const ProductListWidget({
    super.key,
    required this.products,
    required this.onDelete,
    required this.onEdit,
    required this.onTap,
    required this.refresh,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No products found',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first product to get started',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final product = products[index];
          final int? id = product['product_id'] is int
              ? product['product_id']
              : int.tryParse(product['product_id'].toString());

          return ProductCardWidget(
            product: product,
            onDelete: () {
              if (id != null) onDelete(id);
            },
            onEdit: () => onEdit(product),
            onTap: () => onTap(product),
          );
        },
      ),
    );
  }
}
