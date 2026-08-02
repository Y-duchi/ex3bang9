import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../constants.dart';
import '../models/favorite_helper.dart';
import 'product_detail.dart';

class TrendyFurniturePage extends StatefulWidget {
  const TrendyFurniturePage({super.key});

  @override
  State<TrendyFurniturePage> createState() => _TrendyFurniturePageState();
}

class _TrendyFurniturePageState extends State<TrendyFurniturePage> {
  List furnitureList = [];
  List<bool> likedList = [];
  final formatter = NumberFormat('#,###');

  @override
  void initState() {
    super.initState();
    fetchFurnitureList();
  }

  Future<void> fetchFurnitureList() async {
    final url = Uri.parse('$baseUrl/trendy_furniture_list/');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final all = decoded['furniture'] as List;

      furnitureList = all;
      likedList = List<bool>.filled(furnitureList.length, false);

      setState(() {});
      await fetchFavoriteStatus();
    } else {
      debugPrint('유행 가구 불러오기 실패: ${response.statusCode}');
    }
  }

  Future<void> fetchFavoriteStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    if (userId == null) return;

    final response = await http.get(
      Uri.parse('$baseUrl/favorite_items/?user_id=$userId&content_type=new'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final favorites = List<Map<String, dynamic>>.from(data['favorites']);

      setState(() {
        likedList = furnitureList.map((item) {
          return favorites.any((fav) => fav['product_id'] == item['furniture_id']);
        }).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('유행 가구', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                              image: NetworkImage(item['image_url'] ?? 'https://via.placeholder.com/150'),
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
                    Text(item['brand'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
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