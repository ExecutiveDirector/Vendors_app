import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import '../data/product_model.dart';
import '../data/products_api.dart';
import 'image_picker.dart';
import '../../../core/api/dio_client.dart';

// Verified against the real backend: routes/vendors.js mounts this at
// POST /vendors/upload-image (NOT /vendors/products/upload-image), handled
// by vendorController.uploadProductImage with multer wired in front of it.
const String _kProductImageUploadUrl = '/vendors/upload-image';

class ProductFormScreen extends StatefulWidget {
  final Product? product;
  const ProductFormScreen({super.key, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _code;
  late final TextEditingController _brand;
  late final TextEditingController _description;
  late final TextEditingController _size;
  late final TextEditingController _price;
  late final TextEditingController _stock;

  List<Category> _categories = [];
  List<dynamic> _outlets = [];
  int? _selectedCategory;
  String? _selectedOutlet;
  bool _isActive = true;
  bool _isFeatured = false;
  bool _saving = false;
  bool _loading = true;

  // ── Image upload state ──────────────────────────────────────────────────
  final _imagePicker = ImagePickerService();
  XFile? _pickedImage; // local file just chosen, not yet uploaded
  String? _uploadedImageUrl; // URL returned by server after upload
  String? _existingImageUrl; // image already on the product (edit mode)
  bool _uploadingImage = false;

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _name = TextEditingController(text: p?.productName ?? '');
    _code = TextEditingController(text: p?.productCode ?? '');
    _brand = TextEditingController(text: p?.brand ?? '');
    _description = TextEditingController(text: p?.description ?? '');
    _size = TextEditingController(text: p?.sizeSpecification ?? '');
    _price = TextEditingController(text: p?.basePrice.toString() ?? '');
    _stock = TextEditingController(text: p?.currentStock?.toString() ?? '0');
    _selectedCategory = p?.categoryId;
    _isActive = p?.isActive ?? true;
    _isFeatured = p?.isFeatured ?? false;
    _existingImageUrl = _extractFirstImageUrl(p?.productImages);
    _loadData();
  }

  // productImages can come back as a JSON-encoded string, a List, or a
  // single URL string depending on the endpoint — handle all three safely.
  String? _extractFirstImageUrl(dynamic raw) {
    if (raw == null) return null;
    if (raw is String && raw.isEmpty) return null;
    if (raw is String && (raw.startsWith('http') || raw.startsWith('/'))) {
      return raw;
    }
    if (raw is List && raw.isNotEmpty) {
      final first = raw.first;
      if (first is String) return first;
      if (first is Map) {
        return (first['url'] ?? first['image_url'] ?? first['path'])
            ?.toString();
      }
    }
    return null;
  }

  Future<void> _loadData() async {
    try {
      final cats = await ProductsApi.categories();
      final outlets = await ProductsApi.outlets();
      if (mounted) {
        setState(() {
          _categories = cats;
          _outlets = outlets;
          if (outlets.isNotEmpty) {
            _selectedOutlet = outlets.first['outlet_id']?.toString();
          }
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Image pick + upload ───────────────────────────────────────────────────
  Future<void> _pickAndUploadImage() async {
    final result = await _imagePicker.showImageSourceBottomSheet(context);
    if (result == null || result is! XFile) return;

    final validation = await _imagePicker.validateImage(result);
    if (!validation.isValid) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(validation.errorMessage ?? 'Invalid image'),
          backgroundColor: Colors.red,
        ));
      }
      return;
    }

    setState(() {
      _pickedImage = result;
      _uploadingImage = true;
    });

    final url = await _imagePicker.uploadImage(
      image: result,
      uploadUrl: _kProductImageUploadUrl,
      dio: ApiClient.dio,
      fieldName: 'image',
      additionalData: widget.product != null
          ? {'product_id': widget.product!.productId}
          : null,
    );

    if (!mounted) return;
    setState(() => _uploadingImage = false);

    if (url == null) {
      setState(() => _pickedImage = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Image upload failed. The product will be saved without it — you can add an image by editing it again.'),
          backgroundColor: Colors.red,
        ));
      }
      return;
    }

    setState(() => _uploadedImageUrl = url);
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _brand.dispose();
    _description.dispose();
    _size.dispose();
    _price.dispose();
    _stock.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final payload = {
        'product_name': _name.text.trim(),
        'product_code': _code.text.trim(),
        'brand': _brand.text.trim(),
        'description': _description.text.trim(),
        'size_specification': _size.text.trim(),
        'base_price': double.parse(_price.text),
        'category_id': _selectedCategory,
        'is_active': _isActive,
        'is_featured': _isFeatured,
        'stock_quantity': int.tryParse(_stock.text) ?? 0,
        'outlet_id': _selectedOutlet,
        if (_uploadedImageUrl != null) 'product_images': [_uploadedImageUrl],
      };
      if (_isEdit) {
        await ProductsApi.update(widget.product!.productId, payload);
      } else {
        await ProductsApi.create(payload);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEdit ? 'Product updated!' : 'Product created!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Product' : 'Add Product'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: const Text('Save'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _section('Product Photo', [_buildImagePicker()]),
                  const SizedBox(height: 16),
                  _section('Basic Info', [
                    _field('Product Name *', _name, required: true),
                    const SizedBox(height: 12),
                    _field('Product Code / SKU *', _code, required: true),
                    const SizedBox(height: 12),
                    _field('Brand', _brand),
                    const SizedBox(height: 12),
                    _field('Description', _description, maxLines: 3),
                    const SizedBox(height: 12),
                    _field('Size / Specification', _size,
                        hint: 'e.g. 6kg, 13kg, 35kg'),
                  ]),
                  const SizedBox(height: 16),
                  _section('Pricing & Stock', [
                    _field('Base Price (KES) *', _price,
                        required: true,
                        keyboardType: TextInputType.number, validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (double.tryParse(v) == null)
                        return 'Enter a valid number';
                      return null;
                    }),
                    const SizedBox(height: 12),
                    _field('Initial Stock Quantity', _stock,
                        keyboardType: TextInputType.number),
                  ]),
                  const SizedBox(height: 16),
                  _section('Category & Outlet', [
                    if (_categories.isNotEmpty)
                      DropdownButtonFormField<int>(
                        value: _selectedCategory,
                        decoration:
                            const InputDecoration(labelText: 'Category'),
                        items: _categories
                            .map((c) => DropdownMenuItem(
                                value: c.categoryId,
                                child: Text(c.categoryName)))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedCategory = v),
                      ),
                    const SizedBox(height: 12),
                    if (_outlets.isNotEmpty && !_isEdit)
                      DropdownButtonFormField<String>(
                        value: _selectedOutlet,
                        decoration: const InputDecoration(labelText: 'Outlet'),
                        items: _outlets
                            .map((o) => DropdownMenuItem<String>(
                                value: o['outlet_id']?.toString(),
                                child: Text(o['outlet_name'] ?? '')))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedOutlet = v),
                      ),
                  ]),
                  const SizedBox(height: 16),
                  _section('Settings', [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Active'),
                      subtitle: const Text('Product visible to customers'),
                      value: _isActive,
                      onChanged: (v) => setState(() => _isActive = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Featured'),
                      subtitle: const Text('Show in featured section'),
                      value: _isFeatured,
                      onChanged: (v) => setState(() => _isFeatured = v),
                    ),
                  ]),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: Text(
                      _saving
                          ? 'Saving...'
                          : (_isEdit ? 'Update Product' : 'Create Product'),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildImagePicker() {
    final hasLocal = _pickedImage != null;
    final hasRemote = _uploadedImageUrl != null || _existingImageUrl != null;

    Widget preview;
    if (_uploadingImage) {
      preview = const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (hasLocal) {
      preview = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(File(_pickedImage!.path),
            height: 160, width: double.infinity, fit: BoxFit.cover),
      );
    } else if (hasRemote) {
      preview = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          _uploadedImageUrl ?? _existingImageUrl!,
          height: 160,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            height: 160,
            color: Colors.grey[200],
            child:
                const Icon(Icons.broken_image, color: Colors.grey, size: 32),
          ),
        ),
      );
    } else {
      preview = Container(
        height: 160,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_a_photo_outlined, color: Colors.grey, size: 32),
              SizedBox(height: 8),
              Text('No photo added', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      preview,
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _uploadingImage ? null : _pickAndUploadImage,
            icon: const Icon(Icons.photo_camera_outlined),
            label: Text(hasRemote || hasLocal ? 'Change Photo' : 'Add Photo'),
          ),
        ),
        if ((hasRemote || hasLocal) && !_uploadingImage) ...[
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => setState(() {
              _pickedImage = null;
              _uploadedImageUrl = null;
              _existingImageUrl = null;
            }),
            icon: const Icon(Icons.close, color: Colors.red),
            tooltip: 'Remove photo',
          ),
        ],
      ]),
    ]);
  }

  Widget _section(String title, List<Widget> children) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ),
    ]);
  }

  Widget _field(
    String label,
    TextEditingController ctrl, {
    bool required = false,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
      ),
      validator: validator ??
          (required
              ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
              : null),
    );
  }
}
