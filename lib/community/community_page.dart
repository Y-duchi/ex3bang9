/// 게시물 페이지( 신고 버튼 있음)

import 'package:flutter/material.dart';
import '../top_bar/top_bar.dart';
import 'post_detail_page.dart';
import 'post_creation_page.dart';
import '../constants.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'co_report_page.dart';

class CommunityPage extends StatefulWidget {
  const CommunityPage({Key? key}) : super(key: key);

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String searchKeyword = '';

  List<Map<String, dynamic>> allPosts = [];
  Set<int> likedPostIds = {};
  String? myUserId;
  String? t_userId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    _initializeUser();
    fetchPostsFromServer();
  }


  Future<void> _initializeUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      t_userId = prefs.getString('user_id');
    });
  }


  Future<void> fetchPostsFromServer() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    myUserId = userId;

    final url = '$baseUrl/community/posts/?user_id=$userId';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final decoded = utf8.decode(response.bodyBytes);
        final List<dynamic> data = jsonDecode(decoded);

        final loadedPosts = data.map((post) => post as Map<String, dynamic>).toList();
        final liked = loadedPosts
            .where((post) => post['is_liked'] == true)
            .map<int>((post) => post['id'] as int)
            .toSet();

        setState(() {
          allPosts = loadedPosts;
          likedPostIds = liked;
        });
      }
    } catch (e) {
      print('불러오기 실패: $e');
    }
  }

  List<Map<String, dynamic>> get filteredPosts {
    List<Map<String, dynamic>> baseList;
    switch (_tabController.index) {
      case 1:
        baseList = List.from(allPosts)
          ..sort((a, b) => (b['likes'] as int).compareTo(a['likes'] as int));
        break;
      case 2:
        baseList = allPosts.where((p) => p['user_id'] == myUserId).toList();
        break;
      default:
        baseList = allPosts;
    }

    if (searchKeyword.isEmpty) return baseList;

    return baseList.where((post) {
      final title = post['title']?.toLowerCase() ?? '';
      final content = post['content']?.toLowerCase() ?? '';
      return title.contains(searchKeyword.toLowerCase()) || content.contains(searchKeyword.toLowerCase());
    }).toList();
  }


  String formatTimeAgo(String? dateTime) {
    if (dateTime == null) return '';
    try {
      final date = DateTime.parse(dateTime);
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inMinutes < 1) return '방금 전';
      if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
      if (diff.inHours < 24) return '${diff.inHours}시간 전';
      return '${diff.inDays}일 전';
    } catch (_) {
      return '';
    }
  }

  Future<void> _toggleLike(int postId) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    if (userId == null) return;

    final isLiked = likedPostIds.contains(postId);
    final url = '$baseUrl/community/posts/$postId/toggle_like/';
    final action = isLiked ? 'unlike' : 'like';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': action, 'user_id': userId}),
      );
      if (response.statusCode == 200) {
        final updatedPost = jsonDecode(utf8.decode(response.bodyBytes));
        final index = allPosts.indexWhere((p) => p['id'] == postId);
        setState(() {
          allPosts[index]['likes'] = updatedPost['likes'];
          isLiked ? likedPostIds.remove(postId) : likedPostIds.add(postId);
        });
      }
    } catch (e) {
      print('좋아요 오류: $e');
    }
  }

  Future<void> _increaseViewCount(int postId) async {
    final url = '$baseUrl/community/posts/$postId/';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        print('조회수 증가 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('조회수 증가 에러: $e');
    }
  }

  void _showMoreOptions(Map<String, dynamic> post) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');

    final isMine = userId != null && post['user_id'] == userId;

    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isMine) ...[
            ListTile(
              title: const Text('수정'),
              onTap: () async {
                Navigator.pop(context);
                final editedPost = await Navigator.push<Map<String, dynamic>>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PostCreationPage(
                      initialTitle: post['title'],
                      initialContent: post['content'],
                      postId: post['id'],
                    ),
                  ),
                );
                if (editedPost != null) fetchPostsFromServer();
              },
            ),
            ListTile(
              title: const Text('삭제'),
              onTap: () {
                Navigator.pop(context);
                _deletePost(post['id']);
              },
            ),
          ] else ...[
            ListTile(
              title: const Text('신고'),
              onTap: () async {
                Navigator.pop(context);

                final prefs = await SharedPreferences.getInstance();
                final reporterEmail = prefs.getString('email'); // ✅ 수정됨

                if (reporterEmail == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('로그인 정보가 없습니다.')),
                  );
                  return;
                }

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CommunityReportPage(
                      postId: post['id'],
                      reporterEmail: reporterEmail,
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _deletePost(int postId) async {
    final url = '$baseUrl/community/posts/$postId/';
    try {
      final response = await http.delete(Uri.parse(url));
      if (response.statusCode == 204) {
        setState(() {
          allPosts.removeWhere((p) => p['id'] == postId);
          likedPostIds.remove(postId);
        });
      }
    } catch (e) {
      print('삭제 오류: $e');
    }
  }

  PreferredSize buildCommunityAppBarBottom() {
    return PreferredSize(
      preferredSize: Size.fromHeight(_tabController.index == 0 ? 96 : 48),
      child: Column(
        children: [
          if (_tabController.index == 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() {
                  searchKeyword = value;
                }),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: '검색어를 입력하세요',
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.black, width: 1.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.black, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                ),
              ),
            ),
          TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF916636),
            unselectedLabelColor: Colors.black,
            indicatorColor: const Color(0xFF916636),
            tabs: const [
              Tab(text: '게시글'),
              Tab(text: '인기글'),
              Tab(text: '내 게시물'),
            ],
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TopBar(
        currentUserId : t_userId ?? 'UNKNOWN',
        showBackButton: false,
      ),
      body: Column(
        children: [
          buildCommunityAppBarBottom(), // ✅ 검색창 + 탭바 들어감

          Expanded(
            child: ListView.builder(
              itemCount: filteredPosts.length,
              itemBuilder: (context, index) {
                final post = filteredPosts[index];
                final postId = post['id'];
                final isLiked = likedPostIds.contains(postId);
                final commentCount = (post['comments'] as List?)?.length ?? 0;
                final imageUrl = (post['images'] != null && post['images'].isNotEmpty)
                    ? post['images'][0]['image_url']
                    : null;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: ListTile(
                    leading: imageUrl != null
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        imageUrl,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                      ),
                    )
                        : null,
                    title: Text(post['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(post['content'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text('작성자: ${post['nickname']} (@${post['user_id']})'),
                        Text('조회수 ${post['views'] ?? 0} · ${formatTimeAgo(post['created_at'])}'),
                      ],
                    ),
                    trailing: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.more_vert, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _showMoreOptions(post),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.comment, size: 18),
                            const SizedBox(width: 4),
                            Text('$commentCount', style: const TextStyle(fontSize: 13)),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _toggleLike(postId),
                              child: Icon(
                                isLiked ? Icons.favorite : Icons.favorite_border,
                                size: 18,
                                color: isLiked ? Colors.red : Colors.black,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text('${post['likes'] ?? 0}', style: const TextStyle(fontSize: 13)),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ],
                    ),
                    onTap: () async {
                      await _increaseViewCount(postId);
                      final updated = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PostDetailPage(
                            postId: postId,
                            title: post['title'],
                            content: post['content'],
                            createdAt: post['created_at'],
                            userId: post['user_id'],
                            nickname: post['nickname'],
                            likeCount: post['likes'] ?? 0,
                            commentCount: commentCount,
                            isInitiallyLiked: isLiked,
                            images: post['images'] ?? [],
                          ),
                        ),
                      );
                      if (updated == true) fetchPostsFromServer();
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.white,
        shape: const CircleBorder(side: BorderSide(color: Colors.black26)),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PostCreationPage()),
        ).then((value) => fetchPostsFromServer()),
        child: const Icon(Icons.add, color: Colors.black, size: 30),
      ),
    );
  }
}
