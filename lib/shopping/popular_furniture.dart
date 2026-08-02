import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../constants.dart';
import '../models/favorite_helper.dart';
import 'product_detail.dart';

class  PopularFurniturePage extends StatefulWidget {
  const  PopularFurniturePage({super.key});

  @override
  State<PopularFurniturePage> createState() => _NewFurniturePageState();
}

class _NewFurniturePageState extends State< PopularFurniturePage> {
  List furnitureList = [];
  List<bool> likedList = [];
  final formatter = NumberFormat('#,###');

  @override
  void initState() {
    super.initState();
    fetchFurnitureList();
  }



  Future<void> fetchFurnitureList() async {
    final url = Uri.parse('$baseUrl/popular_furniture_list/');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final all = decoded['furniture'] as List;

      furnitureList = all;
      likedList = List<bool>.filled(furnitureList.length, false);

      // 좋아요 상태만 체크하면 됨
      await fetchFavoriteStatus();

      setState(() {});
    } else {
      debugPrint('가구 불러오기 실패: ${response.statusCode}');
    }
  }



  List<Map<String, dynamic>> favoriteData = [];

  Future<void> fetchFavoriteStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    if (userId == null) return;

    final response = await http.get(
      Uri.parse('$baseUrl/favorite_items/?user_id=$userId&content_type=new'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      favoriteData = List<Map<String, dynamic>>.from(data['favorites']);

      setState(() {
        likedList = furnitureList.map((item) {
          return favoriteData.any((fav) => fav['product_id'] == item['furniture_id']);
        }).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('인기 가구', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: furnitureList.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : GridView.builder(
            itemCount: furnitureList.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.75,
            ),
            padding: const EdgeInsets.only(bottom: 80), // 하단 여유
            itemBuilder: (context, index) {
              final item = furnitureList[index];
              final isLiked = likedList[index];

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductDetailPage(
                        productId: item['furniture_id'],
                        productName: item['name'],
                        isLiked: isLiked,
                        onToggleLike: (newStatus) {
                          setState(() {
                            likedList[index] = newStatus;
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
                        Container(
                          height: 140,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: NetworkImage(item['image_url'] ??
                                  'https://via.placeholder.com/150'),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                            color: isLiked ? Colors.red : Colors.grey,
                          ),
                          onPressed: () async {
                            if (item['furniture_id'] == null) return;

                            setState(() {
                              likedList[index] = !likedList[index];
                            });

                            await toggleFavorite(
                              productId: item['furniture_id'],
                              contentType: 'new',
                              isFavorited: likedList[index],
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(item['brand'] ?? '',
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(item['name'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text('${formatter.format(item['min_price'] ?? 0)}원'),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}