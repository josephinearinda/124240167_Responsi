import 'dart:convert';
import 'package:http/http.dart' as http;
import 'product.dart';

class ProductService {
  ProductService({http.Client? client}) : _client = client ?? http.Client();

  static const _baseUrl = 'https://dummyjson.com/products';
  final http.Client _client;

  Future<List<Product>> fetchProducts() async {
    final response = await _client
        .get(Uri.parse('$_baseUrl?limit=30'))
        .timeout(const Duration(seconds: 15));
    _ensureSuccessful(response);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final products = data['products'] as List<dynamic>;
    return products
        .map((item) => Product.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<String>> fetchCategories() async {
    final response = await _client
        .get(Uri.parse('$_baseUrl/category-list'))
        .timeout(const Duration(seconds: 15));
    _ensureSuccessful(response);
    return (jsonDecode(response.body) as List<dynamic>).cast<String>();
  }

  Future<Product> fetchProduct(int id) async {
    final response = await _client
        .get(Uri.parse('$_baseUrl/$id'))
        .timeout(const Duration(seconds: 15));
    _ensureSuccessful(response);
    return Product.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  void _ensureSuccessful(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Permintaan API gagal (HTTP ${response.statusCode}).');
    }
  }
}
