import 'package:flutter/material.dart';

/// Filter dialog widget for selecting outlet, category, and sorting option.
/// Returns selected values when closed.
class InventoryFilters extends StatefulWidget {
  final List<String> outlets;
  final List<String> categories;
  final String? selectedOutlet;
  final String? selectedCategory;
  final String? selectedSort;
  final void Function({
    String? outlet,
    String? category,
    String? sort,
  })? onApply;

  const InventoryFilters({
    super.key,
    required this.outlets,
    required this.categories,
    this.selectedOutlet,
    this.selectedCategory,
    this.selectedSort,
    this.onApply,
  });

  @override
  State<InventoryFilters> createState() => _InventoryFiltersState();
}

class _InventoryFiltersState extends State<InventoryFilters> {
  String? _selectedOutlet;
  String? _selectedCategory;
  String? _selectedSort;

  final List<String> _sortOptions = const [
    'Name (A–Z)',
    'Name (Z–A)',
    'Stock (High → Low)',
    'Stock (Low → High)',
    'Expiring Soon',
  ];

  @override
  void initState() {
    super.initState();
    _selectedOutlet = widget.selectedOutlet;
    _selectedCategory = widget.selectedCategory;
    _selectedSort = widget.selectedSort;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filter Inventory'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDropdown(
              label: 'Outlet',
              items: widget.outlets,
              value: _selectedOutlet,
              onChanged: (val) => setState(() => _selectedOutlet = val),
            ),
            const SizedBox(height: 12),
            _buildDropdown(
              label: 'Category',
              items: widget.categories,
              value: _selectedCategory,
              onChanged: (val) => setState(() => _selectedCategory = val),
            ),
            const SizedBox(height: 12),
            _buildDropdown(
              label: 'Sort by',
              items: _sortOptions,
              value: _selectedSort,
              onChanged: (val) => setState(() => _selectedSort = val),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onApply?.call(
              outlet: _selectedOutlet,
              category: _selectedCategory,
              sort: _selectedSort,
            );
            Navigator.pop(context);
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }

  /// Builds a styled dropdown with consistent Material look.
  Widget _buildDropdown({
    required String label,
    required List<String> items,
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: value,
          items: [
            const DropdownMenuItem(value: null, child: Text('All')),
            ...items.map(
              (e) => DropdownMenuItem(value: e, child: Text(e)),
            ),
          ],
          onChanged: onChanged,
          decoration: InputDecoration(
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }
}
