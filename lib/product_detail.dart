import 'package:flutter/material.dart';
import 'database.dart';
import 'product.dart';
import 'product_service.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({
    required this.productId,
    required this.user,
    required this.initiallyFavorite,
    required this.onWishlistChanged,
    super.key,
  });

  final int productId;
  final LocalUser user;
  final bool initiallyFavorite;
  final void Function(int productId, bool isFavorite) onWishlistChanged;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final _service = ProductService();
  late Future<Product> _productFuture;
  late bool _isFavorite;
  bool _isUpdatingWishlist = false;

  @override
  void initState() {
    super.initState();
    _productFuture = _service.fetchProduct(widget.productId);
    _isFavorite = widget.initiallyFavorite;
  }

  Future<void> _toggleFavorite(Product product) async {
    if (_isUpdatingWishlist) return;
    setState(() => _isUpdatingWishlist = true);
    try {
      final isFavorite = await AppDatabase.instance.toggleWishlist(
        widget.user.id,
        product.id,
      );
      if (!mounted) return;
      setState(() => _isFavorite = isFavorite);
      widget.onWishlistChanged(product.id, isFavorite);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: isFavorite ? Colors.green : Colors.red,
          content: Text(
            isFavorite
                ? 'Produk ditambahkan ke wishlist.'
                : 'Produk dihapus dari wishlist.',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Wishlist gagal diperbarui: $error')),
      );
    } finally {
      if (mounted) setState(() => _isUpdatingWishlist = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail produk')),
      body: FutureBuilder<Product>(
        future: _productFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_outlined, size: 44),
                    const SizedBox(height: 12),
                    Text(
                      'Detail produk tidak dapat dimuat.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => setState(
                        () => _productFuture = _service.fetchProduct(
                          widget.productId,
                        ),
                      ),
                      child: const Text('Coba lagi'),
                    ),
                  ],
                ),
              ),
            );
          }
          final product = snapshot.data!;
          return _buildDetails(context, product);
        },
      ),
    );
  }

  Widget _buildDetails(BuildContext context, Product product) {
    final colors = Theme.of(context).colorScheme;
    final images = product.images.isEmpty
        ? [product.thumbnail]
        : product.images;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        SizedBox(
          height: 300,
          child: PageView.builder(
            itemCount: images.length,
            itemBuilder: (context, index) => ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Image.network(
                images[index],
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Container(
                  color: colors.surfaceContainerHighest,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.image_not_supported_outlined,
                    size: 48,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Chip(
                    label: Text(_formatCategory(product.category)),
                    visualDensity: VisualDensity.compact,
                  ),
                  Text(
                    product.title,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (product.brand.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Brand: ${product.brand}',
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: _isUpdatingWishlist
                  ? null
                  : () => _toggleFavorite(product),
              style: FilledButton.styleFrom(
                backgroundColor: _isFavorite
                    ? Colors.green
                    : colors.primaryContainer,
                foregroundColor: _isFavorite ? Colors.white : colors.primary,
              ),
              icon: Icon(_isFavorite ? Icons.favorite : Icons.favorite_border),
              label: const Text('Wishlist'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          '\$${product.price.toStringAsFixed(2)}',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(color: colors.primary, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            _InfoPill(
              icon: Icons.star,
              label: product.rating.toStringAsFixed(1),
            ),
            _InfoPill(
              icon: Icons.inventory_2_outlined,
              label: '${product.stock} tersedia',
            ),
            _InfoPill(
              icon: Icons.local_offer_outlined,
              label: 'Diskon ${product.discountPercentage.toStringAsFixed(1)}%',
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Deskripsi',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          product.description,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
        ),
      ],
    );
  }

  String _formatCategory(String category) => category
      .split('-')
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}
