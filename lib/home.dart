import 'package:flutter/material.dart';
import 'database.dart';
import 'product.dart';
import 'product_detail.dart';
import 'product_service.dart';
import 'wishlist.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({required this.user, super.key});

  final LocalUser user;

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final _service = ProductService();
  final _searchController = TextEditingController();
  late Future<List<Product>> _productsFuture;
  Set<int> _wishlistIds = {};
  String _selectedCategory = 'Semua';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _productsFuture = _loadProducts();
    _loadWishlist();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Product>> _loadProducts() async {
    final products = await _service.fetchProducts();
    if (products.length < 10) {
      throw Exception('API hanya mengembalikan ${products.length} produk.');
    }
    return products;
  }

  Future<void> _loadWishlist() async {
    try {
      final ids = await AppDatabase.instance.getWishlist(widget.user.id);
      if (mounted) setState(() => _wishlistIds = ids);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Wishlist gagal dimuat: $error')));
    }
  }

  void _retry() {
    setState(() => _productsFuture = _loadProducts());
  }

  void _logout() {
    Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
  }

  Future<void> _toggleWishlistWithFeedback(Product product) async {
    try {
      final isAdded = await AppDatabase.instance.toggleWishlist(
        widget.user.id,
        product.id,
      );
      if (!mounted) return;
      setState(() {
        if (isAdded) {
          _wishlistIds.add(product.id);
        } else {
          _wishlistIds.remove(product.id);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: isAdded ? Colors.green : Colors.red,
          content: Text(
            isAdded
                ? '${product.title} ditambahkan ke wishlist!'
                : '${product.title} dihapus dari wishlist!',
            style: const TextStyle(color: Colors.white),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Wishlist gagal diperbarui: $error')),
      );
    }
  }

  Future<void> _openDetail(Product product) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          productId: product.id,
          user: widget.user,
          initiallyFavorite: _wishlistIds.contains(product.id),
          onWishlistChanged: (id, isFavorite) {
            setState(() {
              if (isFavorite) {
                _wishlistIds.add(id);
              } else {
                _wishlistIds.remove(id);
              }
            });
          },
        ),
      ),
    );
    _loadWishlist();
  }

  List<Product> _filterProducts(List<Product> products) {
    return products.where((product) {
      final matchesCategory =
          _selectedCategory == 'Semua' || product.category == _selectedCategory;
      final matchesSearch = product.title.toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
      return matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ShoppingHub',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Halo, ${widget.user.name}!',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Wishlist',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => WishlistScreen(user: widget.user),
                ),
              );
              _loadWishlist();
            },
            icon: Badge(
              isLabelVisible: _wishlistIds.isNotEmpty,
              backgroundColor: Theme.of(context).colorScheme.primary,
              textColor: Colors.white,
              label: Text('${_wishlistIds.length}'),
              child: const Icon(Icons.favorite_border),
            ),
          ),
          IconButton(
            tooltip: 'Keluar',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: FutureBuilder<List<Product>>(
        future: _productsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 14),
                  Text('Memuat produk...'),
                ],
              ),
            );
          }
          if (snapshot.hasError) {
            return _ErrorState(
              message: 'Produk tidak dapat dimuat.\n${snapshot.error}',
              onRetry: _retry,
            );
          }
          final allProducts = snapshot.data ?? const <Product>[];
          final products = _filterProducts(allProducts);
          return RefreshIndicator(
            onRefresh: () async {
              final future = _loadProducts();
              setState(() => _productsFuture = future);
              await future;
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildHeader(context)),
                SliverToBoxAdapter(
                  child: _buildCategories(context, allProducts),
                ),
                if (products.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: Text('Produk tidak ditemukan.')),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    sliver: SliverLayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.crossAxisExtent;
                        final count = width > 900
                            ? 4
                            : width > 600
                            ? 3
                            : 2;
                        return SliverGrid.builder(
                          itemCount: products.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: count,
                                mainAxisSpacing: 14,
                                crossAxisSpacing: 14,
                                childAspectRatio: width > 600 ? 0.72 : 0.64,
                              ),
                          itemBuilder: (context, index) {
                            final product = products[index];
                            return _ProductCard(
                              product: product,
                              isFavorite: _wishlistIds.contains(product.id),
                              onTap: () => _openDetail(product),
                              onFavorite: () =>
                                  _toggleWishlistWithFeedback(product),
                            );
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Temukan produk favoritmu',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Jelajahi produk pilihanmu!',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value.trim()),
            decoration: InputDecoration(
              hintText: 'Cari produk...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                      icon: const Icon(Icons.close),
                    ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategories(BuildContext context, List<Product> products) {
    final productCategories = products
        .map((product) => product.category)
        .toSet()
        .toList()
      ..sort();
    final categories = ['Semua', ...productCategories];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 54,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final category = categories[index];
              return ChoiceChip(
                label: Text(_categoryLabel(category)),
                selected: _selectedCategory == category,
                onSelected: (_) => setState(() => _selectedCategory = category),
              );
            },
          ),
        ),
      ],
    );
  }

  String _categoryLabel(String category) {
    return category
        .split('-')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.isFavorite,
    required this.onTap,
    required this.onFavorite,
  });

  final Product product;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _ProductImage(url: product.thumbnail),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.white.withValues(alpha: 0.92),
                      shape: const CircleBorder(),
                      child: IconButton(
                        onPressed: onFavorite,
                        constraints: const BoxConstraints.tightFor(
                          width: 38,
                          height: 38,
                        ),
                        padding: EdgeInsets.zero,
                        tooltip: isFavorite
                            ? 'Hapus dari wishlist'
                            : 'Tambah ke wishlist',
                        icon: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          size: 20,
                          color: isFavorite ? colors.error : colors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _displayCategory(product.category),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '\$${product.price.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.bold,
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

  String _displayCategory(String value) => value
      .split('-')
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return _placeholder();
    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Center(
          child: CircularProgressIndicator(
            value: progress.expectedTotalBytes == null
                ? null
                : progress.cumulativeBytesLoaded / progress.expectedTotalBytes!,
          ),
        );
      },
      errorBuilder: (_, _, _) => _placeholder(),
    );
  }

  Widget _placeholder() => Container(
    color: const Color(0xFFFCE4EC),
    alignment: Alignment.center,
    child: const Icon(Icons.image_not_supported_outlined, size: 38),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
