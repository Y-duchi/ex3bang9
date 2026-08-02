import 'package:bang9_test/shopping/search_result_page.dart';

import '../shopping/budget_filter_page.dart';
import '../shopping/popular_furniture.dart';
import '../shopping/sale_furniture.dart';
import '../shopping/trendy_furniture.dart';
import '../top_bar/top_bar.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/favorite_helper.dart';
import 'new_furniture.dart';
import 'product_detail.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants.dart';
import 'package:intl/intl.dart';

class ShoppingPage extends StatefulWidget {
  const ShoppingPage({super.key});

  @override
  State<ShoppingPage> createState() => _ShoppingPageState();
}

class _ShoppingPageState extends State<ShoppingPage> {
  final formatter = NumberFormat('#,###');


  // --- 카테고리 & 스타일 데이터 ---
  final categories = [
    '조명', '쇼파', '책상', '의자', '침대',
    '옷장', '선반', '식탁', '화장대', '잡화',
  ];
  final categoryIcons = [
    Icons.light_mode,
    Icons.weekend,
    Icons.table_bar,
    Icons.chair_alt,
    Icons.bed,
    Icons.checkroom,
    Icons.view_module,
    Icons.dining,
    Icons.bathroom,
    Icons.dashboard_customize,
  ];
  final List<String> filters = ['전체', '러블리', '모던', '우든', '레트로'];

  // --- 사용자 선택 상태 ---
  String selectedTab = '쇼핑';
  int? selectedCategoryIndex;
  String selectedFilter = '전체';
  List<bool> liked = [];

  // --- API 데이터 ---
  List furnitureList = [];
  List popularList = [];
  List trendyList = [];
  // List saleList = [];
  List newList = [];
  List<bool> popularLiked = [];
  List<bool> trendyLiked = [];
  // List<bool> saleLiked = [];
  List<bool> newLiked = [];

  Map<int, bool> likedMap = {};

  final TextEditingController _searchController = TextEditingController();


  @override
  void initState() {
    super.initState();
    fetchFurniture().then((_) => fetchFavoriteStatus());
    fetchPopularFurniture();
    fetchTrendyFurniture();
  }

  /// 전체 가구 목록 호출 (최신순만 여기서 처리)
  Future<void> fetchFurniture() async {
    final url = Uri.parse('$baseUrl/furniture_list/');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final all = decoded['furniture'] as List;

      furnitureList = all;
      likedMap = {
        for (var item in all) item['furniture_id']: false,
      };

      // ✅ 최신순 정렬 (created_at 기준)
      final latest = List<Map<String, dynamic>>.from(all);
      latest.sort((a, b) {
        final aDate = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(2000);
        final bDate = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(2000);
        return bDate.compareTo(aDate);
      });

      newList = latest.take(5).toList();
      newLiked = List.filled(newList.length, false);

      setState(() {});
    } else {
      debugPrint('가구 불러오기 실패: ${response.statusCode}');
    }
  }

  /// 인기순: 백엔드에서 정확한 좋아요 수 기준으로 정렬된 리스트 받아오기
  Future<void> fetchPopularFurniture() async {
    final url = Uri.parse('$baseUrl/popular_furniture_list/');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final list = decoded['furniture'] as List;

      setState(() {
        popularList = list.take(5).toList();  // 홈에서는 5개 미리보기
        popularLiked = List.filled(popularList.length, false);
      });
    } else {
      debugPrint('인기 가구 불러오기 실패: ${response.statusCode}');
    }
  }

  /// 유행가구 5개 잘라오기
  Future<void> fetchTrendyFurniture() async {
    final url = Uri.parse('$baseUrl/trendy_furniture_list/');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final list = decoded['furniture'] as List;

      setState(() {
        trendyList = list.take(5).toList();  // 홈에서는 5개 미리보기
        trendyLiked = List.filled(trendyList.length, false);
      });
    } else {
      debugPrint('유행 가구 불러오기 실패: ${response.statusCode}');
    }
  }

  /// 좋아요 상태 체크
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

      // --- 전체 목록에 대해 liked 상태 세팅
      final favoriteIds = favorites.map((fav) => fav['product_id']).toSet();

      setState(() {
        liked = furnitureList.map((item) =>
            favoriteIds.contains(item['furniture_id'])
        ).toList();

        popularLiked = popularList.map((item) =>
            favoriteIds.contains(item['furniture_id'])
        ).toList();

        trendyLiked = trendyList.map((item) =>
            favoriteIds.contains(item['furniture_id'])
        ).toList();


        newLiked = newList.map((item) =>
            favoriteIds.contains(item['furniture_id'])
        ).toList();
      });
    }
  }

  // 검색페이지 이동
  void _performSearch() {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SearchResultPage(searchQuery: query),
        ),
      );
    }
  }


  void _navigateToSearchPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SearchResultPage(searchQuery: _searchController.text.trim())),
    );
  }



  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF916636);

    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final prefs = snapshot.data!;
        final userId = prefs.getString('user_id') ?? 'UNKNOWN';

        return Scaffold(
          appBar: TopBar(
            currentUserId: userId,
            showBackButton: false,
          ),
          body: ListView(
            children: [
              // 검색창
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: GestureDetector(
                  onTap: () {
                    _navigateToSearchPage();
                  },
                  child: AbsorbPointer(
                    child: SizedBox(
                      height: 50,
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: '검색어를 입력하세요',
                          prefixIcon: IconButton(
                            icon: const Icon(Icons.search),
                            onPressed: () {
                              _performSearch();
                            },
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onSubmitted: (value) {
                          _performSearch();
                        },
                        textInputAction: TextInputAction.search,
                      ),
                    ),
                  ),
                ),
              ),

              // 탭 바
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  children: [
                    _buildTabButton('쇼핑', activeColor),
                    SizedBox(width: 12),
                    _buildTabButton('이달의 가구', activeColor, width: 60),
                    Spacer(),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const BudgetFilterPage(),
                          ),
                        );
                      },
                      icon: Icon(Icons.auto_awesome, size: 16),
                      label: Text(
                        'AI 예산 추천',
                        style: TextStyle(fontSize: 11),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: activeColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        minimumSize: Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ),

              // 탭 선택 결과에 따른 분기
              selectedTab == '이달의 가구'
                  ? SizedBox()
                  : SizedBox(height: 6),

              if (selectedTab == '쇼핑') ...[
                _buildCategoryIcons(),
                SizedBox(height: 16),
                _buildStyleFilters(),
                SizedBox(height: 16),
                _buildProductGrid(),
              ] else ...[
                _buildMonthlySection("인기 가구", popularList, popularLiked),
                _buildMonthlySection("유행 가구", trendyList, trendyLiked),
                //_buildMonthlySection("세일 가구", saleList, saleLiked),
                _buildMonthlySection("최신 가구", newList, newLiked),
                SizedBox(height: 10),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabButton(String label, Color activeColor, {double width = 30}) {
    final isSelected = selectedTab == label;
    return GestureDetector(
      onTap: () => setState(() => selectedTab = label),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isSelected ? activeColor : Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Container(height: 2,
              width: width,
              color: isSelected ? activeColor : Colors.transparent),
        ],
      ),
    );
  }

  // --- 카테고리 아이콘 그리기 & 탭 클릭 시 카테고리만 필터 ---
  Widget _buildCategoryIcons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.75,
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final isSelected = selectedCategoryIndex == index;
          return GestureDetector(
            onTap: () =>
                setState(() {
                  // 카테고리 탭: 선택 시 해당 index, 해제 시 null
                  selectedCategoryIndex = isSelected ? null : index;
                  // 스타일 필터는 모두 해제
                  selectedFilter = '전체';
                }),
            child: Column(
              children: [
                Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFEBD19C) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.brown.shade300),
                  ),
                  child: Center(
                    child: Icon(categoryIcons[index], size: 28,
                        color: Colors.brown.shade700),
                  ),
                ),
                const SizedBox(height: 6),
                Text(categories[index], style: const TextStyle(fontSize: 12)),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- 스타일 칩 그리기 & 탭 클릭 시 스타일만 필터 ---
  Widget _buildStyleFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: filters.map((style) {
          final isSelected = selectedFilter == style;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(style),
              selected: isSelected,
              selectedColor: const Color(0xFF916636),
              labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.black),
              onSelected: (_) =>
                  setState(() {
                    // 스타일 탭: 선택 시 해당 스타일, 해제 시 '전체'
                    selectedFilter = isSelected ? '전체' : style;
                    // 카테고리 필터는 모두 해제
                    selectedCategoryIndex = null;
                  }),
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- 필터링 로직: 카테고리 OR 스타일 OR 전체 ---
  // 수정된 _buildProductGrid 함수 부분
  Widget _buildProductGrid() {
    List filteredList;
    if (selectedCategoryIndex != null) {
      // 카테고리만 필터
      filteredList = furnitureList.where((item) =>
      item['category'] == categories[selectedCategoryIndex!]
      ).toList();
    } else if (selectedFilter != '전체') {
      // 스타일만 필터
      filteredList = furnitureList.where((item) =>
      item['style'] == selectedFilter
      ).toList();
    } else {
      // 전체
      filteredList = furnitureList;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: filteredList.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.75,
        ),
        itemBuilder: (context, index) {
          final item = filteredList[index];
          final originalIndex = furnitureList.indexWhere(
                  (e) => e["furniture_id"] == item["furniture_id"]);

          final isLiked = (originalIndex != -1 && originalIndex < liked.length)
              ? liked[originalIndex] : false;

          return GestureDetector(
            onTap: () {
              if (originalIndex == -1) return;

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ProductDetailPage(
                        productId: item['furniture_id'],
                        productName: item['name'],
                        isLiked: isLiked,
                        onToggleLike: (newStatus) {
                          if (originalIndex == -1) return;
                          setState(() {
                            liked[originalIndex] = newStatus;
                          });
                        },
                      ),
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(alignment: Alignment.topRight, children: [
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
                      if (item['furniture_id'] == null || originalIndex == -1)
                        return;

                      setState(() {
                        liked[originalIndex] = !liked[originalIndex];
                      });

                      await toggleFavorite(
                        productId: item['furniture_id'],
                        contentType: 'new',
                        isFavorited: liked[originalIndex],
                      );
                    },
                  ),
                ]),
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
    );
  }


  // --- 이달의 가구 섹션(쇼핑 탭 외) ---
  Widget _buildMonthlySection(String title, List list, List<bool> likedList) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton(
                onPressed: () {
                  late Widget targetPage;
                  switch (title) {
                    case '인기 가구':
                      targetPage = const PopularFurniturePage();
                      break;
                    case '유행 가구':
                      targetPage = const TrendyFurniturePage();
                      break;
                    case '세일 가구':
                      targetPage = const SaleFurniturePage();
                      break;
                    case '최신 가구':
                      targetPage = const NewFurniturePage();
                      break;
                    default:
                      targetPage = const PopularFurniturePage();
                  }
                  Navigator.push(
                      context, MaterialPageRoute(builder: (_) => targetPage));
                },
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                child: const Text(
                    "더보기", style: TextStyle(color: Colors.grey, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: list.length,
              itemBuilder: (context, index) {
                final item = list[index];

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ProductDetailPage(
                              productId: item['furniture_id'],
                              productName: item['name'],
                              isLiked: likedList[index],
                              onToggleLike: (newStatus) {
                                setState(() {
                                  likedList[index] = newStatus;
                                });
                              },
                            ),
                      ),
                    );
                  },
                  child: Container(
                    margin: EdgeInsets.only(
                        right: index == list.length - 1 ? 0 : 8),
                    width: 115,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            Container(
                              height: 110,
                              width: 110,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  image: NetworkImage(item['image_url'] ??
                                      'https://via.placeholder.com/150'),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 6,
                              right: 6,
                              child: IconButton(
                                icon: Icon(
                                  likedList[index] ? Icons.favorite : Icons
                                      .favorite_border,
                                  color: likedList[index] ? Colors.red : Colors
                                      .black,
                                ),
                                onPressed: () async {
                                  if (item['furniture_id'] == null) return;

                                  final newStatus = !likedList[index];

                                  setState(() {
                                    likedList[index] = newStatus;
                                  });

                                  await toggleFavorite(
                                    productId: item['furniture_id'],
                                    contentType: 'new',
                                    isFavorited: newStatus,
                                  );

                                  // ✅ 전체 liked 리스트에 반영 (쇼핑페이지 필터링 리스트 기준)
                                  final targetIndex = furnitureList.indexWhere(
                                        (e) => e['furniture_id'] == item['furniture_id'],
                                  );
                                  if (targetIndex != -1 && targetIndex < liked.length) {
                                    setState(() {
                                      liked[targetIndex] = newStatus;
                                    });
                                  }
                                },
                                iconSize: 24,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(item['brand'] ?? '',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey)),
                        const SizedBox(height: 1),
                        Text(
                          item['name'] ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          item['min_price'] != null
                              ? '${formatter.format(item['min_price'])}원'
                              : '가격 정보 없음',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}