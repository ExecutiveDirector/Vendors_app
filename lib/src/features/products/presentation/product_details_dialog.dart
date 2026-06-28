import 'package:flutter/material.dart';
import 'dart:convert';

class ProductDetailsDialog extends StatefulWidget {
  final Map<String, dynamic> product;
  final VoidCallback onEdit;

  const ProductDetailsDialog({
    super.key,
    required this.product,
    required this.onEdit,
  });

  @override
  State<ProductDetailsDialog> createState() => _ProductDetailsDialogState();
}

class _ProductDetailsDialogState extends State<ProductDetailsDialog> {
  int _currentImageIndex = 0;
  List<String> imageUrls = [];

  @override
  void initState() {
    super.initState();
    _parseImages();
  }

  void _parseImages() {
    final productImages = widget.product['product_images'];
    if (productImages != null) {
      try {
        if (productImages is String && productImages.isNotEmpty) {
          final parsed = jsonDecode(productImages);
          if (parsed is List) {
            imageUrls = parsed.map((e) => e.toString()).toList();
          }
        } else if (productImages is List) {
          imageUrls = productImages.map((e) => e.toString()).toList();
        }
      } catch (e) {
        print('Error parsing images: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;
    final stockQuantity = widget.product['stock_quantity'] ?? 0;
    final isLowStock = stockQuantity < 10;

    return Dialog(
      child: Container(
        width: isWideScreen ? screenWidth * 0.7 : screenWidth * 0.95,
        constraints: const BoxConstraints(maxHeight: 800),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF064E3B), Color(0xFF10B981)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.product['product_name'] ?? 'Product Details',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image Gallery
                    if (imageUrls.isNotEmpty) ...[
                      _buildImageGallery(),
                      const SizedBox(height: 24),
                    ],

                    // Status Badges
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildBadge(
                          'KES ${widget.product['base_price']?.toStringAsFixed(2) ?? '0.00'}',
                          Colors.green,
                          Icons.attach_money,
                        ),
                        _buildBadge(
                          'Stock: $stockQuantity',
                          isLowStock ? Colors.red : Colors.blue,
                          Icons.inventory,
                        ),
                        if (widget.product['is_active'] == true)
                          _buildBadge(
                              'Active', Colors.green, Icons.check_circle),
                        if (widget.product['is_featured'] == true)
                          _buildBadge('Featured', Colors.orange, Icons.star),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Basic Information
                    _buildSection(
                      'Basic Information',
                      Icons.info,
                      [
                        _buildInfoRow('Product Code',
                            widget.product['product_code'], Icons.qr_code),
                        _buildInfoRow(
                            'Category', _getCategoryName(), Icons.category),
                        _buildInfoRow(
                            'Brand', widget.product['brand'], Icons.business),
                        _buildInfoRow(
                            'Size',
                            widget.product['size_specification'],
                            Icons.straighten),
                        _buildInfoRow(
                            'Unit',
                            _formatUnit(widget.product['unit_of_measure']),
                            Icons.scale),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Pricing Information
                    _buildSection(
                      'Pricing',
                      Icons.payments,
                      [
                        _buildInfoRow(
                            'Base Price',
                            'KES ${widget.product['base_price']?.toStringAsFixed(2)}',
                            Icons.attach_money),
                        if (widget.product['min_price'] != null)
                          _buildInfoRow(
                              'Min Price',
                              'KES ${widget.product['min_price']?.toStringAsFixed(2)}',
                              Icons.arrow_downward),
                        if (widget.product['max_price'] != null)
                          _buildInfoRow(
                              'Max Price',
                              'KES ${widget.product['max_price']?.toStringAsFixed(2)}',
                              Icons.arrow_upward),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Specifications
                    _buildSection(
                      'Specifications',
                      Icons.settings,
                      [
                        if (widget.product['weight_kg'] != null)
                          _buildInfoRow('Weight',
                              '${widget.product['weight_kg']} kg', Icons.scale),
                        if (widget.product['carbon_footprint_kg'] != null)
                          _buildInfoRow(
                              'Carbon Footprint',
                              '${widget.product['carbon_footprint_kg']} kg CO₂',
                              Icons.eco),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Description
                    if (widget.product['description'] != null &&
                        widget.product['description'].toString().isNotEmpty)
                      _buildSection(
                        'Description',
                        Icons.description,
                        [
                          Text(
                            widget.product['description'],
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),

                    // Timestamps
                    const SizedBox(height: 20),
                    _buildSection(
                      'Record Information',
                      Icons.access_time,
                      [
                        if (widget.product['created_at'] != null)
                          _buildInfoRow(
                              'Created',
                              _formatDate(widget.product['created_at']),
                              Icons.calendar_today),
                        if (widget.product['updated_at'] != null)
                          _buildInfoRow(
                              'Last Updated',
                              _formatDate(widget.product['updated_at']),
                              Icons.update),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Action Buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onEdit();
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit Product'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageGallery() {
    return Column(
      children: [
        // Main Image Display
        Container(
          height: 300,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey[100],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                Center(
                  child: Image.network(
                    imageUrls[_currentImageIndex],
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.broken_image,
                      size: 80,
                      color: Colors.grey,
                    ),
                  ),
                ),
                // Navigation Arrows
                if (imageUrls.length > 1) ...[
                  Positioned(
                    left: 8,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: IconButton(
                        onPressed: () {
                          setState(() {
                            _currentImageIndex =
                                (_currentImageIndex - 1 + imageUrls.length) %
                                    imageUrls.length;
                          });
                        },
                        icon: const Icon(Icons.arrow_back_ios),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: IconButton(
                        onPressed: () {
                          setState(() {
                            _currentImageIndex =
                                (_currentImageIndex + 1) % imageUrls.length;
                          });
                        },
                        icon: const Icon(Icons.arrow_forward_ios),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ),
                  ),
                ],
                // Image Counter
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_currentImageIndex + 1} / ${imageUrls.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Thumbnail Row
        if (imageUrls.length > 1) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: imageUrls.length,
              itemBuilder: (context, index) {
                final isSelected = index == _currentImageIndex;
                return GestureDetector(
                  onTap: () => setState(() => _currentImageIndex = index),
                  child: Container(
                    width: 60,
                    height: 60,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? Colors.green : Colors.grey[300]!,
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        imageUrls[index],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.broken_image,
                          size: 24,
                          color: Colors.grey[400],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: Colors.green),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, dynamic value, IconData icon) {
    if (value == null || value.toString().isEmpty || value == 'N/A') {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.toString(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _getCategoryName() {
    // You might want to pass categories to this dialog to show the name
    return widget.product['category_name'] ??
        'Category ID: ${widget.product['category_id']}';
  }

  String _formatUnit(String? unit) {
    if (unit == null) return 'N/A';
    switch (unit) {
      case 'kg':
        return 'Kilograms';
      case 'liters':
        return 'Liters';
      case 'pieces':
        return 'Pieces';
      case 'meters':
        return 'Meters';
      default:
        return unit;
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      final DateTime dateTime = DateTime.parse(date.toString());
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return date.toString();
    }
  }
}
