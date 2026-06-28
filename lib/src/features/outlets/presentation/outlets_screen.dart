import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/widgets/shared_widgets.dart';
import 'dart:convert';

class OutletsScreen extends StatefulWidget {
  const OutletsScreen({super.key});

  @override
  State<OutletsScreen> createState() => _OutletsScreenState();
}

class _OutletsScreenState extends State<OutletsScreen> {
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _error;
  List<VendorOutlet> _outlets = [];

  @override
  void initState() {
    super.initState();
    _loadOutlets();
  }

  Future<void> _loadOutlets() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await ApiClient.dio.get('/vendors/outlets');
      final data = response.data;
      final List list =
          data is List ? data : (data['outlets'] ?? data['data'] ?? []);

      setState(() {
        _outlets = list
            .map((o) => VendorOutlet.fromJson(o as Map<String, dynamic>))
            .toList();
      });
    } on DioException catch (e) {
      setState(() => _error = _formatDioError(e));
    } catch (e) {
      setState(() => _error = 'Unexpected error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createOutlet(VendorOutletCreate outlet) async {
    try {
      final response = await ApiClient.dio.post(
        '/vendors/outlets',
        data: outlet.toJson(),
      );

      if (response.statusCode == 201) {
        await _loadOutlets();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Outlet created successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${_formatDioError(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateOutlet(VendorOutlet outlet) async {
    try {
      final response = await ApiClient.dio.put(
        '/vendors/outlets/${outlet.outletId}',
        data: outlet.toJson(),
      );

      if (response.statusCode == 200) {
        await _loadOutlets();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Outlet updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${_formatDioError(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteOutlet(int outletId) async {
    try {
      await ApiClient.dio.delete('/vendors/outlets/$outletId');
      setState(() {
        _outlets.removeWhere((o) => o.outletId == outletId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Outlet deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${_formatDioError(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Connection timed out. Please check your internet connection.';
    } else if (e.response != null) {
      final data = e.response!.data;
      final message = data is Map ? data['error'] ?? data['message'] : null;
      return message ?? 'Failed with status ${e.response!.statusCode}';
    } else {
      return 'Network error: ${e.message ?? 'Unknown error'}';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && !_isRefreshing) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadOutlets,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Outlet Management'),
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOutlets,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _isRefreshing = true);
          await _loadOutlets();
          setState(() => _isRefreshing = false);
        },
        child: _buildOutletsList(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddOutletDialog,
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Add Outlet'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildOutletsList() {
    if (_outlets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.store_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No outlets found',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first outlet to get started',
              style: TextStyle(color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showAddOutletDialog,
              icon: const Icon(Icons.add_location_alt),
              label: const Text('Add Outlet'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _outlets.length,
      itemBuilder: (context, index) => _buildOutletCard(_outlets[index]),
    );
  }

  Widget _buildOutletCard(VendorOutlet outlet) {
    final operatingHours = outlet.operatingHours != null
        ? _parseOperatingHours(outlet.operatingHours!)
        : null;
    final isOpen =
        operatingHours != null ? _isOutletOpen(operatingHours) : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Icon(Icons.store, color: Colors.blue[600], size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              outlet.outletName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          if (isOpen != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isOpen ? Colors.green : Colors.red,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isOpen ? 'Open' : 'Closed',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Code: ${outlet.outletCode}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.location_on,
                              size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _formatAddress(outlet),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) => _handleOutletAction(value, outlet),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(Icons.edit, size: 18),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ]),
                    ),
                    const PopupMenuItem(
                      value: 'view_map',
                      child: Row(children: [
                        Icon(Icons.map, size: 18),
                        SizedBox(width: 8),
                        Text('View on Map'),
                      ]),
                    ),
                    const PopupMenuItem(
                      value: 'inventory',
                      child: Row(children: [
                        Icon(Icons.inventory, size: 18),
                        SizedBox(width: 8),
                        Text('View Inventory'),
                      ]),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ]),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (outlet.contactPhone != null) ...[
              Row(children: [
                Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(outlet.contactPhone!,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
              ]),
              const SizedBox(height: 8),
            ],
            if (outlet.managerName != null) ...[
              Row(children: [
                Icon(Icons.person, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text('Manager: ${outlet.managerName}',
                    style: const TextStyle(fontWeight: FontWeight.w500)),
              ]),
              const SizedBox(height: 8),
            ],
            if (operatingHours != null) ...[
              Row(children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  _getCurrentDayHours(operatingHours),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ]),
              const SizedBox(height: 12),
            ],
            if (outlet.facilities != null && outlet.facilities!.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _parseFacilities(outlet.facilities!)
                    .map((f) => _buildFacilityChip(f))
                    .toList(),
              ),
              const SizedBox(height: 12),
            ],
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showOutletDetails(outlet),
                  icon: const Icon(Icons.visibility, size: 18),
                  label: const Text('Details'),
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _editOutlet(outlet),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildFacilityChip(String facility) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Text(
        facility,
        style: TextStyle(
          color: Colors.blue[700],
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _formatAddress(VendorOutlet outlet) {
    return [
      outlet.addressLine1,
      if (outlet.addressLine2?.isNotEmpty == true) outlet.addressLine2!,
      outlet.city,
      outlet.county,
    ].join(', ');
  }

  Map<String, dynamic>? _parseOperatingHours(String operatingHours) {
    try {
      return jsonDecode(operatingHours) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  List<String> _parseFacilities(String facilities) {
    try {
      final parsed = jsonDecode(facilities);
      if (parsed is List) return parsed.cast<String>();
    } catch (_) {}
    return [];
  }

  bool _isOutletOpen(Map<String, dynamic> operatingHours) {
    final today = _getDayName(DateTime.now().weekday).toLowerCase();
    final todayHours = operatingHours[today];
    if (todayHours == null) return false;
    try {
      final open = _parseTimeString(todayHours['open']?.toString() ?? '');
      final close = _parseTimeString(todayHours['close']?.toString() ?? '');
      if (open == null || close == null) return false;
      final now = TimeOfDay.now();
      final cur = now.hour * 60 + now.minute;
      final o = open.hour * 60 + open.minute;
      final c = close.hour * 60 + close.minute;
      return c < o ? cur >= o || cur <= c : cur >= o && cur <= c;
    } catch (_) {
      return false;
    }
  }

  String _getCurrentDayHours(Map<String, dynamic> operatingHours) {
    final today = _getDayName(DateTime.now().weekday).toLowerCase();
    final h = operatingHours[today];
    if (h == null) return 'Closed today';
    return '${h['open']} - ${h['close']}';
  }

  String _getDayName(int weekday) {
    const days = [
      '',
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday'
    ];
    return days[weekday];
  }

  TimeOfDay? _parseTimeString(String t) {
    try {
      final parts = t.split(':');
      if (parts.length == 2) {
        return TimeOfDay(
            hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    } catch (_) {}
    return null;
  }

  void _handleOutletAction(String action, VendorOutlet outlet) {
    switch (action) {
      case 'edit':
        _editOutlet(outlet);
        break;
      case 'view_map':
        _viewOnMap(outlet);
        break;
      case 'inventory':
        _viewInventory(outlet);
        break;
      case 'delete':
        _showDeleteConfirmation(outlet);
        break;
    }
  }

  void _showAddOutletDialog() {
    showDialog(
      context: context,
      builder: (_) => OutletFormDialog(
        onSave: (outlet) => _createOutlet(outlet as VendorOutletCreate),
      ),
    );
  }

  void _editOutlet(VendorOutlet outlet) {
    showDialog(
      context: context,
      builder: (_) => OutletFormDialog(
        outlet: outlet,
        onSave: (updated) => _updateOutlet(updated as VendorOutlet),
      ),
    );
  }

  void _showOutletDetails(VendorOutlet outlet) {
    showDialog(
      context: context,
      builder: (_) => OutletDetailsDialog(outlet: outlet),
    );
  }

  void _viewOnMap(VendorOutlet outlet) {
    Navigator.pushNamed(
      context,
      '/map',
      arguments: {
        'latitude': outlet.latitude,
        'longitude': outlet.longitude,
        'title': outlet.outletName,
      },
    );
  }

  void _viewInventory(VendorOutlet outlet) {
    Navigator.pushNamed(
      context,
      '/inventory',
      arguments: {'outlet_id': outlet.outletId},
    );
  }

  void _showDeleteConfirmation(VendorOutlet outlet) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Outlet'),
        content: Text(
          'Are you sure you want to delete "${outlet.outletName}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteOutlet(outlet.outletId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// MODELS
// ============================================================================

class VendorOutlet {
  final int outletId;
  final int vendorId;
  final String outletName;
  final String outletCode;
  final String addressLine1;
  final String? addressLine2;
  final String city;
  final String county;
  final String? postalCode;
  final double latitude;
  final double longitude;
  final String? contactPhone;
  final String? managerName;
  final String? operatingHours;
  final String? facilities;

  VendorOutlet({
    required this.outletId,
    required this.vendorId,
    required this.outletName,
    required this.outletCode,
    required this.addressLine1,
    this.addressLine2,
    required this.city,
    required this.county,
    this.postalCode,
    required this.latitude,
    required this.longitude,
    this.contactPhone,
    this.managerName,
    this.operatingHours,
    this.facilities,
  });

  factory VendorOutlet.fromJson(Map<String, dynamic> json) {
    return VendorOutlet(
      outletId: json['outlet_id'] as int,
      vendorId: json['vendor_id'] as int,
      outletName: json['outlet_name'] ?? '',
      outletCode: json['outlet_code'] ?? '',
      addressLine1: json['address_line_1'] ?? '',
      addressLine2: json['address_line_2'],
      city: json['city'] ?? '',
      county: json['county'] ?? '',
      postalCode: json['postal_code'],
      latitude:
          double.tryParse(json['latitude']?.toString() ?? '') ?? -1.286389,
      longitude:
          double.tryParse(json['longitude']?.toString() ?? '') ?? 36.817223,
      contactPhone: json['contact_phone'],
      managerName: json['manager_name'],
      operatingHours: json['operating_hours'] is String
          ? json['operating_hours']
          : json['operating_hours'] != null
              ? jsonEncode(json['operating_hours'])
              : null,
      facilities: json['facilities'] is String
          ? json['facilities']
          : json['facilities'] != null
              ? jsonEncode(json['facilities'])
              : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'outlet_id': outletId,
        'vendor_id': vendorId,
        'outlet_name': outletName,
        'outlet_code': outletCode,
        'address_line_1': addressLine1,
        'address_line_2': addressLine2,
        'city': city,
        'county': county,
        'postal_code': postalCode,
        'latitude': latitude,
        'longitude': longitude,
        'contact_phone': contactPhone,
        'manager_name': managerName,
        'operating_hours': operatingHours,
        'facilities': facilities,
      };
}

class VendorOutletCreate {
  final String outletName;
  final String outletCode;
  final String addressLine1;
  final String? addressLine2;
  final String city;
  final String county;
  final String? postalCode;
  final double latitude;
  final double longitude;
  final String? contactPhone;
  final String? managerName;
  final String? operatingHours;
  final String? facilities;

  VendorOutletCreate({
    required this.outletName,
    required this.outletCode,
    required this.addressLine1,
    this.addressLine2,
    required this.city,
    required this.county,
    this.postalCode,
    required this.latitude,
    required this.longitude,
    this.contactPhone,
    this.managerName,
    this.operatingHours,
    this.facilities,
  });

  Map<String, dynamic> toJson() => {
        'outlet_name': outletName,
        'outlet_code': outletCode,
        'address_line_1': addressLine1,
        'address_line_2': addressLine2,
        'city': city,
        'county': county,
        'postal_code': postalCode,
        'latitude': latitude,
        'longitude': longitude,
        'contact_phone': contactPhone,
        'manager_name': managerName,
        'operating_hours': operatingHours,
        'facilities': facilities,
      };
}

// ============================================================================
// FORM DIALOG
// ============================================================================

class OutletFormDialog extends StatefulWidget {
  final VendorOutlet? outlet;
  final Function(dynamic) onSave;

  const OutletFormDialog({
    super.key,
    this.outlet,
    required this.onSave,
  });

  @override
  State<OutletFormDialog> createState() => _OutletFormDialogState();
}

class _OutletFormDialogState extends State<OutletFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _address1Controller = TextEditingController();
  final _address2Controller = TextEditingController();
  final _cityController = TextEditingController();
  final _countyController = TextEditingController();
  final _postalController = TextEditingController();
  final _phoneController = TextEditingController();
  final _managerController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.outlet != null) {
      final o = widget.outlet!;
      _nameController.text = o.outletName;
      _codeController.text = o.outletCode;
      _address1Controller.text = o.addressLine1;
      _address2Controller.text = o.addressLine2 ?? '';
      _cityController.text = o.city;
      _countyController.text = o.county;
      _postalController.text = o.postalCode ?? '';
      _phoneController.text = o.contactPhone ?? '';
      _managerController.text = o.managerName ?? '';
      _latController.text = o.latitude.toString();
      _lngController.text = o.longitude.toString();
    } else {
      // Default to Nairobi CBD
      _latController.text = '-1.286389';
      _lngController.text = '36.817223';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _address1Controller.dispose();
    _address2Controller.dispose();
    _cityController.dispose();
    _countyController.dispose();
    _postalController.dispose();
    _phoneController.dispose();
    _managerController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final isEditing = widget.outlet != null;

    final data = isEditing
        ? VendorOutlet(
            outletId: widget.outlet!.outletId,
            vendorId: widget.outlet!.vendorId,
            outletName: _nameController.text.trim(),
            outletCode: _codeController.text.trim(),
            addressLine1: _address1Controller.text.trim(),
            addressLine2: _address2Controller.text.trim().isEmpty
                ? null
                : _address2Controller.text.trim(),
            city: _cityController.text.trim(),
            county: _countyController.text.trim(),
            postalCode: _postalController.text.trim().isEmpty
                ? null
                : _postalController.text.trim(),
            contactPhone: _phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim(),
            managerName: _managerController.text.trim().isEmpty
                ? null
                : _managerController.text.trim(),
            latitude: double.parse(_latController.text),
            longitude: double.parse(_lngController.text),
            operatingHours: widget.outlet!.operatingHours,
            facilities: widget.outlet!.facilities,
          )
        : VendorOutletCreate(
            outletName: _nameController.text.trim(),
            outletCode: _codeController.text.trim(),
            addressLine1: _address1Controller.text.trim(),
            addressLine2: _address2Controller.text.trim().isEmpty
                ? null
                : _address2Controller.text.trim(),
            city: _cityController.text.trim(),
            county: _countyController.text.trim(),
            postalCode: _postalController.text.trim().isEmpty
                ? null
                : _postalController.text.trim(),
            contactPhone: _phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim(),
            managerName: _managerController.text.trim().isEmpty
                ? null
                : _managerController.text.trim(),
            latitude: double.parse(_latController.text),
            longitude: double.parse(_lngController.text),
          );

    widget.onSave(data);
    Navigator.pop(context);
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        isDense: true,
      ),
      keyboardType: keyboardType,
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.outlet == null ? 'Add Outlet' : 'Edit Outlet'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(_nameController, 'Outlet Name', required: true),
                const SizedBox(height: 12),
                _field(_codeController, 'Outlet Code', required: true),
                const SizedBox(height: 12),
                _field(_address1Controller, 'Address Line 1', required: true),
                const SizedBox(height: 12),
                _field(_address2Controller, 'Address Line 2'),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: _field(_cityController, 'City', required: true)),
                  const SizedBox(width: 12),
                  Expanded(
                      child:
                          _field(_countyController, 'County', required: true)),
                ]),
                const SizedBox(height: 12),
                _field(_postalController, 'Postal Code'),
                const SizedBox(height: 12),
                _field(_phoneController, 'Contact Phone',
                    keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                _field(_managerController, 'Manager Name'),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latController,
                      decoration: InputDecoration(
                        labelText: 'Latitude *',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (double.tryParse(v) == null) return 'Invalid';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lngController,
                      decoration: InputDecoration(
                        labelText: 'Longitude *',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (double.tryParse(v) == null) return 'Invalid';
                        return null;
                      },
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Text(
                  'Tip: Defaults to Nairobi CBD coordinates',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          child: Text(widget.outlet == null ? 'Create' : 'Save'),
        ),
      ],
    );
  }
}

// ============================================================================
// DETAILS DIALOG
// ============================================================================

class OutletDetailsDialog extends StatelessWidget {
  final VendorOutlet outlet;

  const OutletDetailsDialog({super.key, required this.outlet});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(outlet.outletName),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _row('Code', outlet.outletCode),
            _row('Address', outlet.addressLine1),
            if (outlet.addressLine2?.isNotEmpty == true)
              _row('', outlet.addressLine2!),
            _row('City', outlet.city),
            _row('County', outlet.county),
            if (outlet.postalCode != null)
              _row('Postal Code', outlet.postalCode!),
            if (outlet.contactPhone != null)
              _row('Phone', outlet.contactPhone!),
            if (outlet.managerName != null)
              _row('Manager', outlet.managerName!),
            _row('Coordinates', '${outlet.latitude}, ${outlet.longitude}'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label.isNotEmpty)
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 11,
                color: Colors.grey,
              ),
            ),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}
