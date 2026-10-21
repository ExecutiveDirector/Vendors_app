import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import '../data/product_model.dart';
import '../data/products_api.dart';
import 'image_picker.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/shared_widgets.dart';

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
  // All photos currently on the product, in display order — a mix of URLs
  // that existed before this screen opened (edit mode) and ones uploaded
  // during this session. This is the single source of truth sent on save,
  // so removing a photo here actually persists the removal instead of the
  // previous single-photo field silently discarding everything else.
  final _imagePicker = ImagePickerService();
  final List<String> _imageUrls = [];
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
    _imageUrls.addAll(_extractImageUrls(p?.productImages));
    _loadData();
  }

  // productImages can come back as a JSON-encoded string, a List, or a
  // single URL string depending on the endpoint — handle all three safely.
  List<String> _extractImageUrls(dynamic raw) {
    if (raw == null) return [];
    dynamic value = raw;
    if (value is String && value.isEmpty) return [];
    if (value is String &&
        !value.startsWith('http') &&
        !value.startsWith('/')) {
      // Likely a JSON-encoded array/string from the API — decode it.
      try {
        value = jsonDecode(value);
      } catch (_) {
        return [];
      }
    }
    if (value is String) return [value];
    if (value is List) {
      return value
          .map((e) {
            if (e is String) return e;
            if (e is Map) {
              return (e['url'] ?? e['image_url'] ?? e['path'])?.toString();
            }
            return null;
          })
          .whereType<String>()
          .toList();
    }
    return [];
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
  Future<void> _pickAndUploadImages() async {
    final result = await _imagePicker.showImageSourceBottomSheet(context,
        allowMultiple: true);
    if (result == null) return;

    final picked = result is List<XFile> ? result : [result as XFile];
    if (picked.isEmpty) return;

    setState(() => _uploadingImage = true);

    for (final file in picked) {
      final validation = await _imagePicker.validateImage(file);
      if (!validation.isValid) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('${file.name}: ${validation.errorMessage ?? 'Invalid image'}'),
            backgroundColor: AppColors.danger,
          ));
        }
        continue;
      }

      final url = await _imagePicker.uploadImage(
        image: file,
        uploadUrl: _kProductImageUploadUrl,
        dio: ApiClient.dio,
        fieldName: 'image',
        // In edit mode the backend appends this straight onto the
        // product's stored photo array, so it survives even if the
        // vendor backs out without tapping Save.
        additionalData: widget.product != null
            ? {'product_id': widget.product!.productId}
            : null,
      );

      if (!mounted) return;
      if (url != null) {
        setState(() => _imageUrls.add(url));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${file.name} failed to upload — skipped.'),
          backgroundColor: AppColors.danger,
        ));
      }
    }

    if (mounted) setState(() => _uploadingImage = false);
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
        // Always send the complete current list — this is what makes
        // removing a photo in this screen actually stick. (Previously this
        // sent only the single newest upload, which silently wiped out
        // every other photo already on the product.)
        'product_images': _imageUrls,
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
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(friendlyError(e)),
              backgroundColor: AppColors.danger),
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
                  _section('Product Photos', [_buildImagePicker()]),
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
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        height: 96,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (var i = 0; i < _imageUrls.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _photoThumb(
                  child: Image.network(
                    _imageUrls[i],
                    width: 96,
                    height: 96,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppColors.border,
                      child: const Icon(Icons.broken_image,
                          color: AppColors.muted, size: 28),
                    ),
                  ),
                  onRemove: _uploadingImage
                      ? null
                      : () => setState(() => _imageUrls.removeAt(i)),
                ),
              ),
            if (_uploadingImage)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppColors.subtle,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                      child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2))),
                ),
              ),
            InkWell(
              onTap: _uploadingImage ? null : _pickAndUploadImages,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.subtle,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_a_photo_outlined,
                          color: AppColors.muted, size: 24),
                      SizedBox(height: 4),
                      Text('Add', style: TextStyle(color: AppColors.muted)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 6),
      Text(
        _imageUrls.isEmpty
            ? 'No photos added yet — the first one is shown to customers.'
            : 'First photo is shown to customers. Tap Add for more, or the × to remove one.',
        style: TextStyle(color: AppColors.muted, fontSize: 12),
      ),
    ]);
  }

  Widget _photoThumb({required Widget child, VoidCallback? onRemove}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(borderRadius: BorderRadius.circular(8), child: child),
        if (onRemove != null)
          Positioned(
            top: -6,
            right: -6,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: AppColors.danger,
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.close, color: Colors.white, size: 14),
              ),
            ),
          ),
      ],
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.muted)),
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
