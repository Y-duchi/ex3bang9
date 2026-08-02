// 게시물 상세 페이지

import 'package:flutter/material.dart';
import 'comment_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PostDetailPage extends StatefulWidget {
  final int postId;
  final String title;
  final String content;
  final String createdAt;
  final String userId;
  final String nickname;
  final int likeCount;
  final int commentCount;
  final bool isInitiallyLiked;
  final List<dynamic> images; // ✅ 수정됨

  const PostDetailPage({
    Key? key,
    required this.postId,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.userId,
    required this.nickname,
    required this.likeCount,
    required this.commentCount,
    required this.isInitiallyLiked,
    required this.images, // ✅ 수정됨
  }) : super(key: key);

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  late bool isLiked;
  late int likeCount;
  late int commentCount;
  late PageController _pageController;
  int _currentImageIndex = 0;
  String? profileImageUrl;

  @override
  void initState() {
    super.initState();
    isLiked = widget.isInitiallyLiked;
    likeCount = widget.likeCount;
    commentCount = widget.commentCount;
    _pageController = PageController();
    fetchAuthorProfileImage();
  }

  String formatTimeAgo(String dateTime) {
    try {
      final created = DateTime.parse(dateTime).toLocal();
      final now = DateTime.now();
      final diff = now.difference(created);

      if (diff.inMinutes < 1) return '방금 전';
      if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
      if (diff.inHours < 24) return '${diff.inHours}시간 전';
      return '${diff.inDays}일 전';
    } catch (_) {
      return '';
    }
  }

  Future<void> _toggleLike() async {
    final url = '$baseUrl/community/posts/${widget.postId}/toggle_like/';
    final action = isLiked ? 'unlike' : 'like';

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');

    if (userId == null) {
      print('로그인 정보 없음');
      return;
    }

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': action,
          'user_id': userId,
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          isLiked = result['is_liked'];
          likeCount = result['likes'];
        });
      } else {
        print('좋아요 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('좋아요 오류: $e');
    }
  }

  Future<void> fetchAuthorProfileImage() async {
    final response = await http.post(
      Uri.parse('$baseUrl/get_user_info/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': widget.userId}), // 게시글 작성자 ID
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      setState(() {
        profileImageUrl = data['profile_image'];
      });
    } else {
      print('작성자 프로필 이미지 조회 실패');
    }
  }


  @override
  Widget build(BuildContext context) {
    final List<String> imageUrls = widget.images
        .where((img) => img['image_url'] != null)
        .map<String>((img) => img['image_url'] as String)
        .toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('내 게시물', style: TextStyle(color: Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context, true),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey.shade300,
                backgroundImage: profileImageUrl != null ? NetworkImage(profileImageUrl!) : null,
                child: profileImageUrl == null
                    ? const Icon(Icons.person, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${widget.nickname} (@${widget.userId})', style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(formatTimeAgo(widget.createdAt), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(widget.content, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 16),

          if (imageUrls.isNotEmpty)
            Column(
              children: [
                SizedBox(
                  height: 250,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: imageUrls.length,
                    onPageChanged: (index) => setState(() => _currentImageIndex = index),
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Image.network(
                          imageUrls[index],
                          fit: BoxFit.contain,
                        ),
                      );
                    },
                  ),
                ),
                if (imageUrls.length > 1)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      imageUrls.length,
                          (index) => Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentImageIndex == index ? Colors.black : Colors.grey,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

          const SizedBox(height: 24),
          Row(
            children: [
              IconButton(
                icon: Icon(
                  isLiked ? Icons.favorite : Icons.favorite_border,
                  color: isLiked ? Colors.red : Colors.grey,
                ),
                onPressed: _toggleLike,
              ),
              Text('좋아요 $likeCount개'),
              const SizedBox(width: 24),
              IconButton(
                icon: const Icon(Icons.comment_outlined),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CommentPage(
                        postId: widget.postId,
                        onCommentAdded: () {
                          setState(() {
                            commentCount += 1;
                          });
                        },
                      ),
                    ),
                  );
                },
              ),
              Text('댓글 $commentCount개'),
            ],
          ),
        ],
      ),
    );
  }
}