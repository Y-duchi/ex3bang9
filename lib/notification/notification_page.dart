import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../constants.dart';
import '../used/detail_used.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  List<Map<String, dynamic>> notifications = [];


  @override
  void initState() {
    super.initState();
    fetchNotifications();
  }

  Future<void> fetchNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');

      if (userId == null) {
        print("유저 ID 없음");
        return;
      }

      final response = await http.get(
        Uri.parse('$baseUrl/get_notification/?user_id=$userId'),
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(utf8.decode(response.bodyBytes));
        if (decoded is List) {
          final List<Map<String, dynamic>> casted = decoded
              .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
              .toList();

          setState(() {
            notifications = casted;
          });
        } else {
          print("예상치 못한 데이터 형식: $decoded");
        }
      } else {
        print("알림 목록 불러오기 실패: ${response.statusCode}");
      }
    } catch (e) {
      print("에러 발생: $e");
    }
  }


  Future<void> handleNotificationTap(String url, Map<String, dynamic> noti) async {
    print(noti);

    if (url.startsWith('/community/posts/')) {
      final id = int.tryParse(url.split('/').lastWhere((part) => part.isNotEmpty));
      if (id != null) {
        final response = await http.get(Uri.parse('$baseUrl/community/posts/$id/'));
        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          Navigator.pushNamed(
            context,
            '/community/post_detail_page',
            arguments: {
              'postId': id,
              'title': data['title'] ?? '',
              'content': data['content'] ?? '',
              'createdAt': data['created_at'] ?? '',
              'userId': data['user_id'] ?? '',
              'nickname': data['nickname'] ?? '',
              'likeCount': data['like_count'] ?? 0,
              'commentCount': data['comment_count'] ?? 0,
              'isInitiallyLiked': data['is_liked'] ?? false,
              'images': data['images'] ?? [],
            },
          );
        }
      }
    } else if (url.startsWith('/used/posts/')) {
      final segments = url.split('/').where((e) => e.isNotEmpty).toList();
      final id = int.tryParse(segments.last);
      if (id != null) {
        Navigator.pushNamed(
          context,
          '/used/detail_used',
          arguments: {
            'postId': id,
            'isLiked': false, // 초기값만 던짐
            'onToggleLike': (bool liked) {
              print("알림에서 토글 누름: $liked");
            },
          },
        );
      }
    } else if (url.startsWith('/order/detail')) {
      Navigator.pushNamed(context, '/user/Order_List');
    }
  }

  IconData getIconForType(String type) {
    switch (type) {
      case 'delivery_start':
        return Icons.local_shipping;
      case 'comment':
        return Icons.comment;
      case 'like':
        return Icons.favorite;
      case 'review_reminder':
        return Icons.rate_review;
      case 'delivery_complete':
        return Icons.check_circle;
      case 'inquiry_answer':
        return Icons.help_outline;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('알림', style: TextStyle(color: Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: notifications.isEmpty
          ? const Center(
        child: Text(
          '받은 알림이 없어요.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      )
          : ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: notifications.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final noti = notifications[index];
          final icon = getIconForType(noti['type'] ?? '');
          final url = noti['url'] ?? '';

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => handleNotificationTap(url, noti),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(4), // 살짝 눌림 영역 확보
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF0F0F0),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          icon,
                          size: 20,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            noti['title'] ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            noti['message'] ?? '',
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            noti['created_at'] ?? '',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF888888),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
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