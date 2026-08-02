import 'dart:convert';
import '../constants.dart';
import '../top_bar/top_bar.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_database/firebase_database.dart';
import 'chat_page.dart';

class ChatUserSelectPage extends StatefulWidget {
  final String currentUserId;
  const ChatUserSelectPage({super.key, required this.currentUserId});

  @override
  State<ChatUserSelectPage> createState() => _ChatUserSelectPageState();
}

class _ChatUserSelectPageState extends State<ChatUserSelectPage> {
  late Future<List<Map<String, dynamic>>> _chatUsersFuture;

  @override
  void initState() {
    super.initState();
    _chatUsersFuture = fetchRecentChats();
  }

  String generateChatId(String userA, String userB) {
    final sorted = [userA, userB]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  String formatTimestamp(dynamic timestamp) {
    try {
      final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) return '방금 전';
      if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
      if (diff.inHours < 24) return '${diff.inHours}시간 전';
      if (diff.inDays < 7) return '${diff.inDays}일 전';
      return '${dt.month}/${dt.day}';
    } catch (e) {
      return '';
    }
  }

  Future<List<Map<String, dynamic>>> fetchRecentChats() async {
    final currentUserId = widget.currentUserId;
    final chatsRef = FirebaseDatabase.instance.ref('chats');
    final snapshot = await chatsRef.get();

    List<Map<String, dynamic>> result = [];

    for (final chat in snapshot.children) {
      final chatId = chat.key!;
      if (!chatId.contains(currentUserId)) continue;

      final ids = chatId.split('_');
      if (!ids.contains(currentUserId)) continue;

      final otherUserId = ids.first == currentUserId ? ids.last : ids.first;

      final lastMessageSnapshot = await chatsRef.child('$chatId/lastMessage').get();
      if (!lastMessageSnapshot.exists) continue;

      final msgData = lastMessageSnapshot.value as Map?;
      if (msgData == null) continue;

      final readBy = (msgData['readBy'] as Map?) ?? {};
      final isRead = readBy[currentUserId] == true; //읽음확인

      final userInfo = await fetchUserInfo(otherUserId);
      final nickname = userInfo['nickname'];
      final profileImage = userInfo['profile_image'];

      result.add({
        'user_id': otherUserId,
        'nickname': nickname,
        'profile_image': profileImage,
        'lastMessage': msgData['message'] ?? '',
        'timestamp': msgData['timestamp'] ?? 0,
        'chatId': chatId,
        'isRead': isRead,
      });
    }

    return result;
  }

  Future<Map<String, String>> fetchUserInfo(String userId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/get_user_info/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return {
        'nickname': data['nickname'] ?? '이름 없음',
        'profile_image': data['profile_image'] ?? '',
      };
    } else {
      return {
        'nickname': '이름 없음',
        'profile_image': '',
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TopBar(
        currentUserId: widget.currentUserId,
        showBackButton: true,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _chatUsersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('에러: ${snapshot.error}'));
          }

          final chatUsers = snapshot.data!;
          if (chatUsers.isEmpty) {
            return const Center(child: Text('메시지가 없습니다.'));
          }

          return ListView.separated(
            itemCount: chatUsers.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final user = chatUsers[index];
              final userId = user['user_id'];
              final nickname = user['nickname'] ?? '이름 없음';
              final lastMessage = user['lastMessage'] ?? '';
              final chatId = user['chatId'];
              final isRead = user['isRead'] == true;
              final timestamp = user['timestamp'];

              return ListTile(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatPage(
                        currentUserId: widget.currentUserId,
                        targetUserId: userId,
                        targetNickname: nickname,
                        chatId: chatId,
                      ),
                    ),
                  ).then((value) {
                    if (value == true) {
                      setState(() {
                        _chatUsersFuture = fetchRecentChats(); // 다시 불러옴
                      });
                    }
                  });
                },
                onLongPress: () { //채팅창 나가기
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('채팅 삭제'),
                      content: const Text('이 채팅방에서 나가시겠습니까?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('취소'),
                        ),
                        TextButton(
                          onPressed: () async {
                            await FirebaseDatabase.instance.ref('chats/$chatId').remove();
                            Navigator.pop(context);

                            // 삭제 후 목록 새로고침
                            setState(() {
                              _chatUsersFuture = fetchRecentChats();
                            });
                          },
                          child: const Text('삭제', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                },
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey.shade300,
                  backgroundImage: (user['profile_image'] != null && user['profile_image'].toString().isNotEmpty)
                      ? NetworkImage(user['profile_image'])
                      : null,
                  child: (user['profile_image'] == null || user['profile_image'].toString().isEmpty)
                      ? const Icon(Icons.person, color: Colors.white)
                      : null,
                ),
                title: Text(
                  nickname,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    lastMessage,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                trailing: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      formatTimestamp(timestamp),
                      style: const TextStyle(fontSize: 10, color: Color(0xFF444444)),
                    ),
                    const SizedBox(height: 4),
                    if (!isRead)
                      const CircleAvatar(
                        radius: 4,
                        backgroundColor: Color(0xFF1DFF00),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}