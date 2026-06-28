import 'package:flutter/material.dart';
import 'dart:convert';

class ProductCardWidget extends StatefulWidget {
  final Map<String, dynamic> product;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onTap;

  const ProductCardWidget({
    super.key,
    required this.product,
    required this.onDelete,
    required this.onEdit,
    required this.onTap,
  });

  @override
  State<ProductCardWidget> createState() => _ProductCardWidgetState();
}

class _ProductCardWidgetState extends State<ProductCardWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.972).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  // ── Image Parsing ─────────────────────────────────────────────────────────
  String? _firstImageUrl() {
    final raw = widget.product['product_images'];
    if (raw == null || raw.toString().isEmpty) return null;
    try {
      if (raw is String) {
        if (raw.startsWith('http')) return raw;
        final parsed = jsonDecode(raw);
        if (parsed is List && parsed.isNotEmpty) return parsed.first.toString();
      } else if (raw is List && raw.isNotEmpty) {
        return raw.first.toString();
      }
    } catch (_) {}
    return null;
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final stock = widget.product['stock_quantity'] ?? 0;
    final isOutOfStock = stock == 0;
    final isLowStock = stock > 0 && stock < 10;
    final isActive = widget.product['is_active'] ?? true;
    final isFeatured = widget.product['is_featured'] ?? false;
    final imageUrl = _firstImageUrl();

    return AnimatedBuilder(
      animation: _scaleAnim,
      builder: (context, child) =>
          Transform.scale(scale: _scaleAnim.value, child: child),
      child: GestureDetector(
        onTapDown: (_) => _pressCtrl.forward(),
        onTapUp: (_) {
          _pressCtrl.reverse();
          widget.onTap();
        },
        onTapCancel: () => _pressCtrl.reverse(),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.055),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                // Status accent stripe (left border)
                _buildAccentStripe(isOutOfStock, isLowStock, isActive),

                // Main content
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProductImage(imageUrl, isActive, isFeatured),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _buildInfo(
                              stock, isOutOfStock, isLowStock, isActive)),
                      const SizedBox(width: 8),
                      _buildActions(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccentStripe(bool isOutOfStock, bool isLowStock, bool isActive) {
    Color? color;
    if (!isActive) {
      color = Colors.grey[400];
    } else if (isOutOfStock) {
      color = Colors.red[700];
    } else if (isLowStock) {
      color = Colors.orange[600];
    }
    if (color == null) return const SizedBox.shrink();
    return Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      child: Container(width: 4, color: color),
    );
  }

  Widget _buildProductImage(String? imageUrl, bool isActive, bool isFeatured) {
    return Stack(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: const Color(0xFFF0F4F0),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: imageUrl != null
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : Container(
                            color: const Color(0xFFF0F4F0),
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: const Color(0xFF10B981),
                                value: progress.expectedTotalBytes != null
                                    ? progress.cumulativeBytesLoaded /
                                        progress.expectedTotalBytes!
                                    : null,
                              ),
                            ),
                          ),
                    errorBuilder: (_, __, ___) => _placeholder(),
                  )
                : _placeholder(),
          ),
        ),
        // Featured badge
        if (isFeatured)
          Positioned(
            top: 5,
            right: 5,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFF6F00), Color(0xFFFFA000)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.star_rounded, size: 10, color: Colors.white),
            ),
          ),
        // Inactive overlay
        if (!isActive)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.48),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  'INACTIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _placeholder() => Container(
        color: const Color(0xFFF0F4F0),
        child: Center(
          child: Icon(Icons.inventory_2_outlined,
              size: 32, color: Colors.grey[350]),
        ),
      );

  Widget _buildInfo(
      int stock, bool isOutOfStock, bool isLowStock, bool isActive) {
    final price = widget.product['base_price'];
    final name = widget.product['product_name'] ?? 'Unknown Product';
    final code = widget.product['product_code'];
    final size = widget.product['size_specification'];
    final category = widget.product['category_name'];
    final brand = widget.product['brand'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Active indicator + Name
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? const Color(0xFF10B981) : Colors.grey[400],
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isActive ? const Color(0xFF1A1A1A) : Colors.grey[500],
                  height: 1.25,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),

        // Code + Size
        if (code != null)
          Text(
            [code, if (size != null) size].join(' · '),
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF757575),
              fontFamily: 'monospace',
              letterSpacing: 0.3,
            ),
          ),

        // Brand
        if (brand != null && brand.toString().isNotEmpty) ...[
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(Icons.business_outlined, size: 11, color: Colors.grey[500]),
              const SizedBox(width: 3),
              Text(
                brand.toString(),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ],

        // Category chip
        if (category != null) ...[
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF064E3B).withOpacity(0.08),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              category,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF064E3B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],

        const SizedBox(height: 10),

        // Price + Stock badges
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            _priceBadge(price),
            _stockBadge(stock, isOutOfStock, isLowStock),
          ],
        ),

        // Low stock progress bar
        if (isLowStock) ...[
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: (stock / 10).clamp(0.0, 1.0),
                    backgroundColor: Colors.orange[100],
                    valueColor: AlwaysStoppedAnimation(Colors.orange[700]!),
                    minHeight: 4,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Low',
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.orange[700],
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _priceBadge(dynamic price) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF064E3B), Color(0xFF10B981)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'KES ',
            style: TextStyle(
                fontSize: 9,
                color: Colors.white70,
                fontWeight: FontWeight.w600),
          ),
          Text(
            price?.toStringAsFixed(0) ?? '0',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stockBadge(int stock, bool isOutOfStock, bool isLowStock) {
    final Color color;
    final IconData icon;
    final String text;

    if (isOutOfStock) {
      color = Colors.red[700]!;
      icon = Icons.remove_circle_outline;
      text = 'Out of Stock';
    } else if (isLowStock) {
      color = Colors.orange[700]!;
      icon = Icons.warning_amber_rounded;
      text = '$stock left';
    } else {
      color = Colors.blue[700]!;
      icon = Icons.check_circle_outline;
      text = '$stock in stock';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _actionBtn(
          icon: Icons.edit_outlined,
          color: Colors.blue[700]!,
          onTap: widget.onEdit,
          tooltip: 'Edit',
        ),
        const SizedBox(height: 8),
        _actionBtn(
          icon: Icons.delete_outline_rounded,
          color: Colors.red[700]!,
          onTap: widget.onDelete,
          tooltip: 'Delete',
        ),
      ],
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 17, color: color),
        ),
      ),
    );
  }
}
