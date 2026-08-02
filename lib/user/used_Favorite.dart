import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../used/detail_used.dart';

class UsedFavorite extends StatefulWidget {
  const UsedFavorite({Key? key}) : super(key: key);

  @override
  State<UsedFavorite> createState() => _UsedFavoritePreviewState();
}

class _UsedFavoritePreviewState extends State<UsedFavorite> {
  List<Map<String, dynamic>> items = [];
  List<bool> isFavorited = [];

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
      final list = List<Map<String, dynamic>>.from(data['favorites']);
      setState(() {
        items = list.take(5).toList();
        isFavorited = List.generate(items.length, (_) => true);
      });
    }
  }

  Future<void> toggleFavorite(int postId, bool status) async {
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
        'is_favorited': status,
      }),
    );
    fetchFavorites();
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        SizedBox(
          height: 160,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              final imageUrl = '$baseUrl/media/${item['image_url']}';

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UsedDetailPage(
                        postId: item['post_id'],
                        isLiked: isFavorited[index],
                        onToggleLike: (newStatus) {
                          setState(() {
                            isFavorited[index] = newStatus;
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
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: NetworkImage(imageUrl),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () async {
                              setState(() {
                                isFavorited[index] = !isFavorited[index];
                              });
                              await toggleFavorite(item['post_id'], isFavorited[index]);
                            },
                            child: Icon(
                              isFavorited[index] ? Icons.favorite : Icons.favorite_border,
                              color: isFavorited[index] ? Colors.red : Colors.grey,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 100,
                      child: Text(
                        item['title'] ?? '',
                        style: const TextStyle(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text('${item['price']}원', style: const TextStyle(fontSize: 12)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
