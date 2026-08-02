// UsedMarketDetailPage.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../used/detail_used.dart';


class UsedMarketDetailPage extends StatefulWidget {
  const UsedMarketDetailPage({super.key});

  @override
  State<UsedMarketDetailPage> createState() => _UsedMarketDetailPageState();
}

class _UsedMarketDetailPageState extends State<UsedMarketDetailPage> {
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
      Uri.parse('$baseUrl/favorite_items/?user_id=$userId&content_type=used'),
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

  Future<void> toggleFavorite(int postId, bool isFavorited) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    if (userId == null) return;

    await http.post(
      Uri.parse('$baseUrl/favorite_items/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'content_type': 'used',
        'furniture_id': postId,
        'is_favorited': isFavorited,
      }),
    );
    fetchFavorites();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('중고거래 찜 목록'),
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
            final postId = product['post_id'];
            final imageUrl = '$baseUrl/media/${product['image_url'] ?? ''}';
            final title = product['title'] ?? '';
            final price = product['price'] ?? 0;

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UsedDetailPage(
                      postId: postId,
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
                          await toggleFavorite(postId, _isFavorited[index]);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '중고거래',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
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
