// inventory_header.dart
// Search bar + filter chips. The search bar calls onSearchChanged on every
// keystroke so the parent can call setState and rebuild filtered lists.

import 'package:flutter/material.dart';
import 'inventory_models.dart';

class InventoryHeader extends StatelessWidget {
  final TextEditingController searchController;
  final List<VendorOutlet> outlets;
  final List<ProductCategory> categories;
  final int? selectedOutletId;
  final String? selectedCategory;
  final String sortDisplayName;

  // Callbacks
  final VoidCallback onClearSearch;
  final VoidCallback onOpenOutletSelector;
  final VoidCallback onOpenCategorySelector;
  final VoidCallback onOpenSortDialog;

  /// Called on every keystroke so parent can rebuild filtered items.
  final VoidCallback onSearchChanged;

  const InventoryHeader({
    super.key,
    required this.searchController,
    required this.outlets,
    required this.categories,
    required this.selectedOutletId,
    required this.selectedCategory,
    required this.sortDisplayName,
    required this.onClearSearch,
    required this.onOpenOutletSelector,
    required this.onOpenCategorySelector,
    required this.onOpenSortDialog,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchBar(context),
          const SizedBox(height: 8),
          _buildFilterChips(context),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: searchController,
      builder: (_, value, __) => TextField(
        controller: searchController,
        onChanged: (_) => onSearchChanged(),
        decoration: InputDecoration(
          hintText: 'Search products, SKU, category…',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: value.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    searchController.clear();
                    onClearSearch();
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[200]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).primaryColor,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    final outletLabel = selectedOutletId != null
        ? outlets
                .where((o) => o.outletId == selectedOutletId)
                .map((o) => o.outletName)
                .firstOrNull ??
            'Outlet'
        : 'Outlet';

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip(
            icon: Icons.storefront_outlined,
            label: outletLabel,
            active: selectedOutletId != null,
            onTap: onOpenOutletSelector,
            context: context,
          ),
          const SizedBox(width: 8),
          _chip(
            icon: Icons.category_outlined,
            label: selectedCategory ?? 'Category',
            active: selectedCategory != null,
            onTap: onOpenCategorySelector,
            context: context,
          ),
          const SizedBox(width: 8),
          _chip(
            icon: Icons.sort,
            label: sortDisplayName,
            active: sortDisplayName != 'Name',
            onTap: onOpenSortDialog,
            context: context,
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
    required BuildContext context,
  }) {
    final color = active ? Theme.of(context).primaryColor : Colors.grey[600]!;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? Theme.of(context).primaryColor.withOpacity(0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? Theme.of(context).primaryColor.withOpacity(0.4)
                : Colors.grey[300]!,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down, size: 16, color: color),
          ],
        ),
      ),
    );
  }
}
