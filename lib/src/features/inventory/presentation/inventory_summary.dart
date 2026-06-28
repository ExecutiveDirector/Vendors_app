// inventory_summary.dart
// Compact stats bar — total, low stock, out of stock, expiring soon.
// Shown at the top of the "All" tab list.

import 'package:flutter/material.dart';
import 'inventory_models.dart';

class InventorySummary extends StatelessWidget {
  final List<VendorInventory> items;

  const InventorySummary({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final total = items.length;
    final lowStock = items.where((e) => e.isLowStock).length;
    final outOfStock = items.where((e) => e.isOutOfStock).length;
    final expiring = items.where((e) => e.isExpiringSoon).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _tile(context,
                  label: 'Total',
                  value: total,
                  icon: Icons.inventory_2_outlined,
                  color: Colors.blue),
              _divider(),
              _tile(context,
                  label: 'Low Stock',
                  value: lowStock,
                  icon: Icons.warning_amber_rounded,
                  color: Colors.orange),
              _divider(),
              _tile(context,
                  label: 'Out of Stock',
                  value: outOfStock,
                  icon: Icons.remove_shopping_cart_outlined,
                  color: Colors.red),
              _divider(),
              _tile(context,
                  label: 'Expiring',
                  value: expiring,
                  icon: Icons.timer_outlined,
                  color: Colors.amber[700]!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider() => Container(
        height: 40,
        width: 1,
        color: Colors.grey[200],
      );

  Widget _tile(
    BuildContext context, {
    required String label,
    required int value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
