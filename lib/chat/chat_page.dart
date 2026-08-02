import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import '../constants.dart';
import 'dart:convert';

class ChatPage extends StatefulWidget {
  final String currentUserId;
  final String targetUserId;
  final String chatId;
  final String targetNickname;
  final int? postId;

  const ChatPage({
    super.key,
    required this.currentUserId,
    required this.targetUserId,
    required this.chatId,
    required this.targetNickname,
    this.postId,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late DatabaseReference _chatRef;
  final TextEditingController _messageController = TextEditingController();

  String usedStatus = '';
  String usedTitle = '';
  String usedPrice = '';
  String usedNickname = '';
  String usedUserId = '';
  String? usedImageUrl = '';

  @override
  void initState() {
    super.initState();
    _chatRef = FirebaseDatabase.instance.ref('chats/${widget.chatId}/messages');

    fetchUsedChatInfo(widget.postId);

    markLastMessageAsRead();

  }

  void markLastMessageAsRead() async {
    final messagesRef = FirebaseDatabase.instance.ref('chats/${widget.chatId}/messages');
    final snapshot = await messagesRef.get();

    if (snapshot.exists && snapshot.value is Map) {
      final rawMessages = Map<String, dynamic>.from(snapshot.value as Map);
      String? lastKey;
      int latestTime = 0;

      rawMessages.forEach((key, value) {
        final msg = Map<String, dynamic>.from(value);
        final timestamp = msg['timestamp'];
        if (timestamp != null && timestamp is int && timestamp > latestTime) {
          lastKey = key;
          latestTime = timestamp;
        }
      });

      if (lastKey != null) {
        final msgRef = messagesRef.child(lastKey!);
        final readBySnap = await msgRef.child('readBy').get();
        final readByMap = Map<String, dynamic>.from(readBySnap.value as Map? ?? {});
        readByMap[widget.currentUserId] = true;
        await msgRef.update({'readBy': readByMap});
      }

      // 그리고 lastMessage도 읽음 처리
      final lastMsgRef = FirebaseDatabase.instance.ref('chats/${widget.chatId}/lastMessage');
      final lastSnapshot = await lastMsgRef.get();

      if (lastSnapshot.exists && lastSnapshot.value is Map) {
        final lastMessage = Map<String, dynamic>.from(lastSnapshot.value as Map);
        final updatedReadBy = Map<String, dynamic>.from(lastMessage['readBy'] ?? {});
        updatedReadBy[widget.currentUserId] = true;

        await lastMsgRef.update({'readBy': updatedReadBy});
      }
    }
  }

  Future<void> fetchUsedChatInfo(int? postId) async {
    if (postId == null) return;

    try {
      final response = await http.get(Uri.parse('$baseUrl/get_used_furniture_chat_info/?post_id=$postId'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          usedStatus = data['status'];
          usedTitle = data['title'];
          usedPrice = data['price'];
          usedNickname = data['nickname'];
          usedUserId = data['user_id'];
          usedImageUrl = data['image_url'];
        });
      }
    } catch (_) {}
  }

  String _formatTimestamp(dynamic timestamp) {
    try {
      final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final messageData = {
      'sender': widget.currentUserId,
      'message': text,
      'timestamp': ServerValue.timestamp,
      'readBy': {
        widget.currentUserId: true,
        widget.targetUserId: false,
      },
    };

    _chatRef.push().set(messageData);
    await FirebaseDatabase.instance.ref('chats/${widget.chatId}/lastMessage').set(messageData);
    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context, true),
        ),
        title: Text(
          '${widget.targetNickname} (${widget.targetUserId})',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          if (usedTitle.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.1))),
              ),
              child: Row(
                children: [
                  usedImageUrl != null && usedImageUrl!.isNotEmpty
                      ? Image.network('$baseUrl/media/$usedImageUrl', width: 60, height: 60, fit: BoxFit.cover)
                      : Container(width: 60, height: 60, color: const Color(0xFFD9D9D9)),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('[$usedStatus] $usedTitle', style: const TextStyle(fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(usedPrice, style: const TextStyle(fontSize: 13)),
                    ],
                  )
                ],
              ),
            ),
          Expanded(
            child: StreamBuilder<DatabaseEvent>(
              stream: _chatRef.onValue,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('에러 발생: ${snapshot.error}'));
                }

                final raw = snapshot.data?.snapshot.value;
                if (raw == null || raw is! Map) {
                  return const Center(child: Text('아직 대화가 없습니다.'));
                }

                final messages = (raw as Map).entries.map((e) {
                  final msg = e.value as Map;
                  return {
                    'sender': msg['sender'] ?? '',
                    'message': msg['message'] ?? '',
                    'timestamp': msg['timestamp'] ?? 0,
                  };
                }).toList()
                  ..sort((a, b) => (a['timestamp'] as int).compareTo(b['timestamp'] as int));

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final m = messages[index];
                    final isMe = m['sender'] == widget.currentUserId;

                    return Column(
                      crossAxisAlignment:
                      isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            crossAxisAlignment:
                            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                constraints: const BoxConstraints(maxWidth: 250),
                                decoration: BoxDecoration(
                                  color: isMe ? const Color(0xFF916636) : Colors.white,
                                  border: Border.all(color: Colors.black26),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(15),
                                    bottomLeft: Radius.circular(15),
                                    bottomRight: Radius.circular(15),
                                  ),
                                ),
                                child: Text(
                                  m["message"],
                                  style: TextStyle(color: isMe ? Colors.white : Colors.black),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatTimestamp(m["timestamp"]),
                                style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.5)),
                              ),
                            ],
                          ),
                        )
                      ],
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: const Color(0xFF916636),
            child: Row(
              children: [
                const Text("+", style: TextStyle(color: Colors.white, fontSize: 30)),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 35,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: '메시지를 입력하세요',
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendMessage,
                  child: const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}