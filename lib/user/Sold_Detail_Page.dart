import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/used_furniture_model.dart';
import '../constants.dart';
import '../used/detail_used.dart';

class SoldDetailPage extends StatefulWidget {
  const SoldDetailPage({super.key});

  @override
  State<SoldDetailPage> createState() => _SoldDetailPageState();
}

class _SoldDetailPageState extends State<SoldDetailPage> {
  List<UsedFurniture> onSaleItems = [];
  String? userId;
  List<int> likeCounts = [];
  List<bool> liked = [];

  @override
  void initState() {
    super.initState();
    loadUserId();
  }

  Future<void> loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getString('user_id');
    if (userId != null) {
      await fetchUserOnSalePosts();
      await fetchAllLikeCounts();
      await fetchUsedFavoriteStatus();
    }
  }

  Future<void> fetchUserOnSalePosts() async {
    final response = await http.get(Uri.parse('$baseUrl/sold_furniture_list/'));
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as List;
      final allPosts = data.map((item) => UsedFurniture.fromJson(item)).toList();
      setState(() {
        onSaleItems = allPosts.where((post) =>
        (post.transactionType == '판매' || post.transactionType == '나눔') &&
            post.userId == userId
        ).toList();

        likeCounts = List.filled(onSaleItems.length, 0);
        liked = List.filled(onSaleItems.length, false);
      });
    } else {
      debugPrint('판매완료 글 가져오기 실패: ${response.statusCode}');
    }
  }

  Future<void> fetchAllLikeCounts() async {
    for (int i = 0; i < onSaleItems.length; i++) {
      final id = onSaleItems[i].postId;
      final response = await http.get(
        Uri.parse('$baseUrl/favorite/count/?furniture_id=$id&content_type=used'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          likeCounts[i] = data['like_count'] ?? 0;
        });
      }
    }
  }

  Future<void> fetchUsedFavoriteStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    if (userId == null) return;

    final response = await http.get(
      Uri.parse('$baseUrl/favorite_items/?user_id=$userId&content_type=used'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final favorites = List<Map<String, dynamic>>.from(data['favorites']);
      setState(() {
        liked = onSaleItems.map((item) {
          return favorites.any((fav) =>
          (fav['post_id'] ?? fav['furniture_id']) == item.postId);
        }).toList();
      });
    } else {
      debugPrint('중고거래 좋아요 상태 불러오기 실패: ${response.statusCode}');
    }
  }

  Future<void> toggleFavorite({
    required String productId,
    required String contentType,
    required bool isFavorited,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    if (userId == null) return;

    final response = await http.post(
      Uri.parse('$baseUrl/favorite_items/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'content_type': contentType,
        'furniture_id': productId,
        'is_favorited': isFavorited,
      }),
    );

    if (response.statusCode != 200) {
      debugPrint('좋아요 상태 변경 실패: ${response.statusCode}');
    }
  }

  Future<bool> markPostAsSold(int postId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/used_furniture/mark_sold/$postId/'),
    );

    return response.statusCode == 200;
  }

  String formatDate(DateTime date) {
    return DateFormat('yyyy.MM.dd').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text('판매 완료', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: onSaleItems.isEmpty
          ? const Center(child: Text('판매 완료인 게시글이 없습니다.'))
          : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: onSaleItems.length,
        itemBuilder: (context, index) {
          final item = onSaleItems[index];

          String imageUrl = item.imageUrls.isNotEmpty ? item.imageUrls[0] : '';
          if (imageUrl.isNotEmpty && !imageUrl.startsWith('http')) {
            imageUrl = '$baseUrl/media/$imageUrl';
          }

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UsedDetailPage(
                    postId: item.postId,
                    isLiked: liked[index],
                    onToggleLike: (bool newStatus) async {
                      setState(() {
                        liked[index] = newStatus;
                        likeCounts[index] += newStatus ? 1 : -1;
                      });

                      await toggleFavorite(
                        productId: onSaleItems[index].postId.toString(),
                        contentType: 'used',
                        isFavorited: newStatus,
                      );

                      await fetchUsedFavoriteStatus();
                    },
                  ),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black26),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Stack(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        item.imageUrls.isNotEmpty
                            ? Image.network(
                          item.imageUrls[0].startsWith('http')
                              ? item.imageUrls[0]
                              : '$baseUrl/media/${item.imageUrls[0]}',
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                        )
                            : Container(width: 120, height: 120, color: Colors.grey),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                formatDate(DateTime.parse(item.createdAt)),
                                style: const TextStyle(fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '조회수 ${item.views} | 찜 ${likeCounts.length > index ? likeCounts[index] : 0}',
                                style: const TextStyle(fontSize: 12, color: Colors.black54),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            const SizedBox(height: 4),
                            IconButton(
                              icon: Icon(
                                liked.length > index && liked[index]
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: liked.length > index && liked[index]
                                    ? Colors.red
                                    : Colors.black,
                              ),
                              onPressed: () async {
                                final newStatus = !liked[index];
                                setState(() {
                                  liked[index] = newStatus;
                                  likeCounts[index] += newStatus ? 1 : -1;
                                });

                                await toggleFavorite(
                                  productId: onSaleItems[index].postId.toString(),
                                  contentType: 'used',
                                  isFavorited: newStatus,
                                );

                                await fetchUsedFavoriteStatus();
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}