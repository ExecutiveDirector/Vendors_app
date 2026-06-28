import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/dio_client.dart';

class AddOutletScreen extends StatefulWidget {
  /// Pass an existing outlet_id to edit; null = create new.
  final int? outletId;

  const AddOutletScreen({super.key, this.outletId});

  @override
  State<AddOutletScreen> createState() => _AddOutletScreenState();
}

class _AddOutletScreenState extends State<AddOutletScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _saving = false;

  // ── Controllers ──────────────────────────────────────────────────────────
  final _outletNameCtrl = TextEditingController();
  final _outletCodeCtrl = TextEditingController();
  final _address1Ctrl = TextEditingController();
  final _address2Ctrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _countyCtrl = TextEditingController();
  final _postalCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _managerCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();

  bool get _isEdit => widget.outletId != null;

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    if (_isEdit) _loadOutlet();
  }

  @override
  void dispose() {
    _outletNameCtrl.dispose();
    _outletCodeCtrl.dispose();
    _address1Ctrl.dispose();
    _address2Ctrl.dispose();
    _cityCtrl.dispose();
    _countyCtrl.dispose();
    _postalCtrl.dispose();
    _phoneCtrl.dispose();
    _managerCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────────────────────
  Future<void> _loadOutlet() async {
    setState(() => _loading = true);
    try {
      final res =
          await ApiClient.dio.get('/vendors/outlets/${widget.outletId}');
      final data = res.data as Map<String, dynamic>? ?? {};
      _outletNameCtrl.text = data['outlet_name'] ?? '';
      _outletCodeCtrl.text = data['outlet_code'] ?? '';
      _address1Ctrl.text = data['address_line_1'] ?? '';
      _address2Ctrl.text = data['address_line_2'] ?? '';
      _cityCtrl.text = data['city'] ?? '';
      _countyCtrl.text = data['county'] ?? '';
      _postalCtrl.text = data['postal_code'] ?? '';
      _phoneCtrl.text = data['contact_phone'] ?? '';
      _managerCtrl.text = data['manager_name'] ?? '';
      _latCtrl.text = data['latitude']?.toString() ?? '';
      _lngCtrl.text = data['longitude']?.toString() ?? '';
    } catch (_) {
      _showError('Failed to load outlet data');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final payload = {
      'outlet_name': _outletNameCtrl.text.trim(),
      'outlet_code': _outletCodeCtrl.text.trim().toUpperCase(),
      'address_line_1': _address1Ctrl.text.trim(),
      'address_line_2':
          _address2Ctrl.text.trim().isEmpty ? null : _address2Ctrl.text.trim(),
      'city': _cityCtrl.text.trim(),
      'county': _countyCtrl.text.trim(),
      'postal_code':
          _postalCtrl.text.trim().isEmpty ? null : _postalCtrl.text.trim(),
      'contact_phone':
          _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      'manager_name':
          _managerCtrl.text.trim().isEmpty ? null : _managerCtrl.text.trim(),
      'latitude': double.tryParse(_latCtrl.text.trim()),
      'longitude': double.tryParse(_lngCtrl.text.trim()),
    };

    try {
      if (_isEdit) {
        await ApiClient.dio
            .put('/vendors/outlets/${widget.outletId}', data: payload);
        _showSuccess('Outlet updated successfully');
      } else {
        await ApiClient.dio.post('/vendors/outlets', data: payload);
        _showSuccess('Outlet created successfully');
      }
      if (mounted) context.pop();
    } catch (e) {
      _showError(
          _isEdit ? 'Failed to update outlet' : 'Failed to create outlet');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Snackbars ─────────────────────────────────────────────────────────────
  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white),
        const SizedBox(width: 8),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: const Color(0xFFEF4444),
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_outline, color: Colors.white),
        const SizedBox(width: 8),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: const Color(0xFF10B981),
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Outlet' : 'Add Outlet'),
        backgroundColor: const Color(0xFFFF8A00),
        foregroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Color(0xFFFF8A00)),
              ),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _Section(
                    title: 'Basic Information',
                    icon: Icons.storefront_outlined,
                    children: [
                      _Field(
                        controller: _outletNameCtrl,
                        label: 'Outlet Name',
                        hint: 'e.g. Westlands Branch',
                        required: true,
                        capitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 16),
                      _Field(
                        controller: _outletCodeCtrl,
                        label: 'Outlet Code',
                        hint: 'e.g. WL-001',
                        required: true,
                        capitalization: TextCapitalization.characters,
                        helper: 'Unique short identifier for this outlet',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _Section(
                    title: 'Location',
                    icon: Icons.location_on_outlined,
                    children: [
                      _Field(
                        controller: _address1Ctrl,
                        label: 'Address Line 1',
                        hint: 'Street address',
                        required: true,
                      ),
                      const SizedBox(height: 16),
                      _Field(
                        controller: _address2Ctrl,
                        label: 'Address Line 2',
                        hint: 'Building / floor (optional)',
                      ),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(
                          child: _Field(
                            controller: _cityCtrl,
                            label: 'City / Town',
                            hint: 'e.g. Nairobi',
                            required: true,
                            capitalization: TextCapitalization.words,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _Field(
                            controller: _countyCtrl,
                            label: 'County',
                            hint: 'e.g. Nairobi',
                            required: true,
                            capitalization: TextCapitalization.words,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      _Field(
                        controller: _postalCtrl,
                        label: 'Postal Code',
                        hint: 'e.g. 00100',
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _Section(
                    title: 'GPS Coordinates',
                    icon: Icons.my_location_outlined,
                    subtitle: 'Used for delivery routing and nearby search',
                    children: [
                      Row(children: [
                        Expanded(
                          child: _Field(
                            controller: _latCtrl,
                            label: 'Latitude',
                            hint: 'e.g. -1.2864',
                            required: true,
                            keyboardType: const TextInputType.numberWithOptions(
                                signed: true, decimal: true),
                            validator: _validateCoord,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _Field(
                            controller: _lngCtrl,
                            label: 'Longitude',
                            hint: 'e.g. 36.8172',
                            required: true,
                            keyboardType: const TextInputType.numberWithOptions(
                                signed: true, decimal: true),
                            validator: _validateCoord,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFFCB80)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.info_outline,
                              color: Color(0xFFFF8A00), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Open Google Maps, long-press your outlet location, '
                              'and copy the coordinates shown.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                        ]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _Section(
                    title: 'Contact Details',
                    icon: Icons.contact_phone_outlined,
                    children: [
                      _Field(
                        controller: _phoneCtrl,
                        label: 'Contact Phone',
                        hint: '+254 7XX XXX XXX',
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                      _Field(
                        controller: _managerCtrl,
                        label: 'Manager Name',
                        hint: 'Person responsible for this outlet',
                        capitalization: TextCapitalization.words,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF8A00),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            const Color(0xFFFF8A00).withOpacity(0.6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : Text(
                              _isEdit ? 'Save Changes' : 'Create Outlet',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  String? _validateCoord(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    if (double.tryParse(value.trim()) == null) return 'Invalid number';
    return null;
  }
}

// ── Reusable Section Card ─────────────────────────────────────────────────────
class _Section extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final List<Widget> children;

  const _Section({
    required this.title,
    required this.icon,
    required this.children,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
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
            Icon(icon, color: const Color(0xFFFF8A00), size: 20),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  )),
              if (subtitle != null)
                Text(subtitle!,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ]),
          ]),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }
}

// ── Reusable Form Field ───────────────────────────────────────────────────────
class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool required;
  final TextInputType keyboardType;
  final TextCapitalization capitalization;
  final String? helper;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.required = false,
    this.keyboardType = TextInputType.text,
    this.capitalization = TextCapitalization.none,
    this.helper,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: capitalization,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        hintText: hint,
        helperText: helper,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
        hintStyle: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFFF8A00), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      ),
      validator: validator ??
          (required
              ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
              : null),
    );
  }
}
