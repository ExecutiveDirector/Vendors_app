import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/dio_client.dart';

class OutletDetailsScreen extends StatefulWidget {
  final int outletId;

  const OutletDetailsScreen({super.key, required this.outletId});

  @override
  State<OutletDetailsScreen> createState() => _OutletDetailsScreenState();
}

class _OutletDetailsScreenState extends State<OutletDetailsScreen>
    with SingleTickerProviderStateMixin {
  bool loading = true;
  Map<String, dynamic>? outlet;
  List<dynamic> inventory = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadOutletData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOutletData() async {
    try {
      setState(() => loading = true);
      final responses = await Future.wait([
        // ✅ FIX: /vendor/outlets/:id → /vendors/outlets/:id
        ApiClient.dio.get('/vendors/outlets/${widget.outletId}'),
        // ✅ FIX: /vendor/inventory → /vendors/inventory
        ApiClient.dio.get('/vendors/inventory',
            queryParameters: {'outlet_id': widget.outletId}),
      ]);

      if (mounted) {
        setState(() {
          outlet = responses[0].data;
          inventory = responses[1].data ?? [];
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        _showError('Failed to load outlet data');
      }
    }
  }

  Future<void> _updateStock(int inventoryId, int currentStock) async {
    final controller = TextEditingController(text: currentStock.toString());

    final newStock = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Update Stock'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'New Stock Quantity',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value != null && value >= 0) Navigator.pop(context, value);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF8A00),
              foregroundColor: Colors.white,
            ),
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (newStock == null) return;

    try {
      // ✅ FIX: /vendor/inventory/:id → /vendors/inventory/:id
      await ApiClient.dio.put('/vendors/inventory/$inventoryId',
          data: {'current_stock': newStock});
      _showSuccess('Stock updated successfully');
      _loadOutletData();
    } catch (e) {
      _showError('Failed to update stock');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: const Color(0xFFEF4444),
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: const Color(0xFF10B981),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(outlet?['outlet_name'] ?? 'Outlet Details'),
        backgroundColor: const Color(0xFFFF8A00),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => context
                .push('/outlets/${widget.outletId}/edit')
                .then((_) => _loadOutletData()),
            icon: const Icon(Icons.edit),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Details'),
            Tab(text: 'Inventory'),
          ],
        ),
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Color(0xFFFF8A00)),
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDetailsTab(),
                _buildInventoryTab(),
              ],
            ),
    );
  }

  Widget _buildDetailsTab() {
    if (outlet == null) return const SizedBox();

    return RefreshIndicator(
      onRefresh: _loadOutletData,
      color: const Color(0xFFFF8A00),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildInfoCard(
            title: 'Location',
            icon: Icons.location_on,
            children: [
              _buildInfoRow('Address', outlet!['address_line_1'] ?? ''),
              if (outlet!['address_line_2'] != null)
                _buildInfoRow('', outlet!['address_line_2']),
              _buildInfoRow('City', outlet!['city'] ?? ''),
              _buildInfoRow('County', outlet!['county'] ?? ''),
              if (outlet!['postal_code'] != null)
                _buildInfoRow('Postal Code', outlet!['postal_code']),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            title: 'Coordinates',
            icon: Icons.map,
            children: [
              _buildInfoRow('Latitude', outlet!['latitude']?.toString() ?? ''),
              _buildInfoRow(
                  'Longitude', outlet!['longitude']?.toString() ?? ''),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            title: 'Contact',
            icon: Icons.contact_phone,
            children: [
              if (outlet!['contact_phone'] != null)
                _buildInfoRow('Phone', outlet!['contact_phone']),
              if (outlet!['manager_name'] != null)
                _buildInfoRow('Manager', outlet!['manager_name']),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryTab() {
    return RefreshIndicator(
      onRefresh: _loadOutletData,
      color: const Color(0xFFFF8A00),
      child: inventory.isEmpty
          ? _buildEmptyInventory()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: inventory.length,
              itemBuilder: (context, index) =>
                  _buildInventoryCard(inventory[index]),
            ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: const Color(0xFFFF8A00), size: 24),
            const SizedBox(width: 12),
            Text(title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                )),
          ]),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label.isNotEmpty) ...[
            SizedBox(
              width: 100,
              child: Text(label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  )),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B))),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryCard(Map<String, dynamic> item) {
    final currentStock = item['current_stock'] ?? 0;
    final minStock = item['minimum_stock_level'] ?? 5;
    final isLowStock = currentStock < minStock;
    final isAvailable = item['is_available'] ?? true;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isLowStock
            ? Border.all(color: const Color(0xFFFFBF00), width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['product_name'] ?? 'Unknown Product',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item['product_code'] ?? '',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isAvailable
                      ? const Color(0xFF10B981).withOpacity(0.1)
                      : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isAvailable ? 'AVAILABLE' : 'UNAVAILABLE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isAvailable ? const Color(0xFF10B981) : Colors.grey,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: _buildStockInfo(
              'Current Stock',
              currentStock.toString(),
              isLowStock ? const Color(0xFFFFBF00) : const Color(0xFF10B981),
            )),
            Expanded(
                child: _buildStockInfo(
              'Min Level',
              minStock.toString(),
              Colors.grey,
            )),
            Expanded(
                child: _buildStockInfo(
              'Price',
              'KES ${item['selling_price']?.toStringAsFixed(2) ?? '0.00'}',
              const Color(0xFF3B82F6),
            )),
          ]),
          if (isLowStock) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4E6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                const Icon(Icons.warning_amber,
                    color: Color(0xFFFFBF00), size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Low stock alert! Consider restocking soon.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFFD97706),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () =>
                    _updateStock(item['inventory_id'], currentStock),
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Update Stock'),
                style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFFF8A00)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStockInfo(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildEmptyInventory() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Icon(Icons.inventory_2_outlined,
                size: 50, color: Colors.grey[400]),
          ),
          const SizedBox(height: 24),
          const Text('No Inventory Items',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              )),
          const SizedBox(height: 8),
          Text(
            'Add products to this outlet to see them here',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
