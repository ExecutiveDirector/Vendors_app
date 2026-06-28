// inventory_list.dart
// Pull-to-refresh list of InventoryCard widgets with empty state.

import 'package:flutter/material.dart';
import 'inventory_models.dart';
import 'inventory_card.dart';

class InventoryList extends StatelessWidget {
  final List<VendorInventory> items;
  final Future<void> Function()? onRefresh;
  final void Function(VendorInventory)? onUpdateStock;
  final void Function(VendorInventory)? onShowDetails;

  /// Optional: shown above the list (e.g. summary bar).
  final Widget? header;

  const InventoryList({
    super.key,
    required this.items,
    this.onRefresh,
    this.onUpdateStock,
    this.onShowDetails,
    this.header,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh ?? () async {},
      color: Theme.of(context).primaryColor,
      child: items.isEmpty ? _buildEmpty() : _buildList(context),
    );
  }

  Widget _buildEmpty() {
    return ListView(
      // Must be scrollable for RefreshIndicator to work on empty state.
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: 300,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inventory_2_outlined,
                  size: 72, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No items found',
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                'Try adjusting filters or pull down to refresh',
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildList(BuildContext context) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (header != null) SliverToBoxAdapter(child: header!),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, index) {
                final item = items[index];
                return InventoryCard(
                  key: ValueKey(item.inventoryId),
                  item: item,
                  onUpdateStock: () => onUpdateStock?.call(item),
                  onDetails: () => onShowDetails?.call(item),
                );
              },
              childCount: items.length,
            ),
          ),
        ),
      ],
    );
  }
}
