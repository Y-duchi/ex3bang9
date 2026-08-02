// lib/screens/used_trade_page.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

import '../models/used_furniture_model.dart';
import '../models/favorite_helper.dart';
import '../constants.dart';
import '../user/ID_page.dart';
import '../chat/chat_user_select_page.dart';
import '../cart/cart_page.dart';
import '../notification/notification_page.dart';
import 'detail_used.dart';
import 'detail_donate.dart';
import 'sell_form.dart';
import 'report_page.dart';
import 'package:bang9_test/used/region_Filter.dart';

class UsedTradePage extends StatefulWidget {
  const UsedTradePage({Key? key}) : super(key: key);

  @override
  State<UsedTradePage> createState() => _UsedTradePageState();
}

class _UsedTradePageState extends State<UsedTradePage> {
  // ─────────────────── 상태 변수 ───────────────────
  List<UsedFurniture> usedList = [];   // 전체 게시글 데이터
  List<bool> liked = [];               // 게시글별 좋아요 상태
  List<int> likeCounts = [];           // 게시글별 좋아요 개수
  String? t_userId;                    // 현재 로그인된 유저 ID
  String searchQuery = '';

  String selectedSort = '최신순';         // '최신순', '조회수순', '좋아요순'
  String selectedTab = '중고거래';        // '중고거래' vs '나눔페이지'
  int? selectedCategoryIndex;           // 카테고리 필터 인덱스 (null 이면 전체)
  String? selectedProvince;             // 지역(시/도) 필터
  Set<String> selectedDistricts = {};   // 지역(시/군/구) 필터 (여러 개)

  final categories = [
    '조명', '쇼파', '책상', '의자', '침대',
    '옷장', '선반', '식탁', '화장대', '잡화'
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

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
    fetchUsedFurniture().then((_) {
      fetchUsedFavoriteStatus();
      fetchAllUsedLikeCounts();
    });
  }

  Future<void> _loadCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      t_userId = prefs.getString('user_id');
    });
  }

  /// “n일 전, n시간 전, n분 전, 방금 전” 형식
  String getTimeAgo(DateTime postDateTime) {
    final diff = DateTime.now().difference(postDateTime);
    if (diff.inDays > 0) return '${diff.inDays}일 전';
    if (diff.inHours > 0) return '${diff.inHours}시간 전';
    if (diff.inMinutes > 0) return '${diff.inMinutes}분 전';
    return '방금 전';
  }

  /// 서버에서 중고가구 목록(GET) → usedList에 저장
  Future<void> fetchUsedFurniture() async {
    final response = await http.get(Uri.parse('$baseUrl/used_furniture_list/'));
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as List;
      setState(() {
        usedList = data.map((item) => UsedFurniture.fromJson(item)).toList();
        // “목록 길이만큼” liked / likeCounts 초기화
        liked = List.filled(usedList.length, false);
        likeCounts = List.filled(usedList.length, 0);
      });
    } else {
      debugPrint('중고가구 목록 가져오기 실패: ${response.statusCode}');
    }
  }

  /// 현재 유저 기준으로 “어떤 게시글에 좋아요를 눌렀는지” 상태(GET)
  Future<void> fetchUsedFavoriteStatus() async {
    if (t_userId == null) return;
    final response = await http.get(
      Uri.parse('$baseUrl/favorite_items/?user_id=$t_userId&content_type=used'),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final favorites = List<Map<String, dynamic>>.from(data['favorites']);
      setState(() {
        liked = usedList.map((item) {
          return favorites.any((fav) =>
          (fav['post_id'] ?? fav['furniture_id']) == item.postId);
        }).toList();
      });
    } else {
      debugPrint('중고거래 좋아요 상태 불러오기 실패: ${response.statusCode}');
    }
  }

  /// 게시글별 좋아요 개수(GET)
  Future<void> fetchAllUsedLikeCounts() async {
    for (int i = 0; i < usedList.length; i++) {
      final id = usedList[i].postId;
      final response = await http.get(
        Uri.parse('$baseUrl/favorite/count/?furniture_id=$id&content_type=used'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        likeCounts[i] = data['like_count'] ?? 0;
      }
    }
    setState(() {});
  }

  /// 필터(탭/카테고리/지역) + 정렬 적용된 리스트 반환
  List<UsedFurniture> getFilteredList() {
    final filtered = usedList.where((item) {
      final matchesTab = selectedTab == '중고거래'
          ? item.transactionType.trim() == '판매'
          : item.transactionType.trim() == '나눔';

      final matchesCategory = (selectedCategoryIndex == null)
          ? true
          : item.category.trim() == categories[selectedCategoryIndex!];

      final matchesRegion = (selectedProvince == null)
          ? true
          : (selectedDistricts.isEmpty
          ? item.address.contains(selectedProvince!)
          : selectedDistricts.any((gu) => item.address.contains(gu)));
      final matchesSearch = searchQuery.isEmpty
          ? true
          : (item.title.toLowerCase().contains(searchQuery.toLowerCase()) || item.content.toLowerCase().contains(searchQuery.toLowerCase()));

      return matchesTab && matchesCategory && matchesRegion && matchesSearch;
    }).toList();

    if (selectedSort == '최신순') {
      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else if (selectedSort == '조회수순') {
      filtered.sort((a, b) => b.views.compareTo(a.views));
    } else if (selectedSort == '좋아요순') {
      filtered.sort((a, b) {
        final likeA = likeCounts[usedList.indexWhere((x) => x.postId == a.postId)];
        final likeB = likeCounts[usedList.indexWhere((x) => x.postId == b.postId)];
        return likeB.compareTo(likeA);
      });
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF916636);
    final filteredList = getFilteredList();

    return Scaffold(
      // ────────────────────── AppBar ──────────────────────
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        automaticallyImplyLeading: false,
        toolbarHeight: 60.0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 로고
            Image.asset('assets/images/logo.png', height: 50),
            // 알림 / 메시지 / 장바구니 아이콘
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_none, color: Colors.black),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NotificationPage()),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.mail_outline, color: Colors.black),
                  onPressed: () {
                    if (t_userId == null) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatUserSelectPage(currentUserId: t_userId!),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.shopping_cart_outlined, color: Colors.black),
                  onPressed: () {
                    if (t_userId != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => CartPage(userId: t_userId!)),
                      );
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),

      // ────────────────────── Body ──────────────────────
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // 검색창
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SizedBox(
              height: 50,
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    searchQuery = value.trim();
                  });
                },
                decoration: InputDecoration(
                  hintText: '검색어를 입력하세요',
                  prefixIcon: const Icon(Icons.search),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ),

          // 탭 메뉴
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => selectedTab = '중고거래'),
                  child: Column(
                    children: [
                      Text(
                        '중고거래',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: selectedTab == '중고거래' ? activeColor : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 2,
                        width: 60,
                        color: selectedTab == '중고거래' ? activeColor : Colors.transparent,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => setState(() => selectedTab = '나눔페이지'),
                  child: Column(
                    children: [
                      Text(
                        '나눔페이지',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: selectedTab == '나눔페이지' ? activeColor : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 2,
                        width: 60,
                        color: selectedTab == '나눔페이지' ? activeColor : Colors.transparent,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // 카테고리 버튼
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final isSelected = selectedCategoryIndex == index;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (selectedCategoryIndex == index) {
                        selectedCategoryIndex = null;
                      } else {
                        selectedCategoryIndex = index;
                      }
                    });
                  },
                  child: FittedBox(
                    child: Column(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFEBD19C) : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.brown.shade300),
                          ),
                          child: Center(
                            child: Icon(
                              categoryIcons[index],
                              size: 28,
                              color: Colors.brown.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          categories[index],
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // 정렬 & 지역 필터 버튼
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
            child: Row(
              children: [
                PopupMenuButton<String>(
                  onSelected: (value) {
                    setState(() {
                      selectedSort = value;
                    });
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: '최신순', child: Text('최신순')),
                    const PopupMenuItem(value: '조회수순', child: Text('조회수순')),
                    const PopupMenuItem(value: '좋아요순', child: Text('좋아요순')),
                  ],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  offset: const Offset(0, 45),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.filter_list, size: 18, color: Color(0xFF916636)),
                        const SizedBox(width: 4),
                        Text(
                          selectedSort,
                          style: const TextStyle(color: Color(0xFF916636)),
                        ),
                        const Icon(Icons.arrow_drop_down, color: Color(0xFF916636)),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 25),

                TextButton.icon(
                  onPressed: () async {
                    final result = await showDialog<Map<String, dynamic>>(
                      context: context,
                      builder: (context) => const RegionFilterDialog(),
                    );
                    if (result != null) {
                      setState(() {
                        selectedProvince = result['province'];
                        selectedDistricts = Set<String>.from(result['districts']);
                      });
                    }
                  },
                  icon: const Icon(Icons.terrain, color: Color(0xFF916636)),
                  label: const Text("지역 필터링", style: TextStyle(color: Color(0xFF916636))),
                ),
              ],
            ),
          ),

          // 선택된 지역 표시
          if (selectedProvince != null)
            Padding(
              padding: const EdgeInsets.only(left: 16.0, bottom: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Chip(
                    label: Text(
                      selectedDistricts.isEmpty
                          ? selectedProvince!
                          : '$selectedProvince > ${selectedDistricts.join(', ')}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    onDeleted: () {
                      setState(() {
                        selectedProvince = null;
                        selectedDistricts.clear();
                      });
                    },
                  ),
                ],
              ),
            ),

          // ──────────────────────────── 상품/나눔 리스트 ────────────────────────────
          ListView.builder(
            itemCount: filteredList.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              final filteredItem = filteredList[index];

              // 실제 usedList에서 해당 포스트의 인덱스 계산
              final usedIndex = usedList.indexWhere((item) => item.postId == filteredItem.postId);

              // “날짜”/“가격” 변수 정의 (이 부분이 빠져 있으면 컴파일 오류가 납니다)
              final DateTime postDateTime = DateTime.parse(filteredItem.createdAt);
              final String formattedPrice = NumberFormat('#,###').format(filteredItem.price);
              final bool isLikedItem = liked[usedIndex];

              return GestureDetector(
                onTap: () async {
                  // 상세 페이지로 이동 → pop 시 Map 결과를 받는다
                  final result = await Navigator.push<Map<String, dynamic>>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UsedDetailPage(
                        postId: filteredItem.postId,
                        isLiked: liked[usedIndex],
                        onToggleLike: (newStatus) {
                          setState(() {
                            liked[usedIndex] = newStatus;
                          });
                        },
                      ),
                    ),
                  );

                  // pop 결과 로그 (디버깅용)
                  print('▶▶▶ UsedTradePage pop result → $result');

                  if (result != null && result.containsKey('postId')) {
                    final int postId = result['postId'] as int;
                    final bool newLiked = result['isLiked'] as bool;
                    final int updatedViews = result['updatedViewCount'] as int;

                    // usedList에서 해당 postId의 위치(idx)를 다시 계산
                    final int idx = usedList.indexWhere((item) => item.postId == postId);
                    print('▶▶▶ UsedTradePage idx: $idx, postId: $postId, updatedViews: $updatedViews');

                    if (idx != -1) {
                      setState(() {
                        liked[idx] = newLiked;
                        usedList[idx].views = updatedViews;  // **정상적으로 값을 덮어씁니다**
                      });
                    }
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ───────── 썸네일 이미지 ─────────
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.grey[200],
                            ),
                            clipBehavior: Clip.hardEdge,
                            child: filteredItem.imageUrls.isNotEmpty
                                ? Image.network(
                              '$baseUrl/media/${filteredItem.imageUrls.first}',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.broken_image, size: 40),
                            )
                                : const Icon(Icons.image, size: 40),
                          ),

                          const SizedBox(width: 12),

                          // ───────── 제목·가격·작성 시간 ─────────
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  filteredItem.title,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                if (selectedTab == '중고거래') ...[
                                  Text('$formattedPrice원'),
                                  const SizedBox(height: 8),
                                ],
                                Text(getTimeAgo(postDateTime)),
                              ],
                            ),
                          ),

                          // ───────── 신고/좋아요/조회수·좋아요수 ─────────
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.report),
                                    color: Colors.brown,
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ReportPage(postId: filteredItem.postId),
                                        ),
                                      );
                                    },
                                    iconSize: 24,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: Icon(
                                      isLikedItem ? Icons.favorite : Icons.favorite_border,
                                      color: isLikedItem ? Colors.red : Colors.black,
                                    ),
                                    onPressed: () async {
                                      if (usedIndex == -1) return;
                                      final bool newStatus = !liked[usedIndex];
                                      setState(() {
                                        liked[usedIndex] = newStatus;
                                        likeCounts[usedIndex] += newStatus ? 1 : -1;
                                      });
                                      await toggleFavorite(
                                        productId: filteredItem.postId,
                                        contentType: 'used',
                                        isFavorited: newStatus,
                                      );
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 36),
                              Row(
                                children: [
                                  Text(
                                    '조회수 ${filteredItem.views}',
                                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                                  ),
                                  const SizedBox(width: 16),
                                  Text(
                                    '좋아요수 ${likeCounts.length > usedIndex ? likeCounts[usedIndex] : 0}',
                                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),

      // ───────────────────── FloatingActionButton ─────────────────────
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.white,
        shape: const CircleBorder(),
        elevation: 4,
        onPressed: () async {
          final prefs = await SharedPreferences.getInstance();
          final isCertified = prefs.getBool('certified') ?? false;

          if (isCertified) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SellFormPage()),
            );
          } else {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text("2차 인증 필요"),
                content: const Text("중고거래 글 작성은 2차 인증 후 이용하실 수 있습니다."),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => IDPage()),
                      );
                    },
                    child: const Text("인증하러 가기"),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("닫기"),
                  ),
                ],
              ),
            );
          }
        },
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }
}
