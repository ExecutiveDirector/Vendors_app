import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/dio_client.dart';

class VendorOutletsScreen extends StatefulWidget {
  const VendorOutletsScreen({super.key});

  @override
  State<VendorOutletsScreen> createState() => _VendorOutletsScreenState();
}

class _VendorOutletsScreenState extends State<VendorOutletsScreen> {
  bool loading = true;
  bool refreshing = false;
  List<dynamic> outlets = [];
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadOutlets();
  }

  Future<void> _loadOutlets() async {
    try {
      setState(() => loading = true);
      final res = await ApiClient.dio.get('/vendors/outlets');
      if (mounted) {
        setState(() {
          outlets = res.data ?? [];
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        _showError('Failed to load outlets: ${e.toString()}');
      }
    }
  }

  Future<void> _refreshOutlets() async {
    if (refreshing) return;
    setState(() => refreshing = true);
    await _loadOutlets();
    setState(() => refreshing = false);
  }

  Future<void> _deleteOutlet(int outletId, String outletName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Outlet'),
        content: Text('Are you sure you want to delete "$outletName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ApiClient.dio.delete('/vendors/outlets/$outletId');
      _showSuccess('Outlet deleted successfully');
      _loadOutlets();
    } catch (e) {
      _showError('Failed to delete outlet: ${e.toString()}');
    }
  }

  List<dynamic> get filteredOutlets {
    if (searchQuery.isEmpty) return outlets;
    return outlets.where((outlet) {
      final name = (outlet['outlet_name'] ?? '').toString().toLowerCase();
      final code = (outlet['outlet_code'] ?? '').toString().toLowerCase();
      final city = (outlet['city'] ?? '').toString().toLowerCase();
      final query = searchQuery.toLowerCase();
      return name.contains(query) ||
          code.contains(query) ||
          city.contains(query);
    }).toList();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFFE53E3E),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('My Outlets'),
        backgroundColor: const Color(0xFFFF8A00),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _refreshOutlets,
            icon: refreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Color(0xFFFF8A00)),
              ),
            )
          : Column(
              children: [
                _buildSearchBar(),
                Expanded(
                  child: filteredOutlets.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _refreshOutlets,
                          color: const Color(0xFFFF8A00),
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredOutlets.length,
                            itemBuilder: (context, index) {
                              return _buildOutletCard(filteredOutlets[index]);
                            },
                          ),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            context.push('/outlets/add').then((_) => _loadOutlets()),
        backgroundColor: const Color(0xFFFF8A00),
        icon: const Icon(Icons.add),
        label: const Text('Add Outlet'),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: TextField(
        onChanged: (value) => setState(() => searchQuery = value),
        decoration: InputDecoration(
          hintText: 'Search outlets...',
          prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Color(0xFF64748B)),
                  onPressed: () => setState(() => searchQuery = ''),
                )
              : null,
          filled: true,
          fillColor: const Color(0xFFF1F5F9),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildOutletCard(Map<String, dynamic> outlet) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context
              .push('/outlets/${outlet['outlet_id']}')
              .then((_) => _loadOutlets()),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF8A00).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.storefront,
                        color: Color(0xFFFF8A00),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            outlet['outlet_name'] ?? 'Unnamed Outlet',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            outlet['outlet_code'] ?? '',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton(
                      icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          child: const Row(
                            children: [
                              Icon(Icons.edit,
                                  size: 20, color: Color(0xFF3B82F6)),
                              SizedBox(width: 12),
                              Text('Edit'),
                            ],
                          ),
                          onTap: () => Future.delayed(
                            Duration.zero,
                            () => context
                                .push('/outlets/${outlet['outlet_id']}/edit')
                                .then((_) => _loadOutlets()),
                          ),
                        ),
                        PopupMenuItem(
                          child: const Row(
                            children: [
                              Icon(Icons.delete,
                                  size: 20, color: Color(0xFFEF4444)),
                              SizedBox(width: 12),
                              Text('Delete'),
                            ],
                          ),
                          onTap: () => Future.delayed(
                            Duration.zero,
                            () => _deleteOutlet(
                              outlet['outlet_id'],
                              outlet['outlet_name'] ?? '',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildInfoRow(
                  Icons.location_on_outlined,
                  '${outlet['address_line_1']}, ${outlet['city']}',
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.map_outlined,
                  '${outlet['county']} County',
                ),
                if (outlet['contact_phone'] != null) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    Icons.phone_outlined,
                    outlet['contact_phone'],
                  ),
                ],
                if (outlet['manager_name'] != null) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    Icons.person_outline,
                    'Manager: ${outlet['manager_name']}',
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(60),
            ),
            child: Icon(
              Icons.storefront_outlined,
              size: 60,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            searchQuery.isEmpty ? 'No Outlets Yet' : 'No Results Found',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            searchQuery.isEmpty
                ? 'Add your first outlet to start managing inventory'
                : 'Try a different search term',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          if (searchQuery.isEmpty)
            ElevatedButton.icon(
              onPressed: () =>
                  context.push('/outlets/add').then((_) => _loadOutlets()),
              icon: const Icon(Icons.add),
              label: const Text('Add Outlet'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8A00),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
