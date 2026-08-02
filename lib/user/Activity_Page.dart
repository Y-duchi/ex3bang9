import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../constants.dart';
import '../shopping/inquiry_write_page.dart';
import 'review_write_page.dart';

void main() => runApp(
  const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: MyReviewAndInquiryPage(),
  ),
);

class MyReviewAndInquiryPage extends StatefulWidget {
  const MyReviewAndInquiryPage({super.key});

  @override
  State<MyReviewAndInquiryPage> createState() => _MyReviewAndInquiryPageState();
}

class _MyReviewAndInquiryPageState extends State<MyReviewAndInquiryPage> {
  String? userId;
  List<dynamic> reviews = [];
  List<dynamic> inquiries = [];
  Map<int, bool> showActions = {};
  List<dynamic> comments = []; /// 댓글용 추가


  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  ///댓글 불러오기
  Future<void> fetchComments() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');

    if (userId == null) return;

    final response = await http.get(
      Uri.parse('$baseUrl/community/get_my_comments/?user_id=$userId'),
    );

    if (response.statusCode == 200) {
      setState(() {
        comments = jsonDecode(utf8.decode(response.bodyBytes));
      });
    } else {
      print('댓글 목록 불러오기 실패: ${response.statusCode}');
    }
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('user_id');
    if (id != null) {
      setState(() => userId = id);
      await fetchReviews();
      await fetchInquiries();
      await fetchComments();
    }
  }

  Future<void> fetchReviews() async {
    final response = await http.get(Uri.parse('$baseUrl/get_reviews_by_user/?user_id=$userId'));
    if (response.statusCode == 200) {
      setState(() => reviews = jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      debugPrint('내 리뷰 불러오기 실패: ${response.statusCode}');
    }
  }

  Future<void> fetchInquiries() async {
    final response = await http.get(Uri.parse('$baseUrl/get_inquiries/?user_id=$userId'));
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      setState(() => inquiries = data['inquiries']);
    }
  }


  ///리뷰 위젯
  Widget buildReviewItem(BuildContext context, dynamic review) {
    final reviewId = review['new_review_id'];

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/product/detail',
          arguments: {
            'productId': review['product_id'],
            'productName': review['product_name'],
            'isLiked': false,
            'onToggleLike': (bool liked) {
            },
          },
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (review['product_image_url'] != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          review['product_image_url'],
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.image_not_supported),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        review['product_name'] ?? '상품 정보 없음',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                    PopupMenuButton<int>(
                      onSelected: (value) async {
                        if (value == 0) {
                          // 수정
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ReviewWritePage(
                                isEditing: true,
                                existingReview: review,
                                optionId: review['option_id'],
                                productName: review['product_name'],
                                color: review['color'] ?? '',
                                size: review['size'] ?? '',
                                productImageUrl: review['product_image_url'] ?? '',
                              ),
                            ),
                          ).then((_) => fetchReviews());
                        } else if (value == 1) {
                          // 삭제
                          final response = await http.delete(
                            Uri.parse('$baseUrl/delete_new_review/$reviewId/'),
                            headers: {'Content-Type': 'application/json'},
                            body: jsonEncode({'user_id': userId}),
                          );
                          if (response.statusCode == 200) {
                            await fetchReviews();
                          }
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 0, child: Text('수정')),
                        PopupMenuItem(value: 1, child: Text('삭제')),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(review['created_at'] ?? '', style: const TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 4),
                Row(
                  children: List.generate(5, (index) {
                    return Icon(
                      index < (review['rating'] ?? 0).toDouble()
                          ? Icons.star
                          : Icons.star_border,
                      color: Colors.amber,
                      size: 16,
                    );
                  }),
                ),
                const SizedBox(height: 4),
                Text(review['content'] ?? '리뷰 내용 없음', style: const TextStyle(fontSize: 12)),
                if (review['review_images'] != null && review['review_images'].isNotEmpty)
                  SizedBox(
                    height: 200,
                    child: PageView.builder(
                      itemCount: review['review_images'].length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              review['review_images'][index],
                              fit: BoxFit.cover,
                              width: double.infinity,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 8),
                const Divider(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  ///문의 위젯
  Widget buildInquiryItem(BuildContext context, dynamic inquiry) {
    final inquiryId = inquiry['inquiry_id'];

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/product/detail',
          arguments: {
            'productId': inquiry['product_id'],
            'productName': inquiry['product_name'],
            'isLiked': false,
            'onToggleLike': (bool liked) {
            },
          },
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 상품 이미지
                    if (inquiry['product_image_url'] != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          inquiry['product_image_url'],
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.image_not_supported),
                      ),

                    const SizedBox(width: 12),

                    // 텍스트 정보
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            inquiry['product_name'] ?? '상품명 없음',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            inquiry['option'] ?? '옵션 없음',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 4),
                          Text(inquiry['title'] ?? '문의 제목 없음', style: const TextStyle(fontSize: 13)),
                          Text(inquiry['created_at'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),

                    // 수정/삭제
                    PopupMenuButton<int>(
                      onSelected: (value) async {
                        if (value == 0) {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => InquiryWritePage(
                                isEditing: true,
                                existingInquiry: inquiry,
                                productImageUrl: inquiry['product_image_url'] ?? '',
                                productName: inquiry['product_name'] ?? '이름 없음',
                                productPrice: inquiry['product_price'] ?? 0,
                                productId: inquiry['product_id'] ?? 0,
                                option: inquiry['option'] ?? '옵션 없음',
                                existingImages: List<String>.from(inquiry['images'] ?? []),
                              ),
                            ),
                          );
                          if (result == true) await fetchInquiries();
                        } else if (value == 1) {
                          final response = await http.delete(
                            Uri.parse('$baseUrl/delete_inquiry/$inquiryId/'),
                            headers: {'Content-Type': 'application/json'},
                            body: jsonEncode({'inquiry_id': inquiryId}),
                          );
                          if (response.statusCode == 200) await fetchInquiries();
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 0, child: Text('수정')),
                        PopupMenuItem(value: 1, child: Text('삭제')),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  ///댓글 위젯
  Widget buildCommentItem(dynamic comment) {
    return CommentCard(comment: comment);
  }


  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 1,
          title: const Text('나의 활동'),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          bottom: const TabBar(
            labelColor: Color(0xFFD7763D),
            unselectedLabelColor: Colors.black,
            indicatorColor: Color(0xFFD7763D),
            tabs: [
              Tab(text: '작성한 리뷰'),
              Tab(text: '작성한 문의글'),
              Tab(text: '작성한 댓글'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: reviews.length,
              itemBuilder: (context, index) => buildReviewItem(context, reviews[index]),
            ),
            ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: inquiries.length,
              itemBuilder: (context, index) => buildInquiryItem(context, inquiries[index]),
            ),
            ListView.builder(
              itemCount: comments.length,
              itemBuilder: (context, index) => buildCommentItem(comments[index]),
            ),
          ],
        ),
      ),
    );
  }
}

/// 댓글 가져오기
class CommentCard extends StatefulWidget {
  final Map<String, dynamic> comment;

  const CommentCard({super.key, required this.comment});

  @override
  State<CommentCard> createState() => _CommentCardState();
}

class _CommentCardState extends State<CommentCard> {
  bool isLiked = false;

  @override
  Widget build(BuildContext context) {
    final comment = widget.comment;

    final String commentDate = comment['comment_date'] ?? '';
    final String postTitle = comment['post_title'] ?? '제목 없음';
    final String postDate = comment['post_date'] ?? '';
    final int viewCount = comment['view_count'] ?? 0;
    final int commentCount = comment['comment_count'] ?? 0;
    final int likeCount = comment['like_count'] ?? 0;
    final String content = comment['content'] ?? '';
    final String? imageUrl = comment['post_image_url'];


    ///댓글 카드
    return GestureDetector(
      onTap: () async {
        final postId = comment['post_id'] as int;

        // postId로 게시글 상세 조회
        final detailResponse = await http.get(
          Uri.parse('$baseUrl/community/get_post_detail/?post_id=$postId'),
        );

        if (detailResponse.statusCode != 200) {
          print('⚠️ 포스트 상세 가져오기 실패: ${detailResponse.statusCode}');
          return;
        }

        final detailData = jsonDecode(utf8.decode(detailResponse.bodyBytes)) as Map<String, dynamic>;

        Navigator.pushNamed(
          context,
          '/community/post_detail_page',
          arguments: {
            'postId': detailData['id'],
            'title': detailData['title'],
            'content': detailData['content'],
            'createdAt': detailData['created_at'],
            'userId': detailData['user_id'],
            'nickname': detailData['nickname'],
            'profileImageUrl': detailData['profile_image_url'], // 추가: 프로필 이미지 URL
            'likeCount': detailData['likes'],
            'commentCount': detailData['comments'].length,
            'isInitiallyLiked': detailData['is_liked'] ?? false,
            'images': detailData['images'] as List<dynamic>,
          },
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(commentDate, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black12),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// 상단 제목 + 썸네일
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// 제목/날짜/조회수
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(postTitle, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            Text(postDate, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                            Text('조회수 $viewCount', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      /// 이미지 + 아이콘
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                            ),
                            child: imageUrl != null && imageUrl.isNotEmpty
                                ? Image.network(imageUrl, fit: BoxFit.cover)
                                : const Icon(Icons.image, size: 28, color: Colors.white70),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.chat_bubble_outline, size: 14),
                              const SizedBox(width: 4),
                              Text('$commentCount', style: const TextStyle(fontSize: 12)),
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    isLiked = !isLiked;
                                  });
                                },
                                child: Icon(
                                  isLiked ? Icons.favorite : Icons.favorite_border,
                                  size: 14,
                                  color: isLiked ? Colors.redAccent : null,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text('$likeCount', style: const TextStyle(fontSize: 12)),
                              const SizedBox(width: 12),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  /// 내가 쓴 댓글
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('내가 쓴 댓글', style: TextStyle(fontSize: 12)),
                            Text(content, style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}