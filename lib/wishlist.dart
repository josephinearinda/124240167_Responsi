import 'package:flutter/material.dart';
import 'database.dart';
import 'product.dart';
import 'product_detail.dart';
import 'product_service.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({required this.user, super.key});

  final LocalUser user;

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  final _service = ProductService();
  late Future<List<Product>> _wishlistFuture;

  @override
  void initState() {
    super.initState();
    _wishlistFuture = _loadWishlist();
  }

  Future<List<Product>> _loadWishlist() async {
    final ids = await AppDatabase.instance.getWishlist(widget.user.id);
    if (ids.isEmpty) return [];
    final products = await _service.fetchProducts();
    return products.where((product) => ids.contains(product.id)).toList();
  }

  void _remove(Product product, List<Product> products) {
    setState(() {
      _wishlistFuture = Future.value(
        products.where((item) => item.id != product.id).toList(),
      );
    });
    _removeFromDatabase(product);
  }

  Future<void> _removeFromDatabase(Product product) async {
    try {
      await AppDatabase.instance.removeFromWishlist(widget.user.id, product.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.title} dihapus dari wishlist'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _wishlistFuture = _loadWishlist());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Wishlist gagal diperbarui: $error')),
      );
    }
  }

  Widget _deleteBackground({required bool alignRight}) {
    return Container(
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.redAccent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: alignRight
            ? const [
                Text(
                  'Delete',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.delete, color: Colors.white, size: 28),
              ]
            : const [
                Icon(Icons.delete, color: Colors.white, size: 28),
                SizedBox(width: 8),
                Text(
                  'Delete',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
      ),
    );
  }

  Future<void> _openDetail(Product product) async {
    final isFavorite = (await AppDatabase.instance.getWishlist(widget.user.id))
        .contains(product.id);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          productId: product.id,
          user: widget.user,
          initiallyFavorite: isFavorite,
          onWishlistChanged: (_, _) {
            setState(() => _wishlistFuture = _loadWishlist());
          },
        ),
      ),
    );
    if (mounted) setState(() => _wishlistFuture = _loadWishlist());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wishlist')),
      body: FutureBuilder<List<Product>>(
        future: _wishlistFuture,
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
                    Text(
                      'Wishlist tidak dapat dimuat\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () =>
                          setState(() => _wishlistFuture = _loadWishlist()),
                      child: const Text('Coba lagi'),
                    ),
                  ],
                ),
              ),
            );
          }
          final products = snapshot.data ?? const <Product>[];
          if (products.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.favorite_border,
                      size: 56,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Wishlist masih kosong',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    const Text('Simpan produk yang kamu sukai untuk nanti'),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: products.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final product = products[index];
              return Dismissible(
                key: ValueKey('wishlist_${product.id}'),
                direction: DismissDirection.horizontal,
                background: _deleteBackground(alignRight: false),
                secondaryBackground: _deleteBackground(alignRight: true),
                onDismissed: (_) => _remove(product, products),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    onTap: () => _openDetail(product),
                    contentPadding: const EdgeInsets.all(10),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        product.thumbnail,
                        width: 68,
                        height: 68,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 68,
                          height: 68,
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          child: const Icon(Icons.image_not_supported_outlined),
                        ),
                      ),
                    ),
                    title: Text(
                      product.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        '\$${product.price.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
