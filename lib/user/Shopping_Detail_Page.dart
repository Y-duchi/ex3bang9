// ShoppingDetailPage.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../shopping/product_detail.dart';

class ShoppingDetailPage extends StatefulWidget {
  const ShoppingDetailPage({super.key});

  @override
  State<ShoppingDetailPage> createState() => _ShoppingDetailPageState();
}

class _ShoppingDetailPageState extends State<ShoppingDetailPage> {
  List<Map<String, dynamic>> productList = [];
  List<bool> _isFavorited = [];

  @override
  void initState() {
    super.initState();
    fetchFavorites();
  }

  Future<void> fetchFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    if (userId == null) return;

    final response = await http.get(
      Uri.parse('$baseUrl/favorite_items/?user_id=$userId&content_type=new'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final items = List<Map<String, dynamic>>.from(data['favorites']);
      setState(() {
        productList = items;
        _isFavorited = List.generate(items.length, (_) => true);
      });
    }
  }

  Future<void> toggleFavorite(int productId, bool isFavorited) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    if (userId == null) return;

    await http.post(
      Uri.parse('$baseUrl/favorite_items/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'content_type': 'new',
        'furniture_id': productId,
        'is_favorited': isFavorited,
      }),
    );
    fetchFavorites(); // 갱신
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('쇼핑 찜 목록'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: GridView.builder(
          itemCount: productList.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 20,
            childAspectRatio: 0.7,
          ),
          itemBuilder: (context, index) {
            final product = productList[index];
            final productId = product['product_id'];
            final imageUrl = product['image_url'] ?? '';
            final name = product['name'] ?? '';
            final brand = product['brand'] ?? '';
            final price = product['price'] ?? 0;

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductDetailPage(
                      productId: productId,
                      productName: name,
                      isLiked: _isFavorited[index],
                      onToggleLike: (newStatus) {
                        setState(() {
                          _isFavorited[index] = newStatus;
                        });
                      },
                    ),
                  ),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    alignment: Alignment.topRight,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          imageUrl,
                          height: 140,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _isFavorited[index] ? Icons.favorite : Icons.favorite_border,
                          color: _isFavorited[index] ? Colors.red : Colors.grey,
                        ),
                        onPressed: () async {
                          setState(() {
                            _isFavorited[index] = !_isFavorited[index];
                          });
                          await toggleFavorite(productId, _isFavorited[index]);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    brand,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${price.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',')}원',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
