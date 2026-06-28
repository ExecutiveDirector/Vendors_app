// lib/src/features/products/presentation/products_screen.dart
//
// Changes (Catalog tab only):
//  • _CatalogTab now shows a real product thumbnail (same image-parsing logic
//    as ProductCardWidget) instead of the generic fastfood icon
//  • Falls back to a branded placeholder (green bg + inventory icon) when
//    no image is available
//  • Everything else (InventoryTab, search, FAB, etc.) is unchanged

import 'dart:convert';
import 'package:flutter/material.dart';
import '../data/product_model.dart';
import '../data/products_api.dart';
import 'product_form_screen.dart';
import '../../../core/widgets/shared_widgets.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});
  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Product> _inventory = [];
  List<Product> _catalog = [];
  bool _loading = true;
  String? _error;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        ProductsApi.list(),
        ProductsApi.listCatalog(),
      ]);
      if (mounted) {
        setState(() {
          _inventory = results[0];
          _catalog = results[1];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _delete(Product p) async {
    final ok = await showConfirmDialog(context,
        title: 'Delete Product',
        content: 'Delete "${p.productName}"? This cannot be undone.',
        confirmLabel: 'Delete',
        confirmColor: Colors.red);
    if (ok != true) return;
    try {
      await ProductsApi.delete(p.productId.toString());
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Product deleted'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _openForm([Product? p]) async {
    final result = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => ProductFormScreen(product: p)));
    if (result == true) _load();
  }

  List<Product> get _filteredInventory {
    if (_search.isEmpty) return _inventory;
    final q = _search.toLowerCase();
    return _inventory
        .where((p) =>
            p.productName.toLowerCase().contains(q) ||
            (p.productCode?.toLowerCase().contains(q) ?? false) ||
            (p.brand?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  List<Product> get _filteredCatalog {
    if (_search.isEmpty) return _catalog;
    final q = _search.toLowerCase();
    return _catalog
        .where((p) =>
            p.productName.toLowerCase().contains(q) ||
            (p.productCode?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Products'),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: 'Inventory (${_inventory.length})'),
            Tab(text: 'Catalog (${_catalog.length})'),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: const InputDecoration(
              hintText: 'Search products...',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const AppLoading()
              : _error != null
                  ? AppError(message: _error!, onRetry: _load)
                  : TabBarView(
                      controller: _tabs,
                      children: [
                        _InventoryTab(
                            products: _filteredInventory,
                            onDelete: _delete,
                            onEdit: _openForm),
                        _CatalogTab(
                            products: _filteredCatalog,
                            onDelete: _delete,
                            onEdit: _openForm),
                      ],
                    ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
    );
  }
}

// ─── Inventory Tab (unchanged) ─────────────────────────────────────────────
class _InventoryTab extends StatelessWidget {
  final List<Product> products;
  final void Function(Product) onDelete;
  final void Function(Product) onEdit;
  const _InventoryTab(
      {required this.products, required this.onDelete, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const AppEmpty(
        icon: Icons.inventory_2_outlined,
        message: 'No inventory items found.\nAdd products to your outlets.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
      itemCount: products.length,
      itemBuilder: (_, i) {
        final p = products[i];
        final stock = p.currentStock ?? 0;
        final isLow = stock > 0 && stock <= 5;
        final isOut = stock == 0;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: isOut
                  ? Colors.red.shade50
                  : isLow
                      ? Colors.orange.shade50
                      : Colors.teal.shade50,
              child: Text(stock.toString(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isOut
                        ? Colors.red
                        : isLow
                            ? Colors.orange
                            : Colors.teal,
                  )),
            ),
            title: Text(p.productName,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (p.productCode != null)
                  Text(p.productCode!,
                      style: const TextStyle(fontSize: 12)),
                Row(children: [
                  Text(
                    'KES ${(p.sellingPrice ?? p.basePrice).toStringAsFixed(0)}',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600),
                  ),
                  if (p.outletName != null) ...[
                    const Text(' • ',
                        style: TextStyle(color: Colors.grey)),
                    Text(p.outletName!,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey)),
                  ],
                ]),
                if (isOut)
                  const Text('Out of Stock',
                      style: TextStyle(color: Colors.red, fontSize: 12))
                else if (isLow)
                  Text('Low Stock ($stock left)',
                      style: const TextStyle(
                          color: Colors.orange, fontSize: 12)),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') onEdit(p);
                if (v == 'delete') onDelete(p);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete',
                        style: TextStyle(color: Colors.red))),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Catalog Tab — with real thumbnail ────────────────────────────────────
class _CatalogTab extends StatelessWidget {
  final List<Product> products;
  final void Function(Product) onDelete;
  final void Function(Product) onEdit;
  const _CatalogTab(
      {required this.products, required this.onDelete, required this.onEdit});

  /// Parse product_images the same way ProductCardWidget does
  String? _imageUrl(Product p) {
    final raw = p.productImages;
    if (raw == null || raw.toString().isEmpty) return null;
    try {
      if (raw is String) {
        if (raw.startsWith('http')) return raw;
        final parsed = jsonDecode(raw);
        if (parsed is List && parsed.isNotEmpty) return parsed.first.toString();
      } else if (raw is List && raw.isNotEmpty) {
        return raw.first.toString();
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const AppEmpty(
        icon: Icons.shopping_bag_outlined,
        message: 'No products in catalog.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
      itemCount: products.length,
      itemBuilder: (_, i) {
        final p = products[i];
        final url = _imageUrl(p);
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 56,
                height: 56,
                child: url != null
                    ? Image.network(
                        url,
                        fit: BoxFit.cover,
                        // Lightweight fade-in while loading
                        loadingBuilder: (_, child, progress) =>
                            progress == null
                                ? child
                                : Container(
                                    color: Colors.grey[100],
                                    child: Center(
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          value: progress.expectedTotalBytes !=
                                                  null
                                              ? progress
                                                      .cumulativeBytesLoaded /
                                                  progress.expectedTotalBytes!
                                              : null,
                                          color: const Color(0xFF10B981),
                                        ),
                                      ),
                                    ),
                                  ),
                        errorBuilder: (_, __, ___) =>
                            _placeholder(p.isActive),
                      )
                    : _placeholder(p.isActive),
              ),
            ),
            title: Text(p.productName,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('KES ${p.basePrice.toStringAsFixed(0)}',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600)),
                if (p.categoryName != null)
                  Text(p.categoryName!,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey)),
              ],
            ),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              if (!p.isActive)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('Inactive',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey)),
                ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') onEdit(p);
                  if (v == 'delete') onDelete(p);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete',
                          style: TextStyle(color: Colors.red))),
                ],
              ),
            ]),
          ),
        );
      },
    );
  }

  Widget _placeholder(bool isActive) => Container(
        color: const Color(0xFFF0F4F0),
        child: Center(
          child: Icon(Icons.inventory_2_outlined,
              size: 26,
              color: isActive ? Colors.grey[400] : Colors.grey[300]),
        ),
      );
}
