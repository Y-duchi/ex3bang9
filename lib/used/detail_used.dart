import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../cart/cart_page.dart';
import '../models/used_furniture_model.dart';
import '../constants.dart';
import '../chat/chat_page.dart';
import '../notification/notification_page.dart';
import '../user/ID_page.dart';
import '../models/favorite_helper.dart';
import 'report_page.dart';

class UsedDetailPage extends StatefulWidget {
  final int postId;
  final bool isLiked;
  final Function(bool) onToggleLike;

  const UsedDetailPage({
    Key? key,
    required this.postId,
    required this.isLiked,
    required this.onToggleLike,
  }) : super(key: key);

  @override
  State<UsedDetailPage> createState() => _UsedDetailPageState();
}

class _UsedDetailPageState extends State<UsedDetailPage> {
  UsedFurniture? detailData;
  bool isLiked = false;
  int likeCount = 0;
  int viewCount = 0;
  String? userId;
  String? profileImageUrl;

  int currentPage = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    // 부모가 넘겨준 isLiked 초기값 적용
    isLiked = widget.isLiked;
    _loadUserId();
    _fetchLikeCount();
    fetchUsedDetail();
  }

  /// SharedPreferences에서 user_id를 읽어 옵니다.
  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userId = prefs.getString('user_id');
    });
  }

  /// 서버로부터 현재 좋아요 개수를 받아 옵니다.
  Future<void> _fetchLikeCount() async {
    final count = await fetchLikeCount(widget.postId, 'used');
    setState(() {
      likeCount = count;
    });
  }

  /// 서버에서 게시글 상세 정보를 가져오고, viewCount에는 서버에서 이미 +1된 값을 저장합니다.
  Future<void> fetchUsedDetail() async {
    final response = await http.get(
      Uri.parse('$baseUrl/used_furniture/${widget.postId}/'),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      setState(() {
        detailData = UsedFurniture.fromJson(data);
        viewCount = detailData!.views; // 서버에서 +1된 조회수
      });

      if (detailData!.userId != null) {
        await fetchUserProfileImage(detailData!.userId!);
      }
    } else {
      debugPrint('상세 정보 가져오기 실패: ${response.statusCode}');
    }
  }

  /// “n일 전 / n시간 전 / n분 전” 형식으로 변환
  String getTimeAgo(DateTime postDateTime) {
    final diff = DateTime.now().difference(postDateTime);
    if (diff.inDays > 0) return '${diff.inDays}일 전';
    if (diff.inHours > 0) return '${diff.inHours}시간 전';
    if (diff.inMinutes > 0) return '${diff.inMinutes}분 전';
    return '방금 전';
  }

  Future<void> fetchUserProfileImage(String userId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/get_user_info/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      setState(() {
        profileImageUrl = data['profile_image'];
      });
    } else {
      print('프로필 이미지 불러오기 실패: ${response.statusCode}');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 아직 detailData가 null이라면 로딩 인디케이터만 보여 줍니다.
    if (detailData == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        // 시스템 뒤로가기 버튼(안드로이드 물리 뒤로가기 등)도 동일하게 Map을 반환
        print('UsedDetailPage before pop → viewCount: $viewCount');
        Navigator.pop(context, {
          'postId': widget.postId,
          'isLiked': isLiked,
          'updatedViewCount': viewCount,
        });
        return false; // 이미 pop했으므로 Navigator에 추가 pop 금지
      },
      child: Scaffold(
        // ────────────────────────────────────────────────
        // 커스텀 AppBar: 뒤로가기 화살표를 누르면 Map 반환
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
            onPressed: () {
              // AppBar 뒤로가기 누를 때 Map 반환
              Navigator.pop(context, {
                'postId': widget.postId,
                'isLiked': isLiked,
                'updatedViewCount': viewCount,
              });
            },
          ),
          title: const Text(
            '중고거래 상세',
            style: TextStyle(color: Colors.black),
          ),
          actions: [
            // 오른쪽 알림 버튼
            IconButton(
              icon: const Icon(Icons.notifications_none, color: Colors.black),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationPage()),
                );
              },
            ),
            // 오른쪽 채팅 버튼
            IconButton(
              icon: const Icon(Icons.mail, color: Colors.black),
              onPressed: () {
                if (userId == null || detailData!.userId == null) return;
                // 두 유저 ID를 정렬해서 채팅방 ID 생성
                final pair = [userId!, detailData!.userId!]..sort();
                final chatId = '${pair[0]}_${pair[1]}';
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatPage(
                      currentUserId: userId!,
                      targetUserId: detailData!.userId!,
                      chatId: chatId,
                      targetNickname: detailData!.nickname ?? '아무개',
                      postId: widget.postId,
                    ),
                  ),
                );
              },
            ),
            // 오른쪽 장바구니 버튼
            IconButton(
              icon: const Icon(Icons.shopping_cart, color: Colors.black),
              onPressed: () {
                if (userId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CartPage(userId: userId!),
                    ),
                  );
                }
              },
            ),
          ],
        ),

        // ────────────────────────────────────────────────
        // 본문 영역: 이미지, 작성자 정보, 내용, 지도 등
        body: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),

              // 이미지 슬라이더가 있을 때
              if (detailData!.imageUrls.isNotEmpty)
                Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: detailData!.imageUrls.length,
                        onPageChanged: (p) => setState(() => currentPage = p),
                        itemBuilder: (context, i) {
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                            clipBehavior: Clip.hardEdge,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Image.network(
                              '$baseUrl/media/${detailData!.imageUrls[i]}',
                              fit: BoxFit.cover,
                            ),
                          );
                        },
                      ),
                    ),
                    // 페이지 인디케이터
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          detailData!.imageUrls.length,
                              (i) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: currentPage == i ? Colors.black : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 4),

              // 게시자 정보 (닉네임 + 주소)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.grey.shade300,
                  backgroundImage: profileImageUrl != null ? NetworkImage(profileImageUrl!) : null,
                  child: profileImageUrl == null
                      ? const Icon(Icons.person, color: Colors.white)
                      : null,
                ),
                title: Text(
                  detailData!.nickname ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(detailData!.address ?? ''),
              ),

              const Divider(),

              // 제목, 카테고리, 작성 시간, 내용 표시
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    // 제목
                    Text(
                      detailData!.title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    // 카테고리 / 작성 시간
                    Text(
                      '${detailData!.category} / ${getTimeAgo(DateTime.parse(detailData!.createdAt))}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    // 내용 박스
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(minHeight: 100),
                      padding: const EdgeInsets.all(12),
                      color: Colors.grey[200],
                      child: Text(
                        detailData!.content,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 조회수 / 좋아요수
                    Row(
                      children: [
                        Text(
                          '조회수 $viewCount',
                          style: const TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          '좋아요수 $likeCount',
                          style: const TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // 거래 희망 장소 라벨 + 상세 주소 텍스트
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '거래 희망 장소',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          detailData!.detailAddress ?? '',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // 지도 위젯
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey[200],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: LatLng(detailData!.latitude, detailData!.longitude),
                            zoom: 15,
                          ),
                          markers: {
                            Marker(
                              markerId: const MarkerId('loc'),
                              position: LatLng(detailData!.latitude, detailData!.longitude),
                            ),
                          },
                          zoomControlsEnabled: false,
                          myLocationButtonEnabled: false,
                          scrollGesturesEnabled: true,
                          zoomGesturesEnabled: true,
                          rotateGesturesEnabled: false,
                          tiltGesturesEnabled: false,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 신고하기 텍스트버튼
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ReportPage(postId: widget.postId)),
                        );
                      },
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      child: const Text(
                        '이 게시글 신고하기',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ────────────────────────────────────────────────
        // 하단 영역: 좋아요 버튼, 좋아요 수, 가격/직거래 여부, 채팅하기 버튼
        bottomNavigationBar: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Colors.black12)),
            color: Colors.white,
          ),
          child: Row(
            children: [
              // 좋아요 버튼 + 좋아요 수
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? Colors.red : Colors.grey,
                    ),
                    onPressed: () async {
                      final newStatus = !isLiked;
                      setState(() {
                        isLiked = newStatus;
                      });
                      widget.onToggleLike(newStatus);
                      await toggleFavorite(
                        productId: widget.postId,
                        contentType: 'used',
                        isFavorited: newStatus,
                      );
                      final newCount = await fetchLikeCount(widget.postId, 'used');
                      setState(() {
                        likeCount = newCount;
                      });
                    },
                  ),
                  Text(
                    '$likeCount',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),

              const SizedBox(width: 16),

              // 가격 / 직거래 여부 표시
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${detailData!.price}원',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detailData!.isDirectTrade ? '직거래 가능' : '직거래 불가능',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),

              // 채팅하기 버튼
              ElevatedButton(
                onPressed: () {
                  if (userId != null && detailData!.userId != null) {
                    final pair = [userId!, detailData!.userId!]..sort();
                    final chatId = '${pair[0]}_${pair[1]}';
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatPage(
                          currentUserId: userId!,
                          targetUserId: detailData!.userId!,
                          chatId: chatId,
                          targetNickname: detailData!.nickname ?? '아무개',
                          postId: widget.postId,
                        ),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF916636), // 예시: 갈색
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  "채팅하기",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}