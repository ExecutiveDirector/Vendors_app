import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../../core/api/dio_client.dart';
import './image_picker.dart';

class AddProductDialog extends StatefulWidget {
  final List<dynamic> categories;
  final Map<String, dynamic>? product; // non-null = edit mode
  final VoidCallback onSave;

  const AddProductDialog({
    super.key,
    required this.categories,
    required this.onSave,
    this.product,
  });

  @override
  State<AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<AddProductDialog> {
  final formKey = GlobalKey<FormState>();
  final imageService = ImagePickerService();

  late TextEditingController nameController;
  late TextEditingController codeController;
  late TextEditingController brandController;
  late TextEditingController priceController;
  late TextEditingController minPriceController;
  late TextEditingController maxPriceController;
  late TextEditingController stockController;
  late TextEditingController sizeController;
  late TextEditingController weightController;
  late TextEditingController carbonFootprintController;
  late TextEditingController descriptionController;
  late TextEditingController urlController; // ✅ URL input

  int? selectedCategory;
  String selectedUnit = 'kg';
  bool isActive = true;
  bool isFeatured = false;

  List<XFile> selectedImages = []; // files picked from device
  List<String> imageUrls = []; // ✅ URLs pasted by user
  bool isSaving = false;
  bool isUploadingImages = false;
  int uploadProgress = 0;

  bool get isEditMode => widget.product != null;

  // ── Helpers ────────────────────────────────────────────────────────────────

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  static bool _toBool(dynamic v) {
    if (v is bool) return v;
    if (v is int) return v == 1;
    return false;
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    final p = widget.product;

    nameController = TextEditingController(text: p?['product_name'] ?? '');
    codeController = TextEditingController(text: p?['product_code'] ?? '');
    brandController = TextEditingController(text: p?['brand'] ?? '');
    priceController = TextEditingController(
        text: p != null ? _toDouble(p['base_price']).toStringAsFixed(0) : '');
    minPriceController = TextEditingController(
        text: p?['min_price'] != null
            ? _toDouble(p!['min_price']).toStringAsFixed(0)
            : '');
    maxPriceController = TextEditingController(
        text: p?['max_price'] != null
            ? _toDouble(p!['max_price']).toStringAsFixed(0)
            : '');
    stockController = TextEditingController(
        text: p?['current_stock']?.toString() ??
            p?['stock_quantity']?.toString() ??
            '0');
    sizeController =
        TextEditingController(text: p?['size_specification'] ?? '');
    weightController = TextEditingController(
        text: p?['weight_kg'] != null
            ? _toDouble(p!['weight_kg']).toString()
            : '');
    carbonFootprintController = TextEditingController(
        text: p?['carbon_footprint_kg'] != null
            ? _toDouble(p!['carbon_footprint_kg']).toString()
            : '');
    descriptionController =
        TextEditingController(text: p?['description'] ?? '');
    urlController = TextEditingController();

    // Pre-fill edit-mode values
    if (p != null) {
      selectedCategory = p['category_id'];
      selectedUnit = p['unit_of_measure'] ?? 'kg';
      isActive = _toBool(p['is_active'] ?? true);
      isFeatured = _toBool(p['is_featured'] ?? false);

      // Pre-load existing image URLs
      final existing = p['product_images'];
      if (existing != null) {
        try {
          final decoded = existing is String ? jsonDecode(existing) : existing;
          if (decoded is List) {
            imageUrls = List<String>.from(decoded);
          }
        } catch (_) {
          if (existing is String && existing.startsWith('http')) {
            imageUrls = [existing];
          }
        }
      }
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    codeController.dispose();
    brandController.dispose();
    priceController.dispose();
    minPriceController.dispose();
    maxPriceController.dispose();
    stockController.dispose();
    sizeController.dispose();
    weightController.dispose();
    carbonFootprintController.dispose();
    descriptionController.dispose();
    urlController.dispose(); // ✅
    super.dispose();
  }

  // ── Image handling ─────────────────────────────────────────────────────────

  Future<void> _showImagePickerOptions() async {
    final result = await imageService.showImageSourceBottomSheet(
      context,
      allowMultiple: true,
    );
    if (result != null) {
      if (result is List<XFile>) {
        await _handleMultipleImages(result);
      } else if (result is XFile) {
        await _handleSingleImage(result);
      }
    }
  }

  Future<void> _handleSingleImage(XFile image) async {
    final validation = await imageService.validateImage(image);
    if (!validation.isValid) {
      _showSnackBar(validation.errorMessage ?? 'Invalid image', isError: true);
      return;
    }
    setState(() => selectedImages.add(image));
  }

  Future<void> _handleMultipleImages(List<XFile> images) async {
    int added = 0, failed = 0;
    for (final image in images) {
      final v = await imageService.validateImage(image);
      if (v.isValid) {
        setState(() => selectedImages.add(image));
        added++;
      } else {
        failed++;
      }
    }
    if (failed > 0) {
      _showSnackBar('$added added, $failed failed', isError: failed > added);
    } else {
      _showSnackBar('$added image(s) added');
    }
  }

  void _removeFileImage(int index) =>
      setState(() => selectedImages.removeAt(index));

  void _removeUrlImage(int index) => setState(() => imageUrls.removeAt(index));

  void _addUrlImage() {
    final url = urlController.text.trim();
    if (url.isEmpty) return;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      _showSnackBar('URL must start with http:// or https://', isError: true);
      return;
    }
    setState(() {
      imageUrls.add(url);
      urlController.clear();
    });
  }

  // ── Validation ─────────────────────────────────────────────────────────────

  bool _validatePrices() {
    final base = double.tryParse(priceController.text);
    final min = minPriceController.text.isEmpty
        ? null
        : double.tryParse(minPriceController.text);
    final max = maxPriceController.text.isEmpty
        ? null
        : double.tryParse(maxPriceController.text);

    if (base == null || base <= 0) {
      _showSnackBar('Base price must be greater than 0', isError: true);
      return false;
    }
    if (min != null && max != null && min > max) {
      _showSnackBar('Min price cannot exceed max price', isError: true);
      return false;
    }
    if (min != null && base < min) {
      _showSnackBar('Base price cannot be less than min price', isError: true);
      return false;
    }
    if (max != null && base > max) {
      _showSnackBar('Base price cannot exceed max price', isError: true);
      return false;
    }
    return true;
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  Future<void> _saveProduct() async {
    if (!formKey.currentState!.validate()) return;
    if (selectedCategory == null) {
      _showSnackBar('Please select a category', isError: true);
      return;
    }
    if (!_validatePrices()) return;

    setState(() => isSaving = true);

    try {
      // Start with pasted/existing URLs
      final List<String> allImageUrls = List.from(imageUrls);

      // Upload newly picked files
      if (selectedImages.isNotEmpty) {
        setState(() => isUploadingImages = true);
        final uploaded = await imageService.uploadMultipleImages(
          images: selectedImages,
          uploadUrl: '/vendors/upload-image',
          dio: ApiClient.dio,
          onBatchProgress: (current, total) =>
              setState(() => uploadProgress = current),
        );
        allImageUrls.addAll(uploaded);
        setState(() => isUploadingImages = false);
      }

      final payload = {
        'product_name': nameController.text.trim(),
        'product_code': codeController.text.trim(),
        'category_id': selectedCategory,
        'brand': brandController.text.trim().isEmpty
            ? null
            : brandController.text.trim(),
        'base_price': double.parse(priceController.text),
        'min_price': minPriceController.text.isEmpty
            ? null
            : double.parse(minPriceController.text),
        'max_price': maxPriceController.text.isEmpty
            ? null
            : double.parse(maxPriceController.text),
        'stock_quantity': int.parse(stockController.text),
        'size_specification': sizeController.text.trim().isEmpty
            ? null
            : sizeController.text.trim(),
        'unit_of_measure': selectedUnit,
        'weight_kg': weightController.text.isEmpty
            ? null
            : double.parse(weightController.text),
        'carbon_footprint_kg': carbonFootprintController.text.isEmpty
            ? null
            : double.parse(carbonFootprintController.text),
        'description': descriptionController.text.trim().isEmpty
            ? null
            : descriptionController.text.trim(),
        'is_active': isActive,
        'is_featured': isFeatured,
        // ✅ Combined URLs (pasted + uploaded)
        'product_images':
            allImageUrls.isEmpty ? null : jsonEncode(allImageUrls),
      };

      if (isEditMode) {
        // Vendor-scoped self-service update — PUT /admin/products/:id
        // previously used here is admin-only (requireAdminRole) and would
        // 403 for any real vendor; this is the actual vendor endpoint.
        final id = widget.product!['product_id'];
        await ApiClient.dio.put('/vendors/products/$id', data: payload);
      } else {
        // ✅ Create mode
        await ApiClient.dio.post('/vendors/products', data: payload);
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSave();
        _showSnackBar(isEditMode
            ? 'Product updated successfully'
            : 'Product added successfully');
      }
    } catch (e) {
      _showSnackBar(
          '${isEditMode ? 'Error updating' : 'Error adding'} product: $e',
          isError: true);
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
          isUploadingImages = false;
          uploadProgress = 0;
        });
      }
    }
  }

  // ── Snackbar ───────────────────────────────────────────────────────────────

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red : Colors.green,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 600;

    return AlertDialog(
      title: Row(
        children: [
          Icon(isEditMode ? Icons.edit : Icons.add_box, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
              child: Text(isEditMode ? 'Edit Product' : 'Add New Product')),
          if (isUploadingImages)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
      content: SizedBox(
        width: isWide ? screenWidth * 0.7 : screenWidth * 0.9,
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Images ──────────────────────────────────────────────
                _buildSectionHeader(
                    'Product Images (${imageUrls.length + selectedImages.length})'),
                _buildImageSection(),

                if (isUploadingImages)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(children: [
                      LinearProgressIndicator(
                        value: selectedImages.isEmpty
                            ? 0
                            : uploadProgress / selectedImages.length,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Uploading $uploadProgress of ${selectedImages.length}...',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ]),
                  ),

                const SizedBox(height: 24),

                // ── Basic Info ───────────────────────────────────────────
                _buildSectionHeader('Basic Information'),
                _buildTextField(
                  controller: nameController,
                  label: 'Product Name',
                  required: true,
                  icon: Icons.shopping_bag,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: codeController,
                  label: 'Product Code',
                  required: true,
                  icon: Icons.qr_code,
                  hint: 'Unique identifier',
                ),
                const SizedBox(height: 16),
                _buildCategoryDropdown(),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: brandController,
                  label: 'Brand',
                  icon: Icons.business,
                ),
                const SizedBox(height: 24),

                // ── Pricing ──────────────────────────────────────────────
                _buildSectionHeader('Pricing'),
                Row(children: [
                  Expanded(
                    child: _buildTextField(
                      controller: priceController,
                      label: 'Base Price',
                      required: true,
                      icon: Icons.attach_money,
                      keyboardType: TextInputType.number,
                      prefix: 'KES ',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: stockController,
                      label: 'Stock Quantity',
                      required: true,
                      icon: Icons.inventory,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: _buildTextField(
                      controller: minPriceController,
                      label: 'Min Price',
                      icon: Icons.arrow_downward,
                      keyboardType: TextInputType.number,
                      prefix: 'KES ',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: maxPriceController,
                      label: 'Max Price',
                      icon: Icons.arrow_upward,
                      keyboardType: TextInputType.number,
                      prefix: 'KES ',
                    ),
                  ),
                ]),
                const SizedBox(height: 24),

                // ── Specifications ───────────────────────────────────────
                _buildSectionHeader('Specifications'),
                Row(children: [
                  Expanded(
                    child: _buildTextField(
                      controller: sizeController,
                      label: 'Size Specification',
                      icon: Icons.straighten,
                      hint: 'e.g., 13kg, 6kg',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _buildUnitDropdown()),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: _buildTextField(
                      controller: weightController,
                      label: 'Weight (kg)',
                      icon: Icons.scale,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: carbonFootprintController,
                      label: 'Carbon Footprint (kg)',
                      icon: Icons.eco,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: descriptionController,
                  label: 'Description',
                  icon: Icons.description,
                  maxLines: 4,
                ),
                const SizedBox(height: 24),

                // ── Status ───────────────────────────────────────────────
                _buildSectionHeader('Product Status'),
                Row(children: [
                  Expanded(
                    child: SwitchListTile(
                      title: const Text('Active'),
                      subtitle: const Text('Product is visible'),
                      value: isActive,
                      onChanged: (v) => setState(() => isActive = v),
                      activeColor: Colors.green,
                    ),
                  ),
                  Expanded(
                    child: SwitchListTile(
                      title: const Text('Featured'),
                      subtitle: const Text('Show in featured'),
                      value: isFeatured,
                      onChanged: (v) => setState(() => isFeatured = v),
                      activeColor: Colors.orange,
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: isSaving ? null : _saveProduct,
          icon: isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Icon(isEditMode ? Icons.save : Icons.add),
          label: Text(isSaving
              ? (isEditMode ? 'Saving...' : 'Adding...')
              : (isEditMode ? 'Save Changes' : 'Add Product')),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ],
    );
  }

  // ── Image section ──────────────────────────────────────────────────────────

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── URL input row ──────────────────────────────────────────────
        Row(children: [
          Expanded(
            child: TextField(
              controller: urlController,
              decoration: InputDecoration(
                hintText: 'Paste image URL (https://...)',
                prefixIcon: const Icon(Icons.link, color: Colors.green),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onSubmitted: (_) => _addUrlImage(),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _addUrlImage,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Add'),
          ),
        ]),
        const SizedBox(height: 12),

        // ── URL image previews ─────────────────────────────────────────
        if (imageUrls.isNotEmpty) ...[
          Row(children: [
            const Icon(Icons.link, size: 14, color: Colors.grey),
            const SizedBox(width: 4),
            Text('URL Images (${imageUrls.length})',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ]),
          const SizedBox(height: 6),
          SizedBox(
            height: 110,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: imageUrls.length,
              itemBuilder: (_, i) => _buildUrlImagePreview(imageUrls[i], i),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ── File image previews ────────────────────────────────────────
        if (selectedImages.isNotEmpty) ...[
          Row(children: [
            const Icon(Icons.photo, size: 14, color: Colors.grey),
            const SizedBox(width: 4),
            Text('Device Images (${selectedImages.length})',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ]),
          const SizedBox(height: 6),
          SizedBox(
            height: 110,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: selectedImages.length,
              itemBuilder: (_, i) => _buildFileImagePreview(
                imageFile: File(selectedImages[i].path),
                onRemove: () => _removeFileImage(i),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ── Pick from device button ────────────────────────────────────
        OutlinedButton.icon(
          onPressed: isUploadingImages ? null : _showImagePickerOptions,
          icon: const Icon(Icons.add_photo_alternate),
          label: const Text('Pick from device'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.green,
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Paste a URL above or pick images from your device',
          style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  // ── URL image card ─────────────────────────────────────────────────────────

  Widget _buildUrlImagePreview(String url, int index) {
    return Container(
      width: 100,
      height: 100,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Stack(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            url,
            fit: BoxFit.cover,
            width: 100,
            height: 100,
            errorBuilder: (_, __, ___) => Container(
              color: Colors.grey[100],
              child: const Center(
                  child: Icon(Icons.broken_image, color: Colors.grey)),
            ),
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return Container(
                color: Colors.grey[100],
                child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2)),
              );
            },
          ),
        ),
        // Remove button
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => _removeUrlImage(index),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                  color: Colors.red, shape: BoxShape.circle),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
        // URL badge
        Positioned(
          bottom: 4,
          left: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text('URL',
                style: TextStyle(color: Colors.white, fontSize: 9)),
          ),
        ),
      ]),
    );
  }

  // ── File image card ────────────────────────────────────────────────────────

  Widget _buildFileImagePreview({
    required File imageFile,
    required VoidCallback onRemove,
  }) {
    return Container(
      width: 100,
      height: 100,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Stack(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child:
              Image.file(imageFile, fit: BoxFit.cover, width: 100, height: 100),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                  color: Colors.red, shape: BoxShape.circle),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Form helpers ───────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title,
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool required = false,
    IconData? icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? prefix,
    String? hint,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon, color: Colors.green) : null,
        prefixText: prefix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: (value) {
        if (required && (value == null || value.trim().isEmpty)) {
          return 'This field is required';
        }
        if (keyboardType == TextInputType.number &&
            value != null &&
            value.isNotEmpty) {
          if (double.tryParse(value) == null) return 'Enter a valid number';
        }
        return null;
      },
    );
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<int>(
      value: selectedCategory,
      decoration: InputDecoration(
        labelText: 'Category *',
        prefixIcon: const Icon(Icons.category, color: Colors.green),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      items: widget.categories.isEmpty
          ? [
              const DropdownMenuItem<int>(
                  value: null,
                  enabled: false,
                  child: Text('No categories available'))
            ]
          : widget.categories.map<DropdownMenuItem<int>>((cat) {
              return DropdownMenuItem<int>(
                value: cat['category_id'],
                child: Text(cat['category_name'] ?? 'N/A'),
              );
            }).toList(),
      onChanged: widget.categories.isEmpty
          ? null
          : (v) => setState(() => selectedCategory = v),
      validator: (v) => v == null && widget.categories.isNotEmpty
          ? 'Select a category'
          : null,
    );
  }

  Widget _buildUnitDropdown() {
    return DropdownButtonFormField<String>(
      value: selectedUnit,
      decoration: InputDecoration(
        labelText: 'Unit *',
        prefixIcon: const Icon(Icons.straighten, color: Colors.green),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      items: const [
        DropdownMenuItem(value: 'kg', child: Text('Kilograms')),
        DropdownMenuItem(value: 'liters', child: Text('Liters')),
        DropdownMenuItem(value: 'pieces', child: Text('Pieces')),
        DropdownMenuItem(value: 'meters', child: Text('Meters')),
      ],
      onChanged: (v) => setState(() => selectedUnit = v!),
      validator: (v) => v == null ? 'Select a unit' : null,
    );
  }
}
