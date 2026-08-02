import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'product_detail.dart';

class BudgetResultPage extends StatefulWidget {
  final int budget;
  final List<String> furnitureTypes;
  final String category;

  const BudgetResultPage({
    super.key,
    required this.budget,
    required this.furnitureTypes,
    required this.category,
  });

  @override
  State<BudgetResultPage> createState() => _BudgetResultPageState();
}

class _BudgetResultPageState extends State<BudgetResultPage> {
  final Map<String, bool> _likes = {};
  final Map<String, bool> _keeps = {};
  final Map<String, int> _keepSetIndexMap = {};
  List<dynamic> recommendedSets = [];
  List<String> _likedList = [];
  String? userId;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getString('user_id');
    if (userId == null) return;

    await _fetchUserFavorites(userId!);
    await _fetchRecommendedSets();
  }

  Future<void> _fetchUserFavorites(String userId) async {
    final url = Uri.parse('http://127.0.0.1:8000/favorite_items/$userId/');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> favorites = jsonDecode(utf8.decode(response.bodyBytes));
        _likedList = favorites
            .where((item) => item['content_type'] == 'new')
            .map<String>((item) => item['furniture_id'].toString())
            .toList();
      } else {
        print('Failed to fetch favorites: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching favorites: $e');
    }
  }

  Future<void> _fetchRecommendedSets() async {
    final url = Uri.parse('http://127.0.0.1:8001/recommend_sets');

    List<Map<String, dynamic>> keptItemsWithSetIndex = _keeps.entries
        .where((entry) => entry.value)
        .map((entry) => {
      'product_id': entry.key,
      'set_index': _keepSetIndexMap[entry.key] ?? 0,
    })
        .toList();

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'budget': widget.budget,
        'furnitureTypes': widget.furnitureTypes,
        'category': widget.category,
        'keptItems': keptItemsWithSetIndex,
      }),
    );

    if (response.statusCode == 200) {
      final List<dynamic> sets = jsonDecode(utf8.decode(response.bodyBytes));
      setState(() {
        recommendedSets = sets;
        for (int i = 0; i < sets.length; i++) {
          final set = sets[i];
          for (var item in set['items']) {
            final id = '${item['product_id']}';
            _likes[id] = _likedList.contains(id);
            _keeps.putIfAbsent(id, () => false);
            if (_keeps[id] == true) {
              _keepSetIndexMap[id] = i;
            }
          }
        }
      });
    } else {
      print('Failed to fetch sets: ${response.statusCode}');
    }
  }

  void _resetItems() {
    _fetchRecommendedSets();
  }

  Future<void> _toggleFavorite(int productId, bool status) async {
    if (userId == null) return;

    final url = Uri.parse('http://127.0.0.1:8000/favorite_items/');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'content_type': 'new',
          'furniture_id': productId,
          'is_favorited': status,
        }),
      );

      if (response.statusCode == 200) {
        final idStr = productId.toString();
        setState(() {
          if (status) {
            _likedList.add(idStr);
            _likes[idStr] = true;
          } else {
            _likedList.remove(idStr);
            _likes[idStr] = false;
          }
        });
      } else {
        print('Failed to toggle favorite: ${response.statusCode}');
      }
    } catch (e) {
      print('Error toggling favorite: $e');
    }
  }

  Widget _buildSet(int setIndex) {
    if (setIndex >= recommendedSets.length) return const SizedBox();
    final set = recommendedSets[setIndex];
    final items = set['items'] as List<dynamic>;
    final totalPrice = set['totalPrice'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Set ${setIndex + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('${_formatCurrency(totalPrice)}원'),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: items.map<Widget>((item) {
              final id = '${item['product_id']}';
              final isLiked = _likes[id] ?? false;
              final isKept = _keeps[id] ?? false;
              final intId = int.tryParse(id);

              return InkWell(
                onTap: () {
                  if (intId != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProductDetailPage(
                          productId: intId,
                          productName: item['name'] ?? '',
                          isLiked: isLiked,
                          onToggleLike: (bool) {},
                        ),
                      ),
                    );
                  }
                },
                onLongPress: () {
                  setState(() {
                    _keeps[id] = !isKept;
                    if (_keeps[id] == true) {
                      _keepSetIndexMap[id] = setIndex;
                    } else {
                      _keepSetIndexMap.remove(id);
                    }
                  });
                },
                child: Container(
                  width: 120,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              border: Border.all(
                                color: isKept ? Colors.amber : Colors.transparent,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              image: item['image_url'] != null
                                  ? DecorationImage(
                                image: NetworkImage(item['image_url']),
                                fit: BoxFit.cover,
                              )
                                  : null,
                            ),
                          ),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: GestureDetector(
                              onTap: () async {
                                final newValue = !isLiked;
                                if (intId == null) return;
                                setState(() {
                                  _likes[id] = newValue;
                                });
                                await _toggleFavorite(intId, newValue);
                              },
                              child: Icon(
                                Icons.favorite,
                                color: isLiked ? Colors.red : Colors.grey,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(item['brand'] ?? '', style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 2),
                      Text(item['name'] ?? '', style: const TextStyle(fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(
                        '${_formatCurrency(item['price'])}원',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        const Divider(thickness: 1, height: 24),
      ],
    );
  }

  String _formatCurrency(int amount) {
    final formatter = NumberFormat('#,###');
    return formatter.format(amount);
  }

  Widget infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 100, child: Text(label, style: const TextStyle(color: Colors.black54))),
        Expanded(child: Text(value)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    bool hasItems = recommendedSets.any((set) => (set['items'] as List).isNotEmpty);

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('AI 예산 내 추천', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Column(
              children: [
                infoRow('예산', '${_formatCurrency(widget.budget)}원'),
                infoRow('가구 종류', widget.furnitureTypes.join(', ')),
                infoRow('카테고리', widget.category),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Colors.black12),
          Expanded(
            child: hasItems
                ? ListView.builder(
              itemCount: recommendedSets.length,
              itemBuilder: (context, index) => _buildSet(index),
            )
                : const Center(child: Text('예산 내 추천 결과가 없습니다.')),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 20, bottom: 24),
            decoration: const BoxDecoration(
              color: Color(0xFFF5E4B8),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: TextButton(
              onPressed: _resetItems,
              child: const Column(
                children: [
                  Padding(
                    padding: EdgeInsets.only(bottom: 3),
                    child: Text('마음에 드는 게 없나요?', style: TextStyle(fontSize: 13, color: Colors.black54)),
                  ),
                  Text('다시 돌리기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.brown)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}