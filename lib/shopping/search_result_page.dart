import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../constants.dart';
import '../shopping/shopping.dart';
import '../used/usedT.dart';
import '../community/community_page.dart';
import '../user/User.dart';
import '../shopping/product_detail.dart';
import 'package:flutter/cupertino.dart';

class SearchResultPage extends StatefulWidget {
  final String searchQuery;

  const SearchResultPage({super.key, required this.searchQuery});

  @override
  State<SearchResultPage> createState() => _SearchResultPageState();
}

class _SearchResultPageState extends State<SearchResultPage> {
  late TextEditingController _controller;
  int _currentIndex = 0;
  List<Map<String, dynamic>> furnitureList = [];
  Set<int> favoriteProductIds = {}; // 찜 목록 ID 저장
  String selectedSort = '최신순';

  final List<Widget> _pages = const [
    ShoppingPage(),
    UsedTradePage(),
    CommunityPage(),
    UserPage(),
  ];

  void _onItemTapped(int index) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => _pages[index]),
    );
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.searchQuery);
    initData();
  }

  Future<void> initData() async {
    await fetchUserFavorites();
    await fetchSearchResults(widget.searchQuery);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> fetchUserFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    if (userId == null) return;

    try {
      final response = await http.get(Uri.parse('$baseUrl/favorite_items/$userId'));
      if (response.statusCode == 200) {
        final List<dynamic> favorites = jsonDecode(response.body);
        setState(() {
          favoriteProductIds = favorites
              .where((item) => item['content_type'] == 'new')
              .map<int>((item) => item['furniture_id'] as int)
              .toSet();
        });
      }
    } catch (e) {
      print('Failed to load favorites: $e');
    }
  }

  Future<void> fetchSearchResults(String query, {String sort = ''}) async {
    if (query.isEmpty) {
      setState(() {
        furnitureList = [];
      });
      return;
    }

    try {
      final url = Uri.parse('$baseUrl/search/?query=$query${sort.isNotEmpty ? '&sort=$sort' : ''}');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          furnitureList = data.map<Map<String, dynamic>>((item) {
            final id = item['product_id'] ?? 0;
            return {
              'product_id': id,
              'brand': item['brand'] ?? '',
              'name': item['name'] ?? '',
              'price': item['price'] != null ? '${item['price']}원' : '',
              'liked': favoriteProductIds.contains(id),
              'image_url': item['image_url'] ?? '',
            };
          }).toList();
        });
      } else {
        print('Failed to fetch data: ${response.statusCode}');
        setState(() {
          furnitureList = [];
        });
      }
    } catch (e) {
      print('Error fetching data: $e');
      setState(() {
        furnitureList = [];
      });
    }
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('인기순'),
              onTap: () {
                setState(() => selectedSort = '인기순');
                fetchSearchResults(_controller.text.trim(), sort: 'popular');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('최신순'),
              onTap: () {
                setState(() => selectedSort = '최신순');
                fetchSearchResults(_controller.text.trim(), sort: 'recent');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('가격순'),
              onTap: () {
                setState(() => selectedSort = '가격순');
                fetchSearchResults(_controller.text.trim(), sort: 'price');
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> toggleFavorite(int productId, bool status) async {
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
        'is_favorited': status,
      }),
    );

    setState(() {
      if (status) {
        favoriteProductIds.add(productId);
      } else {
        favoriteProductIds.remove(productId);
      }
    });
  }

  void toggleLike(Map<String, dynamic> item) {
    setState(() {
      item['liked'] = !(item['liked'] ?? false);
    });
    toggleFavorite(item['product_id'], item['liked']);
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim();

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
          titleSpacing: 0,
          title: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: '검색어를 입력하세요',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      _controller.clear();
                      setState(() => furnitureList = []);
                    },
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                  isDense: true,
                  filled: true,
                  fillColor: Colors.grey[200],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (value) async {
                  await fetchUserFavorites(); // 하트 반영을 위해 다시 불러오기
                  await fetchSearchResults(value.trim());
                },
                onChanged: (value) async {
                  await fetchUserFavorites(); // 하트 반영을 위해 다시 불러오기
                  await fetchSearchResults(value.trim());
                },
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text('상품 ${furnitureList.length}개', style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                ElevatedButton(
                  onPressed: _showSortOptions,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    elevation: 0,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.filter_list, size: 16),
                      const SizedBox(width: 4),
                      Text(selectedSort),
                    ],
                  ),
                )
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.6,
              ),
              itemCount: furnitureList.length,
              itemBuilder: (context, index) {
                final item = furnitureList[index];

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductDetailPage(
                          productId: item['product_id'] is int
                              ? item['product_id']
                              : int.tryParse(item['product_id'].toString()) ?? 0,
                          productName: item['name'] ?? '',
                          isLiked: item['liked'] ?? false,
                          onToggleLike: (bool newLikeStatus) {
                            setState(() {
                              item['liked'] = newLikeStatus;
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
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: item['image_url'] != null && item['image_url'].isNotEmpty
                                ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                item['image_url'],
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(Icons.broken_image, size: 50, color: Colors.grey);
                                },
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                          : null,
                                    ),
                                  );
                                },
                              ),
                            )
                                : null,
                          ),
                          IconButton(
                            icon: Icon(
                              item['liked'] ? Icons.favorite : Icons.favorite_border,
                              color: item['liked'] ? Colors.red : Colors.black,
                              size: 18,
                            ),
                            onPressed: () => toggleLike(item),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(item['brand'], style: const TextStyle(fontSize: 12)),
                      Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(item['price']),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: const Color(0xFF916636),
        unselectedItemColor: Colors.black,
        type: BottomNavigationBarType.fixed,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.shopping_bag), label: '쇼핑'),
          BottomNavigationBarItem(icon: Icon(Icons.swap_horiz), label: '중고거래'),
          BottomNavigationBarItem(icon: Icon(Icons.groups), label: '커뮤니티'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '사용자'),
        ],
      ),
    );
  }
}