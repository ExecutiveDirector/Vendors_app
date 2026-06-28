// inventory_dialogs.dart
// All modal dialogs for the inventory screen.
// Each dialog is a standalone async function — easy to call from InventoryScreen.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'inventory_models.dart';

// ── Stock Update Dialog ───────────────────────────────────────────────────────

/// Shows a dialog to set a new absolute stock level for [item].
/// Calls [onUpdated] with the new value on confirm.
Future<void> showStockUpdateDialog(
  BuildContext context,
  VendorInventory item, {
  required void Function(int newStock) onUpdated,
}) async {
  final ctrl = TextEditingController(text: item.currentStock.toString());
  final formKey = GlobalKey<FormState>();

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Update Stock — ${item.productName}',
          style: const TextStyle(fontSize: 16)),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current stock: ${item.currentStock}',
                style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const SizedBox(height: 12),
            TextFormField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'New stock level',
                border: OutlineInputBorder(),
                suffixText: 'units',
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter a value';
                final n = int.tryParse(v);
                if (n == null || n < 0) return 'Must be 0 or more';
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              Navigator.pop(ctx);
              onUpdated(int.parse(ctrl.text));
            }
          },
          child: const Text('Update'),
        ),
      ],
    ),
  );
}

// ── Product Details Dialog ────────────────────────────────────────────────────

Future<void> showProductDetailsDialog(
    BuildContext context, VendorInventory item) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(item.productName),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                item.imageUrl!,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          const SizedBox(height: 12),
          _detailRow('SKU', item.sku),
          _detailRow('Category', item.categoryName),
          _detailRow('Current Stock', '${item.currentStock} units'),
          _detailRow('Reserved', '${item.reservedStock} units'),
          _detailRow('Minimum Level', '${item.minimumStockLevel} units'),
          _detailRow('Price', '\$${item.sellingPrice.toStringAsFixed(2)}'),
          _detailRow('Outlet ID', '${item.outletId}'),
          if (item.expiryDate != null)
            _detailRow(
              'Expiry',
              item.expiryDate!.toIso8601String().split('T').first,
              valueColor: item.isExpiringSoon ? Colors.red : null,
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

Widget _detailRow(String label, String value, {Color? valueColor}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.black54, fontWeight: FontWeight.w500)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: valueColor ?? Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

// ── Add Product Dialog ────────────────────────────────────────────────────────

/// Simple add-product form. Calls [onAdded] with the payload on submit.
Future<void> showAddProductDialog(
  BuildContext context, {
  required List<ProductCategory> categories,
  required List<VendorOutlet> outlets,
  required void Function(Map<String, dynamic> payload) onAdded,
}) async {
  final formKey = GlobalKey<FormState>();
  final nameCtrl = TextEditingController();
  final codeCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final stockCtrl = TextEditingController(text: '0');
  int? selectedCategoryId;
  int? selectedOutletId = outlets.isNotEmpty ? outlets.first.outletId : null;

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Add Product'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(nameCtrl, 'Product Name', required: true),
                const SizedBox(height: 10),
                _field(codeCtrl, 'Product Code / SKU', required: true),
                const SizedBox(height: 10),
                _field(priceCtrl, 'Base Price',
                    keyboard: TextInputType.number, required: true),
                const SizedBox(height: 10),
                _field(stockCtrl, 'Initial Stock',
                    keyboard: TextInputType.number),
                const SizedBox(height: 10),
                // Category dropdown
                DropdownButtonFormField<int>(
                  value: selectedCategoryId,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: categories
                      .map((c) => DropdownMenuItem(
                            value: c.categoryId,
                            child: Text(c.categoryName),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => selectedCategoryId = v),
                  validator: (v) => v == null ? 'Select a category' : null,
                ),
                const SizedBox(height: 10),
                // Outlet dropdown
                if (outlets.isNotEmpty)
                  DropdownButtonFormField<int>(
                    value: selectedOutletId,
                    decoration: const InputDecoration(
                      labelText: 'Outlet',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: outlets
                        .map((o) => DropdownMenuItem(
                              value: o.outletId,
                              child: Text(o.outletName),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => selectedOutletId = v),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx);
                onAdded({
                  'product_name': nameCtrl.text.trim(),
                  'product_code': codeCtrl.text.trim(),
                  'base_price': double.tryParse(priceCtrl.text) ?? 0.0,
                  'stock_quantity': int.tryParse(stockCtrl.text) ?? 0,
                  'category_id': selectedCategoryId,
                  'outlet_id': selectedOutletId,
                });
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    ),
  );
}

// ── Filter Dialog ─────────────────────────────────────────────────────────────

Future<void> showFilterDialog(
  BuildContext context, {
  required List<VendorOutlet> outlets,
  required List<ProductCategory> categories,
  int? selectedOutletId,
  String? selectedCategory,
  required String sortBy,
  required bool sortDescending,
  required void Function(
    int? outletId,
    String? category,
    String sortBy,
    bool descending,
  ) onApply,
}) async {
  int? outlet = selectedOutletId;
  String? category = selectedCategory;
  String sort = sortBy;
  bool desc = sortDescending;

  await showDialog<void>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Filter & Sort'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: 'Outlet'),
                value: outlet,
                items: [
                  const DropdownMenuItem<int>(
                      value: null, child: Text('All Outlets')),
                  ...outlets.map((o) => DropdownMenuItem<int>(
                        value: o.outletId,
                        child: Text(o.outletName),
                      )),
                ],
                onChanged: (v) => setState(() => outlet = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Category'),
                value: category,
                items: [
                  const DropdownMenuItem<String>(
                      value: null, child: Text('All Categories')),
                  ...categories.map((c) => DropdownMenuItem<String>(
                        value: c.categoryName,
                        child: Text(c.categoryName),
                      )),
                ],
                onChanged: (v) => setState(() => category = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Sort By'),
                value: sort,
                items: const [
                  DropdownMenuItem(value: 'product_name', child: Text('Name')),
                  DropdownMenuItem(
                      value: 'current_stock', child: Text('Stock')),
                  DropdownMenuItem(value: 'price', child: Text('Price')),
                  DropdownMenuItem(
                      value: 'expiry_date', child: Text('Expiry Date')),
                ],
                onChanged: (v) => setState(() => sort = v ?? 'product_name'),
              ),
              SwitchListTile(
                title: const Text('Descending'),
                value: desc,
                onChanged: (v) => setState(() => desc = v),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onApply(outlet, category, sort, desc);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    ),
  );
}

// ── Bulk Update Dialog ────────────────────────────────────────────────────────

Future<void> showBulkUpdateDialog(
  BuildContext context, {
  required VoidCallback onBulkUpdated,
}) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Bulk Update Inventory'),
      content:
          const Text('Bulk editing is coming soon. You can use the individual '
              '"Update Stock" button on each item for now.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

// ── Selector Dialogs ──────────────────────────────────────────────────────────

Future<void> showOutletSelectorDialog(
  BuildContext context, {
  required List<VendorOutlet> outlets,
  int? selectedId,
  required void Function(int?) onSelected,
}) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('Select Outlet'),
      children: [
        RadioListTile<int?>(
          title: const Text('All Outlets'),
          value: null,
          groupValue: selectedId,
          onChanged: (v) {
            Navigator.pop(ctx);
            onSelected(v);
          },
        ),
        ...outlets.map(
          (o) => RadioListTile<int>(
            title: Text(o.outletName),
            subtitle:
                Text(o.addressLine1, style: const TextStyle(fontSize: 12)),
            value: o.outletId,
            groupValue: selectedId,
            onChanged: (v) {
              Navigator.pop(ctx);
              onSelected(v);
            },
          ),
        ),
      ],
    ),
  );
}

Future<void> showCategorySelectorDialog(
  BuildContext context, {
  required List<ProductCategory> categories,
  String? selected,
  required void Function(String?) onSelected,
}) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('Select Category'),
      children: [
        RadioListTile<String?>(
          title: const Text('All Categories'),
          value: null,
          groupValue: selected,
          onChanged: (v) {
            Navigator.pop(ctx);
            onSelected(v);
          },
        ),
        ...categories.map(
          (c) => RadioListTile<String>(
            title: Text(c.categoryName),
            value: c.categoryName,
            groupValue: selected,
            onChanged: (v) {
              Navigator.pop(ctx);
              onSelected(v);
            },
          ),
        ),
      ],
    ),
  );
}

Future<void> showSortDialog(
  BuildContext context, {
  required String currentSortBy,
  required bool currentDescending,
  required void Function(String sortBy, bool descending) onSelected,
}) async {
  String sortBy = currentSortBy;
  bool desc = currentDescending;

  await showDialog<void>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Sort Options'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: sortBy,
              decoration: const InputDecoration(labelText: 'Sort By'),
              items: const [
                DropdownMenuItem(value: 'product_name', child: Text('Name')),
                DropdownMenuItem(value: 'current_stock', child: Text('Stock')),
                DropdownMenuItem(value: 'price', child: Text('Price')),
                DropdownMenuItem(
                    value: 'expiry_date', child: Text('Expiry Date')),
              ],
              onChanged: (v) => setState(() => sortBy = v ?? currentSortBy),
            ),
            SwitchListTile(
              title: const Text('Descending'),
              value: desc,
              onChanged: (v) => setState(() => desc = v),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onSelected(sortBy, desc);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    ),
  );
}

// ── Shared helpers ────────────────────────────────────────────────────────────

Widget _field(
  TextEditingController ctrl,
  String label, {
  bool required = false,
  TextInputType keyboard = TextInputType.text,
}) {
  return TextFormField(
    controller: ctrl,
    keyboardType: keyboard,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      isDense: true,
    ),
    validator: required
        ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
        : null,
  );
}
