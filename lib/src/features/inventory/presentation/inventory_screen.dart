// lib/src/features/inventory/presentation/inventory_screen.dart

import 'package:flutter/material.dart';
import '../data/inventory_api.dart';
import '../data/inventory_item.dart';
import '../../../core/widgets/shared_widgets.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<InventoryItem> _items = [];
  bool _loading = true;
  String? _error;
  String _search = '';
  String _filter = 'all'; // all | low | out

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // InventoryApi.list() returns Map<String, dynamic> with a 'data' key
      final response = await InventoryApi.list();
      final rawList = response['data'] as List<dynamic>? ?? [];
      final items = rawList
          .map((e) => InventoryItem.fromJson(e as Map<String, dynamic>))
          .toList();
      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  List<InventoryItem> get _filtered {
    var list = _items;
    if (_filter == 'low') list = list.where((i) => i.isLowStock).toList();
    if (_filter == 'out') list = list.where((i) => i.isOutOfStock).toList();
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list
          .where((i) =>
              i.productName.toLowerCase().contains(q) ||
              (i.sku?.toLowerCase().contains(q) ?? false) ||
              (i.outletName?.toLowerCase().contains(q) ?? false))
          .toList();
    }
    return list;
  }

  int get _lowCount => _items.where((i) => i.isLowStock).length;
  int get _outCount => _items.where((i) => i.isOutOfStock).length;

  Future<void> _showAdjustDialog(InventoryItem item) async {
    final ctrl = TextEditingController();
    String reason = 'manual';
    bool adding = true;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Adjust Stock: ${item.productName}',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                'Current: ${item.currentStock} units',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ChoiceChip(
                    label: const Text('Add Stock'),
                    selected: adding,
                    onSelected: (_) => setSt(() => adding = true),
                    selectedColor: Colors.teal.shade100,
                  ),
                  const SizedBox(width: 12),
                  ChoiceChip(
                    label: const Text('Remove Stock'),
                    selected: !adding,
                    onSelected: (_) => setSt(() => adding = false),
                    selectedColor: Colors.red.shade100,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Quantity',
                  prefixText: adding ? '+' : '-',
                  hintText: '0',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: reason,
                decoration: const InputDecoration(labelText: 'Reason'),
                items: const [
                  DropdownMenuItem(
                      value: 'manual', child: Text('Manual Adjustment')),
                  DropdownMenuItem(value: 'restock', child: Text('Restock')),
                  DropdownMenuItem(value: 'damage', child: Text('Damaged')),
                  DropdownMenuItem(
                      value: 'return', child: Text('Customer Return')),
                  DropdownMenuItem(value: 'audit', child: Text('Stock Audit')),
                ],
                onChanged: (v) => setSt(() => reason = v ?? 'manual'),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final qty = int.tryParse(ctrl.text);
                    if (qty == null || qty <= 0) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Enter a valid quantity')),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    await _applyAdjust(item, adding ? qty : -qty, reason);
                  },
                  child: const Text('Apply Adjustment'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _applyAdjust(
      InventoryItem item, int delta, String reason) async {
    try {
      // InventoryApi.adjust() is the correct method name
      await InventoryApi.adjust(
        item.inventoryId,
        delta,
        reason: reason,
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Stock adjusted: ${delta > 0 ? '+' : ''}$delta'),
            backgroundColor: delta > 0 ? Colors.teal : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showMovements(InventoryItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        expand: false,
        builder: (_, sc) => _MovementsSheet(item: item, scrollController: sc),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Inventory'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Export CSV',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Export started...')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: cs.surfaceContainerLowest,
            child: Row(
              children: [
                _SumCard(
                  label: 'Total Items',
                  value: _items.length.toString(),
                  color: cs.primary,
                ),
                const SizedBox(width: 8),
                _SumCard(
                  label: 'Low Stock',
                  value: _lowCount.toString(),
                  color: Colors.orange,
                ),
                const SizedBox(width: 8),
                _SumCard(
                  label: 'Out of Stock',
                  value: _outCount.toString(),
                  color: Colors.red,
                ),
              ],
            ),
          ),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _FilterChip(
                    'All', 'all', _filter, (v) => setState(() => _filter = v)),
                const SizedBox(width: 8),
                _FilterChip('Low Stock ($_lowCount)', 'low', _filter,
                    (v) => setState(() => _filter = v)),
                const SizedBox(width: 8),
                _FilterChip('Out of Stock ($_outCount)', 'out', _filter,
                    (v) => setState(() => _filter = v)),
              ],
            ),
          ),

          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: const InputDecoration(
                hintText: 'Search by name, SKU, outlet...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
            ),
          ),

          // List
          Expanded(
            child: _loading
                ? const AppLoading()
                : _error != null
                    ? AppError(message: _error!, onRetry: _load)
                    : _filtered.isEmpty
                        ? const AppEmpty(
                            icon: Icons.inventory_2_outlined,
                            message: 'No inventory items match your filters.',
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                            itemCount: _filtered.length,
                            itemBuilder: (_, i) => _InventoryCard(
                              item: _filtered[i],
                              onAdjust: _showAdjustDialog,
                              onHistory: _showMovements,
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SumCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SumCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: color),
            ),
            Text(
              label,
              style:
                  TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8)),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final void Function(String) onTap;
  const _FilterChip(this.label, this.value, this.selected, this.onTap);

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    final cs = Theme.of(context).colorScheme;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(value),
      selectedColor: cs.primary.withValues(alpha: 0.2),
      checkmarkColor: cs.primary,
    );
  }
}

class _InventoryCard extends StatelessWidget {
  final InventoryItem item;
  final void Function(InventoryItem) onAdjust;
  final void Function(InventoryItem) onHistory;
  const _InventoryCard({
    required this.item,
    required this.onAdjust,
    required this.onHistory,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final stockColor = item.isOutOfStock
        ? Colors.red
        : item.isLowStock
            ? Colors.orange
            : Colors.teal;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product name + stock badge
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      if (item.sku != null)
                        Text(
                          item.sku!,
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: stockColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: stockColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '${item.currentStock} units',
                    style: TextStyle(
                      color: stockColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Outlet + category
            Row(
              children: [
                if (item.outletName != null) ...[
                  Icon(Icons.store_outlined,
                      size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    item.outletName!,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(width: 16),
                ],
                if (item.categoryName != null) ...[
                  Icon(Icons.category_outlined,
                      size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    item.categoryName!,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 8),

            // Price + action buttons
            Row(
              children: [
                Text(
                  'KES ${item.sellingPrice.toStringAsFixed(0)}',
                  style:
                      TextStyle(color: cs.primary, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => onHistory(item),
                  icon: const Icon(Icons.history, size: 16),
                  label: const Text('History'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => onAdjust(item),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Adjust'),
                  style: ElevatedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),

            // Low/out-of-stock warning banner
            if (item.isLowStock || item.isOutOfStock)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber,
                        size: 14, color: Colors.orange),
                    const SizedBox(width: 6),
                    Text(
                      item.isOutOfStock
                          ? 'Out of stock — restock needed'
                          : 'Low stock — reorder point: ${item.reorderPoint ?? item.minimumStockLevel}',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _MovementsSheet extends StatefulWidget {
  final InventoryItem item;
  final ScrollController scrollController;
  const _MovementsSheet({
    required this.item,
    required this.scrollController,
  });

  @override
  State<_MovementsSheet> createState() => _MovementsSheetState();
}

class _MovementsSheetState extends State<_MovementsSheet> {
  List<dynamic> _movements = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // InventoryApi.movements() returns Map<String, dynamic> with a 'data' key
      final response = await InventoryApi.movements(widget.item.inventoryId);
      final rawList = response['data'] as List<dynamic>? ?? [];
      if (mounted) {
        setState(() {
          _movements = rawList;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Stock History',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      widget.item.productName,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _loading
              ? const AppLoading()
              : _movements.isEmpty
                  ? const AppEmpty(
                      icon: Icons.history,
                      message: 'No movement history yet.',
                    )
                  : ListView.separated(
                      controller: widget.scrollController,
                      itemCount: _movements.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final m = _movements[i] as Map<String, dynamic>;
                        // API returns 'quantity_change', positive = in, negative = out
                        final delta = _parseInt(m['quantity_change']);
                        final isIn = delta > 0;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isIn
                                ? Colors.green.shade50
                                : Colors.red.shade50,
                            child: Icon(
                              isIn ? Icons.add : Icons.remove,
                              color: isIn ? Colors.green : Colors.red,
                            ),
                          ),
                          title: Text(
                              '${isIn ? '+' : ''}$delta units  •  ${m['movement_type'] ?? ''}'),
                          subtitle: Text(m['reason']?.toString() ?? 'manual'),
                          trailing: Text(
                            m['created_at']?.toString().substring(0, 10) ?? '—',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  static int _parseInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }
}
