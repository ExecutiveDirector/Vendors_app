// inventory_card.dart
// Displays a single inventory item card.
// Uses VendorInventory convenience getters (isLowStock, isOutOfStock,
// isExpiringSoon) so logic lives only in the model.

import 'package:flutter/material.dart';
import 'inventory_models.dart';

class InventoryCard extends StatelessWidget {
  final VendorInventory item;
  final VoidCallback? onUpdateStock;
  final VoidCallback? onDetails;

  const InventoryCard({
    super.key,
    required this.item,
    this.onUpdateStock,
    this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    final (statusColor, statusText) = _statusInfo();

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(statusColor, statusText),
            const SizedBox(height: 12),
            _buildStockInfo(),
            if (item.isExpiringSoon) _buildExpiryWarning(),
            const SizedBox(height: 12),
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  (Color, String) _statusInfo() {
    if (item.isOutOfStock) return (Colors.red, 'Out of Stock');
    if (item.isLowStock) return (Colors.orange, 'Low Stock');
    return (Colors.green, 'In Stock');
  }

  // ── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader(Color statusColor, String statusText) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildImage(),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.productName,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'SKU: ${item.sku}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              if (item.outletId != 0) ...[
                const SizedBox(height: 2),
                Text(
                  'Outlet ID: ${item.outletId}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ],
          ),
        ),
        _buildStatusBadge(statusColor, statusText),
      ],
    );
  }

  Widget _buildImage() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: item.imageUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                item.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Icon(Icons.inventory_2, color: Colors.grey[400]),
              ),
            )
          : Icon(Icons.inventory_2, color: Colors.grey[400]),
    );
  }

  Widget _buildStatusBadge(Color color, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w500,
          fontSize: 11,
        ),
      ),
    );
  }

  // ── Stock info ───────────────────────────────────────────────────────────

  Widget _buildStockInfo() {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        _chip('Stock: ${item.currentStock}', Colors.blue),
        if (item.reservedStock > 0)
          _chip('Reserved: ${item.reservedStock}', Colors.orange),
        _chip(
          'Min: ${item.minimumStockLevel}',
          item.isLowStock ? Colors.red : Colors.grey,
        ),
        _chip('\$${item.sellingPrice.toStringAsFixed(2)}', Colors.green),
      ],
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500),
      ),
    );
  }

  // ── Expiry warning ───────────────────────────────────────────────────────

  Widget _buildExpiryWarning() {
    final dateStr = item.expiryDate?.toIso8601String().split('T').first ?? '';
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning, size: 14, color: Colors.amber),
          const SizedBox(width: 4),
          Text(
            'Expires: $dateStr',
            style: const TextStyle(
              color: Colors.amber,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  Widget _buildActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onUpdateStock,
            icon: const Icon(Icons.edit, size: 16),
            label: const Text('Update Stock'),
            style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onDetails,
            icon: const Icon(Icons.info_outline, size: 16),
            label: const Text('Details'),
            style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8)),
          ),
        ),
      ],
    );
  }
}
