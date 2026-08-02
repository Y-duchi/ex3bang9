import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_database/firebase_database.dart';
import '../notification/notification_page.dart';
import '../chat/chat_user_select_page.dart';
import '../cart/cart_page.dart';

class TopBar extends StatefulWidget implements PreferredSizeWidget {
  @override
  final Size preferredSize;
  final String currentUserId;
  final bool showBackButton;

  // 상세 페이지에서 넘겨줄 값
  final int? postId;
  final bool? isLiked;
  final int? updatedViewCount;

  const TopBar({
    Key? key,
    required this.currentUserId,
    this.showBackButton = false,
    this.postId,
    this.isLiked,
    this.updatedViewCount,
  }) : preferredSize = const Size.fromHeight(60.0),
       super(key: key);

  @override
  State<TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<TopBar> {
  bool hasUnreadNotification = false;
  bool hasUnreadMessage = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    fetchUnreadStatus();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) fetchUnreadStatus();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> fetchUnreadStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    if (userId == null) return;

    // 알림
    try {
      final notiRes = await http.get(
        Uri.parse('$baseUrl/get_unread_notification_count/?user_id=$userId'),
      );
      if (notiRes.statusCode == 200) {
        final data = json.decode(notiRes.body);
        setState(() {
          hasUnreadNotification = (data['unread_count'] ?? 0) > 0;
        });
      }
    } catch (e) {
      print("알림 불러오기 오류: $e");
    }

    if (portfolioDemo) return;

    // 채팅
    try {
      final ref = FirebaseDatabase.instance.ref('chats');
      final snapshot = await ref.get();
      bool unreadFound = false;

      for (final chat in snapshot.children) {
        final chatId = chat.key!;
        if (!chatId.contains(userId)) continue;

        final lastMsgSnap = await ref.child('$chatId/lastMessage').get();
        final msgData = lastMsgSnap.value as Map?;
        if (msgData == null) continue;

        final readBy = msgData['readBy'] as Map?;
        final isRead = readBy?[userId] == true;

        if (!isRead) {
          unreadFound = true;
          break;
        }
      }

      setState(() {
        hasUnreadMessage = unreadFound;
      });
    } catch (e) {
      print("채팅 읽음 여부 확인 실패: $e");
    }
  }

  Future<void> markAllNotificationsRead() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    if (userId == null) return;

    try {
      await http.post(
        Uri.parse('$baseUrl/mark_notifications_read/'),
        body: {'user_id': userId},
      );
      setState(() {
        hasUnreadNotification = false;
      });
    } catch (e) {
      print("알림 읽음 처리 오류: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(60.0),
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              widget.showBackButton
                  ? IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios,
                        color: Colors.black,
                      ),
                      onPressed: () {
                        if (widget.postId != null &&
                            widget.isLiked != null &&
                            widget.updatedViewCount != null) {
                          Navigator.pop(context, {
                            'postId': widget.postId!,
                            'isLiked': widget.isLiked!,
                            'updatedViewCount': widget.updatedViewCount!,
                          });
                        } else {
                          Navigator.pop(context);
                        }
                      },
                    )
                  : Image.asset('assets/images/logo.png', height: 50),
              Row(
                children: [
                  // 알림 아이콘
                  Stack(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.notifications_none,
                          color: Colors.black,
                        ),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const NotificationPage(),
                            ),
                          );
                          await markAllNotificationsRead();
                          fetchUnreadStatus();
                        },
                      ),
                      if (hasUnreadNotification)
                        const Positioned(
                          right: 6,
                          top: 6,
                          child: CircleAvatar(
                            radius: 4,
                            backgroundColor: Color(0xFF1DFF00),
                          ),
                        ),
                    ],
                  ),
                  // 채팅 아이콘은 Firebase를 쓰는 non-demo 빌드에서만 노출
                  if (!portfolioDemo)
                    Stack(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.mail_outline,
                            color: Colors.black87,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatUserSelectPage(
                                  currentUserId: widget.currentUserId,
                                ),
                              ),
                            ).then((value) => fetchUnreadStatus());
                          },
                        ),
                        if (hasUnreadMessage)
                          const Positioned(
                            right: 6,
                            top: 6,
                            child: CircleAvatar(
                              radius: 4,
                              backgroundColor: Color(0xFF1DFF00),
                            ),
                          ),
                      ],
                    ),
                  // 장바구니 아이콘
                  IconButton(
                    icon: const Icon(
                      Icons.shopping_cart_outlined,
                      color: Colors.black,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              CartPage(userId: widget.currentUserId),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
