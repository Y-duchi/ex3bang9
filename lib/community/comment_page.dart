import 'comment_report_page.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import 'co_report_page.dart';

class CommentPage extends StatefulWidget {
  final int postId;
  final VoidCallback? onCommentAdded;

  const CommentPage({
    super.key,
    required this.postId,
    this.onCommentAdded,
  });

  @override
  State<CommentPage> createState() => _CommentPageState();
}

class _CommentPageState extends State<CommentPage> {
  final TextEditingController _replyController = TextEditingController();
  final FocusNode _replyFocusNode = FocusNode();
  List<dynamic> comments = [];
  bool isLoading = true;
  String? myUserId;
  String? reporterEmail; // ✅ 신고자 이메일

  @override
  void initState() {
    super.initState();
    fetchComments();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      myUserId = prefs.getString('user_id');
      reporterEmail = prefs.getString('email');
    });
  }

  Future<void> fetchComments() async {
    final url = '$baseUrl/community/posts/${widget.postId}/comments/';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final decoded = utf8.decode(response.bodyBytes);
        final List<dynamic> data = json.decode(decoded);
        setState(() {
          comments = data;
          isLoading = false;
        });
      } else {
        print('댓글 불러오기 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('댓글 불러오기 에러: $e');
    }
  }

  Future<void> _addComment() async {
    final content = _replyController.text.trim();
    if (content.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final nickname = prefs.getString('nickname') ?? '방꾸석유저';
    final userId = prefs.getString('user_id') ?? 'anonymous';

    final url = '$baseUrl/community/comments/create/';
    final body = {
      'post': widget.postId,
      'nickname': nickname,
      'user_id': userId,
      'content': content,
    };

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 201) {
      _replyController.clear();
      await fetchComments();
      widget.onCommentAdded?.call();
    } else {
      print('댓글 작성 실패: ${response.statusCode}');
    }
  }

  Future<void> _updateComment(int commentId, String oldContent) async {
    TextEditingController controller = TextEditingController(text: oldContent);

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('댓글 수정'),
        content: TextField(
          controller: controller,
          maxLines: null,
          decoration: const InputDecoration(
            hintText: '수정할 내용을 입력하세요',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(
            onPressed: () async {
              final newContent = controller.text.trim();
              if (newContent.isNotEmpty) {
                final url = '$baseUrl/community/comments/$commentId/update/';
                final response = await http.put(
                  Uri.parse(url),
                  headers: {'Content-Type': 'application/json; charset=utf-8'},
                  body: jsonEncode({'content': newContent}),
                );
                if (response.statusCode == 200) {
                  Navigator.pop(context);
                  await fetchComments();
                } else {
                  print('댓글 수정 실패: ${response.statusCode}');
                }
              }
            },
            child: const Text('수정'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteComment(int commentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('댓글 삭제'),
        content: const Text('정말 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
        ],
      ),
    );

    if (confirm == true) {
      final url = '$baseUrl/community/comments/$commentId/delete/';
      final response = await http.delete(Uri.parse(url));
      if (response.statusCode == 204) {
        await fetchComments();
      } else {
        print('댓글 삭제 실패: ${response.statusCode}');
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final total = comments.length;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text('댓글 페이지 ($total)'),
        titleTextStyle: const TextStyle(color: Colors.black, fontSize: 18),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: comments.length,
              itemBuilder: (context, index) {
                final comment = comments[index];
                final commentUserId = comment['user'];
                final commentId = comment['id'];
                final commentContent = comment['content'];

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.fromLTRB(20, 6, 12, 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFEDEDED)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              comment['nickname'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == '수정') {
                                _updateComment(commentId, commentContent);
                              } else if (value == '삭제') {
                                _deleteComment(commentId);
                              } else if (value == '신고') {
                                if (reporterEmail == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('로그인 정보가 없습니다.')),
                                  );
                                  return;
                                }

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CommentReportPage(
                                      commentId: commentId,
                                      reporterEmail: reporterEmail!,
                                    ),
                                  ),
                                );
                              }
                            },
                            itemBuilder: (_) {
                              if (commentUserId == myUserId) {
                                return const [
                                  PopupMenuItem(value: '수정', child: Text('수정')),
                                  PopupMenuItem(value: '삭제', child: Text('삭제')),
                                ];
                              } else {
                                return const [
                                  PopupMenuItem(value: '신고', child: Text('신고')),
                                ];
                              }
                            },
                            icon: const Icon(Icons.more_vert, size: 18),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(commentContent ?? '', style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 6),
                      Text(
                        formatTimeAgo(comment['created_at'] ?? ''),
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _replyController,
                      focusNode: _replyFocusNode,
                      decoration: const InputDecoration(
                        hintText: '댓글을 입력하세요...',
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _addComment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF916636),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: const Text('등록'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}