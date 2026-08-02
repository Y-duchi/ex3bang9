import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../chat/chat_page.dart';
import '../models/favorite_helper.dart';
import '../top_bar/top_bar.dart';
import 'report_page.dart';
import '../constants.dart';
import '../models/used_furniture_model.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

class DonateDetailPage extends StatefulWidget {
  final int postId;
  final bool isLiked;
  final Function(bool) onToggleLike;

  const DonateDetailPage({
    super.key,
    required this.postId,
    required this.isLiked,
    required this.onToggleLike,
  });

  @override
  State<DonateDetailPage> createState() => _DonateDetailPageState();
}

class _DonateDetailPageState extends State<DonateDetailPage> {
  final PageController _pageController = PageController();
  int currentPage = 0;
  int likeCount = 0;
  int viewCount=0;
  bool didLikeChange = false;
  late bool isLiked;
  String? userId;
  String? profileImageUrl; // 작성자 프로필 이미지 URL

  UsedFurniture? detailData;

  @override
  void initState() {
    super.initState();
    isLiked = widget.isLiked;
    loadUserId();
    fetchLikeCount(widget.postId, 'used').then((count) {
      setState(() {
        likeCount = count;
      });
    });
    fetchUsedDetail();
  }

  Future<void> loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userId = prefs.getString('user_id');
    });
  }

  String getTimeAgo(DateTime postDateTime) {
    final currentTime = DateTime.now();
    final difference = currentTime.difference(postDateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}일 전';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}시간 전';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}분 전';
    } else {
      return '방금 전';
    }
  }

  Future<void> fetchUsedDetail() async {
    final url = Uri.parse('$baseUrl/used_furniture/${widget.postId}/');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(utf8.decode(response.bodyBytes));
      final usedData = UsedFurniture.fromJson(jsonData);

      setState(() {
        detailData = usedData;
        viewCount = usedData.views ?? 0;
      });

      // 작성자 프로필 이미지 요청
      if (usedData.userId != null) {
        await fetchUserProfileImage(usedData.userId!);
      }
    } else {
      print('상세 정보 불러오기 실패');
    }
  }

  Future<void> fetchUserProfileImage(String userId) async {
    final url = Uri.parse('$baseUrl/get_user_info/');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      setState(() {
        profileImageUrl = data['profile_image'];
      });
    } else {
      print('프로필 이미지 요청 실패: ${response.statusCode}');
    }
  }

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF916636);

    if (detailData == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, {
          'postId': widget.postId,
          'isLiked': isLiked,
          'views': viewCount,
        });
        return false;
      },
      child: Scaffold(
        appBar: TopBar(
          currentUserId: userId ?? 'UNKNOWN',
          showBackButton: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              if (detailData!.imageUrls.isNotEmpty)
                Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: detailData!.imageUrls.length,
                        onPageChanged: (index) => setState(() => currentPage = index),
                        itemBuilder: (context, index) {
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                '$baseUrl/media/${detailData?.imageUrls[index]}',
                                fit: BoxFit.cover,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(detailData!.imageUrls.length, (index) {
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: currentPage == index ? Colors.black : Colors.grey,
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 4),
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
                title: Text(detailData?.nickname ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(detailData?.address ?? ''),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text(detailData?.title ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      '${detailData?.category ?? '카테고리 없음'} / ${getTimeAgo(DateTime.parse(detailData!.createdAt))}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      constraints: const BoxConstraints(minHeight: 100),
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      color: Colors.grey[200],
                      child: Text(detailData?.content ?? '', style: const TextStyle(fontSize: 14)),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text('조회수 $viewCount', style: TextStyle(color: Colors.grey, fontSize: 14)),
                        const SizedBox(width: 16),
                        Text('좋아요수 $likeCount', style: const TextStyle(color: Colors.grey, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('거래 희망 장소', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(detailData?.detailAddress ?? '', style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 12),
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
                              markerId: const MarkerId('selected-location'),
                              position: LatLng(detailData!.latitude, detailData!.longitude),
                            ),
                          },
                          zoomControlsEnabled: false,
                          myLocationButtonEnabled: false,
                          scrollGesturesEnabled: true,
                          zoomGesturesEnabled: true,
                          rotateGesturesEnabled: false,
                          tiltGesturesEnabled: false,
                          gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                            Factory<OneSequenceGestureRecognizer>(
                                  () => EagerGestureRecognizer(),
                            ),
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        if (detailData == null) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReportPage(postId: widget.postId),
                          ),
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
        bottomNavigationBar: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Colors.black12)),
            color: Colors.white,
          ),
          child: Row(
            children: [
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
                        didLikeChange = true;
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
                  Text('$likeCount', style: const TextStyle(fontSize: 12)),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("나눔", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      detailData?.isDirectTrade == true ? '직거래 가능' : '직거래 불가능',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  if (userId != null && detailData?.userId != null) {
                    final sorted = [userId!, detailData!.userId]..sort();
                    final chatId = '${sorted[0]}_${sorted[1]}';

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatPage(
                          currentUserId: userId!,
                          targetUserId: detailData!.userId,
                          chatId: chatId,
                          targetNickname: detailData!.nickname ?? '아무개',
                          postId: widget.postId,
                        ),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: activeColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  "채팅하기",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}