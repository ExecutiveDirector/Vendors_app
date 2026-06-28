import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import '../../../core/api/dio_client.dart';
import './image_picker.dart';
import 'dart:io';

class EditProductDialog extends StatefulWidget {
  final List<dynamic> categories;
  final Map<String, dynamic> product;
  final VoidCallback onSave;

  const EditProductDialog({
    super.key,
    required this.categories,
    required this.product,
    required this.onSave,
  });

  @override
  State<EditProductDialog> createState() => _EditProductDialogState();
}

class _EditProductDialogState extends State<EditProductDialog> {
  final formKey = GlobalKey<FormState>();
  final imageService = ImagePickerService();

  // Controllers
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

  int? selectedCategory;
  late String selectedUnit;
  late bool isActive;
  late bool isFeatured;

  List<String> existingImageUrls = [];
  List<XFile> newImages = [];
  bool isSaving = false;
  bool isUploadingImages = false;
  int uploadProgress = 0;

  @override
  void initState() {
    super.initState();
    final product = widget.product;

    nameController = TextEditingController(text: product['product_name'] ?? '');
    codeController = TextEditingController(text: product['product_code'] ?? '');
    brandController = TextEditingController(text: product['brand'] ?? '');
    priceController =
        TextEditingController(text: product['base_price']?.toString() ?? '');
    minPriceController =
        TextEditingController(text: product['min_price']?.toString() ?? '');
    maxPriceController =
        TextEditingController(text: product['max_price']?.toString() ?? '');
    stockController = TextEditingController(
        text: product['stock_quantity']?.toString() ?? '0');
    sizeController =
        TextEditingController(text: product['size_specification'] ?? '');
    weightController =
        TextEditingController(text: product['weight_kg']?.toString() ?? '');
    carbonFootprintController = TextEditingController(
        text: product['carbon_footprint_kg']?.toString() ?? '');
    descriptionController =
        TextEditingController(text: product['description'] ?? '');
    selectedCategory = product['category_id'];
    selectedUnit = product['unit_of_measure'] ?? 'Kg';
    isActive = product['is_active'] ?? true;
    isFeatured = product['is_featured'] ?? false;

    // Parse images
    final images = product['product_images'];
    if (images != null) {
      try {
        if (images is String && images.isNotEmpty) {
          final parsed = jsonDecode(images);
          if (parsed is List) {
            existingImageUrls = parsed.map((e) => e.toString()).toList();
          }
        } else if (images is List) {
          existingImageUrls = images.map((e) => e.toString()).toList();
        }
      } catch (e) {
        debugPrint('❌ Error parsing product images: $e');
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
    super.dispose();
  }

  // 🖼️ Image Handling
  Future<void> _showImagePickerOptions() async {
    final result = await imageService.showImageSourceBottomSheet(context,
        allowMultiple: true);
    if (result == null) return;

    if (result is List<XFile>) {
      for (final img in result) {
        final validation = await imageService.validateImage(img);
        if (validation.isValid) newImages.add(img);
      }
      setState(() {});
    } else if (result is XFile) {
      final validation = await imageService.validateImage(result);
      if (validation.isValid) {
        setState(() => newImages.add(result));
      }
    }
  }

  void _removeExistingImage(int index) =>
      setState(() => existingImageUrls.removeAt(index));
  void _removeNewImage(int index) => setState(() => newImages.removeAt(index));

  // 💰 Validation
  bool _validatePrices() {
    final basePrice = double.tryParse(priceController.text);
    final minPrice = double.tryParse(
        minPriceController.text.isEmpty ? '0' : minPriceController.text);
    final maxPrice = double.tryParse(
        maxPriceController.text.isEmpty ? '0' : maxPriceController.text);

    if (basePrice == null || basePrice <= 0) {
      _showSnackBar('Base price must be greater than 0', isError: true);
      return false;
    }
    if (minPrice! > 0 && maxPrice! > 0 && minPrice > maxPrice) {
      _showSnackBar('Min price cannot be greater than max price',
          isError: true);
      return false;
    }
    return true;
  }

  // 💾 Update
  Future<void> _updateProduct() async {
    if (!formKey.currentState!.validate()) return;
    if (selectedCategory == null) {
      _showSnackBar('Please select a category', isError: true);
      return;
    }
    if (!_validatePrices()) return;

    setState(() => isSaving = true);
    try {
      List<String> allImageUrls = List.from(existingImageUrls);

      if (newImages.isNotEmpty) {
        setState(() => isUploadingImages = true);
        final uploaded = await imageService.uploadMultipleImages(
          images: newImages,
          uploadUrl: '/vendors/upload-image',
          dio: ApiClient.dio,
          onBatchProgress: (current, total) {
            setState(() => uploadProgress = current);
          },
        );
        allImageUrls.addAll(uploaded);
        setState(() => isUploadingImages = false);
      }

      final payload = {
        'product_name': nameController.text.trim(),
        'product_code': codeController.text.trim(),
        'category_id': selectedCategory,
        'brand': brandController.text.trim(),
        'base_price': double.parse(priceController.text),
        'min_price': minPriceController.text.isEmpty
            ? null
            : double.parse(minPriceController.text),
        'max_price': maxPriceController.text.isEmpty
            ? null
            : double.parse(maxPriceController.text),
        'stock_quantity': int.tryParse(stockController.text) ?? 0,
        'size_specification': sizeController.text.trim(),
        'unit_of_measure': selectedUnit,
        'weight_kg': double.tryParse(weightController.text) ?? 0,
        'carbon_footprint_kg':
            double.tryParse(carbonFootprintController.text) ?? 0,
        'description': descriptionController.text.trim(),
        'is_active': isActive,
        'is_featured': isFeatured,
        'product_images': jsonEncode(allImageUrls),
      };

      await ApiClient.dio.put(
          '/vendors/products/${widget.product['product_id']}',
          data: payload);
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSave();
      _showSnackBar('✅ Product updated successfully');
    } catch (e) {
      _showSnackBar('Error updating product: $e', isError: true);
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

  // 🔔 SnackBar
  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // 🧱 UI Builders
  Widget _buildSectionHeader(String title) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.black87)),
      );

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? prefix,
    bool requiredField = false,
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool readOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: requiredField
            ? (value) =>
                (value == null || value.isEmpty) ? '$label is required' : null
            : null,
        decoration: InputDecoration(
          prefixText: prefix,
          labelText: label,
          prefixIcon: icon != null ? Icon(icon) : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<int>(
      value: selectedCategory,
      decoration: InputDecoration(
        labelText: 'Category',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      items: widget.categories
          .map((cat) => DropdownMenuItem<int>(
                value: cat['category_id'],
                child: Text(cat['category_name'] ?? 'Unnamed'),
              ))
          .toList(),
      onChanged: (val) => setState(() => selectedCategory = val),
      validator: (val) => val == null ? 'Please select a category' : null,
    );
  }

  Widget _buildUnitDropdown() {
    final units = ['Litre', 'Kg', 'Piece', 'Cylinder'];
    return DropdownButtonFormField<String>(
      value: selectedUnit,
      decoration: InputDecoration(
        labelText: 'Unit',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      items:
          units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
      onChanged: (val) => setState(() => selectedUnit = val ?? 'Kg'),
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (int i = 0; i < existingImageUrls.length; i++)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(existingImageUrls[i],
                        height: 100, width: 100, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: InkWell(
                      onTap: () => _removeExistingImage(i),
                      child: const CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.red,
                        child: Icon(Icons.close, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              ),
            for (int i = 0; i < newImages.length; i++)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(newImages[i].path),
                      height: 100,
                      width: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: InkWell(
                      onTap: () => _removeNewImage(i),
                      child: const CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.red,
                        child: Icon(Icons.close, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              ),
            GestureDetector(
              onTap: _showImagePickerOptions,
              child: Container(
                height: 100,
                width: 100,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade100,
                ),
                child: const Icon(Icons.add_a_photo, color: Colors.grey),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 600;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.edit, color: Colors.green),
          SizedBox(width: 8),
          Text('Edit Product'),
        ],
      ),
      content: SizedBox(
        width: isWide ? 600 : double.maxFinite,
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('Images'),
                _buildImageSection(),
                const SizedBox(height: 20),
                _buildSectionHeader('Basic Information'),
                _buildTextField(
                    controller: nameController,
                    label: 'Product Name',
                    requiredField: true,
                    icon: Icons.shopping_bag),
                _buildTextField(
                    controller: codeController,
                    label: 'Product Code',
                    readOnly: true,
                    icon: Icons.qr_code),
                _buildCategoryDropdown(),
                _buildTextField(
                    controller: brandController,
                    label: 'Brand',
                    icon: Icons.business),
                const SizedBox(height: 12),
                _buildSectionHeader('Pricing & Stock'),
                _buildTextField(
                    controller: priceController,
                    label: 'Base Price',
                    prefix: 'KES ',
                    keyboardType: TextInputType.number,
                    requiredField: true),
                _buildTextField(
                    controller: stockController,
                    label: 'Stock Quantity',
                    keyboardType: TextInputType.number),
                Row(
                  children: [
                    Expanded(
                        child: _buildTextField(
                            controller: minPriceController,
                            label: 'Min Price',
                            keyboardType: TextInputType.number)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _buildTextField(
                            controller: maxPriceController,
                            label: 'Max Price',
                            keyboardType: TextInputType.number)),
                  ],
                ),
                const SizedBox(height: 12),
                _buildSectionHeader('Specifications'),
                Row(
                  children: [
                    Expanded(
                        child: _buildTextField(
                            controller: sizeController,
                            label: 'Size',
                            icon: Icons.straighten)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildUnitDropdown()),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                        child: _buildTextField(
                            controller: weightController,
                            label: 'Weight (Kg)',
                            keyboardType: TextInputType.number,
                            icon: Icons.scale)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _buildTextField(
                            controller: carbonFootprintController,
                            label: 'Carbon Footprint',
                            keyboardType: TextInputType.number,
                            icon: Icons.eco)),
                  ],
                ),
                _buildTextField(
                    controller: descriptionController,
                    label: 'Description',
                    icon: Icons.description,
                    maxLines: 3),
                const SizedBox(height: 12),
                _buildSectionHeader('Status'),
                SwitchListTile(
                  title: const Text('Active'),
                  subtitle: const Text('Product visible to customers'),
                  value: isActive,
                  onChanged: (val) => setState(() => isActive = val),
                  activeColor: Colors.green,
                ),
                SwitchListTile(
                  title: const Text('Featured'),
                  subtitle: const Text('Shown in featured section'),
                  value: isFeatured,
                  onChanged: (val) => setState(() => isFeatured = val),
                  activeColor: Colors.orange,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: isSaving ? null : () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton.icon(
          onPressed: isSaving ? null : _updateProduct,
          icon: isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.save),
          label: Text(isSaving ? 'Saving...' : 'Save Changes'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
        ),
      ],
    );
  }
}
