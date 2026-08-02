import 'payment_page.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/favorite_helper.dart';
import '../models/furniture_options_model.dart';
import '../top_bar/top_bar.dart';
import 'ar_page.dart';
import '../constants.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'inquiry_write_page.dart';

// 상품명 → 모델 경로 매핑
const Map<String, String> _modelMap = {
  //침대
  '원목 침대 프레임': 'models.scnassets/bed/bed1.dae',
  '미드 센추리 우든 침대': 'models.scnassets/bed/bed2.dae',
  '호텔침대 프레임오크 침대 KK 민자형 (매트 별도)': 'models.scnassets/bed/bed11.dae',
  '저상향 레트로 우든 침대': 'models.scnassets/bed/bed3.dae',
  '키즈 살롱 귀여운 핑크 어린이 침대': 'models.scnassets/bed/bed4.dae',
  //의자
  '온슬로우 암체어': 'models.scnassets/chair/chair1.dae',
  '고무나무 원목의자 윈저의자 카페의자': 'models.scnassets/chair/chair2.dae',
  '감성공간 원목 의자': 'models.scnassets/chair/chair3.dae',
  '로킹 의자': 'models.scnassets/chair/chair4.dae',
  //옷장
  'Kitchen hanger': 'models.scnassets/closet/closet1.dae',
  '원목 선반 행거 2단 옷걸이 스탠딩 튼튼한 우드 행거': 'models.scnassets/closet/closet2.dae',
  '나무 원목 더블 옷장': 'models.scnassets/closet/closet3.dae',
  '에브리 스탠드 우드가지 옷걸이 베이지': 'models.scnassets/closet/closet4.dae',
  //쇼파
  '리빙 벨라지오 3인용 고정형 소파': 'models.scnassets/couch/couch1.dae',
  '셰이커스 발수코팅 패브릭 3인소파': 'models.scnassets/couch/couch2.dae',
  '다이닝룸 벤치 캐주얼 리듬 페트롤': 'models.scnassets/couch/couch3.dae',
  '허스크 소파': 'models.scnassets/couch/couch4.dae',
  //책상
  '나무 사무실 컴퓨터 책상': 'models.scnassets/desk/desk1.dae',
  '나무 테이블 디자인 컴퓨터 책상': 'models.scnassets/desk/desk2.dae',
  '천연무늬목 정원형 확장테이블': 'models.scnassets/desk/desk3.dae',
  '러블리 화이트 책상': 'models.scnassets/desk/desk4.dae',
  //화장대
  '투명하고 고급스러운 프레임리스 화장대': 'models.scnassets/dresser/dresser1.dae',
  '바이헤이데이 원목 화장대': 'models.scnassets/dresser/dresser2.dae',
  '북유럽 콘솔화장대': 'models.scnassets/dresser/dresser3.dae',
  '공주화장대 대리석 상판 벨벳 화장대풀세트': 'models.scnassets/dresser/dresser4.dae',
  //조명
  '팬시 볼 펜던트': 'models.scnassets/lamp/lamp1.dae',
  '우드함 펜던트': 'models.scnassets/lamp/lamp2.dae',
  '뇌드마스트 이동식 탁상 스탠드 건전지형 충전형 무드등 조명': 'models.scnassets/lamp/lamp3.dae',
  '러블리 6등': 'models.scnassets/lamp/lamp4.dae',
  //선반
  '코른셰 선반유닛 4단선반': 'models.scnassets/shelf/shelf1.dae',
  '이지보 툴프리 800 선반 4단': 'models.scnassets/shelf/shelf2.dae',
  '느릅나무 20칸 머그 장식장': 'models.scnassets/shelf/shelf3.dae',
  '벽걸이선반 디자인 포인트 옷걸이 후크 벽선반': 'models.scnassets/shelf/shelf4.dae',
  //식탁
  '퓨어 화이트 원목 좌탁 테이블': 'models.scnassets/table/table1.dae',
  '아이언 다리 로우 테이블・데스크용': 'models.scnassets/table/table2.dae',
  '내츄럴상판블랙테이블': 'models.scnassets/table/table3.dae',
  '대리석 티 테이블 프레임': 'models.scnassets/table/table4.dae',
  //잡화
  '스텐럭 IGT 1 유닛 메쉬트레이': 'models.scnassets/other/other1.dae',
  '시그니처 전신거울': 'models.scnassets/other/other2.dae',
  '레인보우 체크 클래식 소프트 러그': 'models.scnassets/other/other3.dae',
  '미니 다육이 토분 세트': 'models.scnassets/other/other4.dae',
};

class ProductDetailPage extends StatefulWidget {
  final int productId;
  final String productName;
  final bool isLiked;
  final Function(bool) onToggleLike;

  const ProductDetailPage({
    super.key,
    required this.productId,
    required this.productName,
    required this.isLiked,
    required this.onToggleLike,
  });

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  final PageController _pageController = PageController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _reviewKey = GlobalKey();
  final GlobalKey _inquiryKey = GlobalKey();

  int currentPage = 0;
  String selectedTab = '상품 정보';
  String? userId;

  Map<String, dynamic>? furnitureData;
  bool isLoading = true;
  late bool isLiked;
  bool showAllInquiries = false;
  bool showAllReviews = false;

  List<Map<String, dynamic>> get displayedInquiries {
    if (showAllInquiries || inquiries.length <= 3) return inquiries;
    return inquiries.take(3).toList();
  }

  // ✅ 상태 변수로 변경
  String selectedColor = '색상 선택';
  String selectedSize = '사이즈 선택';
  int quantity = 1;
  int likeCount = 0;

  final formatter = NumberFormat('#,###');

  List<Map<String, dynamic>> reviews = []; // 리뷰 목록
  List<Map<String, dynamic>> inquiries = []; // 문의 목록

  // 리뷰 가져오기 (productId 기준)
  Future<void> fetchReviews() async {
    try {
      final url = Uri.parse(
        '$baseUrl/get_reviews_by_product?product_id=${widget.productId}',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          reviews = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      print('리뷰 불러오기 실패: $e');
    }
  }

  // 문의 가져오기 (productId 기준)
  Future<void> fetchInquiries() async {
    try {
      final url = Uri.parse(
        '$baseUrl/get_inquiries_by_product?product_id=${widget.productId}',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          inquiries = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      print('문의 불러오기 실패: $e');
    }
  }

  // 가구 상세 정보 API
  Future<void> fetchFurnitureDetail() async {
    var url = Uri.parse('$baseUrl/furniture_detail/${widget.productId}/');
    var response = await http.get(url);

    if (response.statusCode == 200) {
      var data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data['success']) {
        setState(() {
          furnitureData = data['furniture'];
          isLoading = false;
        });
      }
    } else {
      print('가져오기 실패: ${response.statusCode}');
    }
  }

  // 옵션 정보 API
  Future<List<FurnitureOptions>> fetchFurnitureOptions(int productId) async {
    final url = Uri.parse('$baseUrl/get_furniture_options/${widget.productId}');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((json) => FurnitureOptions.fromJson(json)).toList();
    } else {
      throw Exception('옵션 정보를 불러오지 못했습니다.');
    }
  }

  List<FurnitureOptions> options = [];
  List<String> colorList = ['색상 선택'];
  List<String> sizeList = ['사이즈 선택'];

  void loadOptions() async {
    options = await fetchFurnitureOptions(widget.productId);
    setState(() {
      colorList = [
        '색상 선택',
        ...{for (var o in options) o.color},
      ];
      sizeList = [
        '사이즈 선택',
        ...{for (var o in options) o.size},
      ];
    });
  }

  Future<void> loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userId = prefs.getString('user_id');
    });
  } //상단바 유저정보

  // 옵션에 맞는 가격 불러오기
  int? _getSelectedOptionPrice() {
    for (var option in options) {
      if (option.color == selectedColor && option.size == selectedSize) {
        return option.price;
      }
    }
    return null;
  }

  //장바구니 추가 연동
  Future<void> addToCart(String userId, String optionId, int quantity) async {
    final url = Uri.parse('$baseUrl/add_to_cart/');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'option_id': optionId,
        'quantity': quantity,
      }),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('장바구니에 담았습니다')));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('장바구니 담기에 실패했습니다.')));
    }
  }

  @override
  void initState() {
    super.initState();
    isLiked = widget.isLiked;
    fetchFurnitureDetail();
    loadOptions();
    fetchLikeCount(widget.productId, 'new').then((count) {
      setState(() {
        likeCount = count;
      });
    });
    loadUserId();
    fetchReviews();
    fetchInquiries();
  }

  void _scrollToSection(GlobalKey key) {
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  // 리뷰 출력 위젯
  Widget _buildReviewSection() {
    return Padding(
      key: _reviewKey,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '리뷰',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),

          if (reviews.isEmpty)
            const Text('리뷰가 아직 없습니다.', style: TextStyle(color: Colors.grey))
          else
            Column(
              children: reviews.map((review) {
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.all(12),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.white,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 닉네임
                      Text(
                        review['nickname'] ?? '익명',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 4),

                      //리뷰 내용
                      Text(
                        review['content'] ?? '',
                        style: const TextStyle(fontSize: 14, height: 1.4),
                      ),
                      const SizedBox(height: 4),

                      //평점 + 작성일
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '⭐ ${review['rating'] ?? 0}점',
                            style: const TextStyle(color: Colors.orange),
                          ),
                          Text(
                            review['created_at'] ?? '',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // 문의 출력 위젯
  Widget _buildInquirySection() {
    List<Map<String, dynamic>> displayedInquiries =
        showAllInquiries || inquiries.length <= 3
        ? inquiries
        : inquiries.take(3).toList();

    return Padding(
      key: _inquiryKey,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '문의',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              TextButton(
                onPressed: () {
                  final inquiry = {
                    'product_image_url': furnitureData!['image_url'],
                    'product_name': furnitureData!['name'],
                    'product_price': furnitureData!['min_price'],
                    'product_id': widget.productId,
                    'option': '$selectedColor / $selectedSize',
                    'images': [],
                  };
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) {
                        // slider_images 첫 번째 항목이 대표 이미지라 가정
                        final firstSliderImage =
                            (furnitureData!['slider_images'] as List).isNotEmpty
                            ? furnitureData!['slider_images'][0] as String
                            : '';

                        final inquiry = {
                          'product_image_url': firstSliderImage, // ← 여기 수정
                          'product_name': furnitureData!['name'],
                          'product_price': furnitureData!['min_price'],
                          'product_id': widget.productId,
                          'option': '$selectedColor / $selectedSize',
                          'images': [],
                        };

                        return InquiryWritePage(
                          isEditing: false,
                          existingInquiry: inquiry,
                          productImageUrl: inquiry['product_image_url'] ?? '',
                          productName: inquiry['product_name'] ?? '이름 없음',
                          productPrice: inquiry['product_price'] ?? 0,
                          productId: inquiry['product_id'] ?? 0,
                          option: inquiry['option'] ?? '옵션 없음',
                          existingImages: List<String>.from(
                            inquiry['images'] ?? [],
                          ),
                        );
                      },
                    ),
                  );
                },
                child: const Text(
                  '문의 작성',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (inquiries.isEmpty)
            const Text('문의 내역이 없습니다.', style: TextStyle(color: Colors.grey))
          else
            Column(
              children: [
                ...displayedInquiries.map(
                  (inquiry) => Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.all(12),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.white,
                    ),
                    child:
                        inquiry['is_private'].toString() == 'true' ||
                            inquiry['is_private'].toString() == '1'
                        ? const Text(
                            '비밀글입니다.',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ///여기추가
                                inquiry['nickname'] ?? '익명',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                inquiry['title'] ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                inquiry['content'] ?? '',
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (inquiry['is_answered'] == true &&
                                  inquiry['answer'] != null)
                                Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF6F6F6),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '답변: ${inquiry['answer']}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ),

                if (!showAllInquiries && inquiries.length > 3)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          showAllInquiries = true;
                        });
                      },
                      child: const Text(
                        '더보기',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  // 옵션 정보 (색상 + 사이즈)
  void _showPurchaseOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            int? selectedOptionPrice = _getSelectedOptionPrice();
            int deliveryFee = furnitureData!['delivery_fee'];
            bool optionsSelected =
                selectedColor != '색상 선택' &&
                selectedSize != '사이즈 선택' &&
                selectedOptionPrice != null;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: '색상'),
                      value: selectedColor,
                      items: colorList
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: (val) {
                        setModalState(() {
                          selectedColor = val!;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: '사이즈'),
                      value: selectedSize,
                      items: sizeList
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: (val) {
                        setModalState(() {
                          selectedSize = val!;
                        });
                      },
                    ),

                    if (optionsSelected) ...[
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFF2DFC2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('$selectedColor / $selectedSize'),
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove),
                                      onPressed: () {
                                        if (quantity > 1) {
                                          setModalState(() {});
                                          setState(() => quantity--);
                                        }
                                      },
                                    ),
                                    Text(
                                      quantity.toString(),
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add),
                                      onPressed: () {
                                        setModalState(() {});
                                        setState(() => quantity++);
                                      },
                                    ),
                                  ],
                                ),
                                Text(
                                  '${formatter.format(selectedOptionPrice * quantity)}원',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('총 금액'),
                          Text(
                            '${formatter.format(selectedOptionPrice * quantity)}원',
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('배송비'),
                          Text('${formatter.format(deliveryFee)}원'),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '결제 금액',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${formatter.format(selectedOptionPrice * quantity + deliveryFee)}원',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final option = options.firstWhere(
                                (o) =>
                                    o.color == selectedColor &&
                                    o.size == selectedSize,
                              );
                              await addToCart(
                                userId!,
                                option.optionId,
                                quantity,
                              );
                              Navigator.pop(context);
                            },
                            child: const Text('장바구니'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: optionsSelected
                                ? () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => PaymentPage(
                                          productId: widget.productId,
                                          productName: widget.productName,
                                          quantity: quantity,
                                          totalPrice:
                                              selectedOptionPrice * quantity +
                                              deliveryFee,
                                          selectedColor: selectedColor,
                                          selectedSize: selectedSize,
                                          imageUrl:
                                              furnitureData!['slider_images'][0],
                                        ),
                                      ),
                                    );
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF916636),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey[300],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(50),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            child: const Text('바로구매'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, {
          'productId': widget.productId,
          'isLiked': isLiked,
        });
        return false; // 뒤로가기 직접 처리했으니 true 아님
      },
      child: Scaffold(
        appBar: TopBar(currentUserId: userId ?? '', showBackButton: true),

        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                children: [
                  SingleChildScrollView(
                    controller: _scrollController,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),

                        // 이미지 슬라이더 + AR 버튼
                        Stack(
                          children: [
                            SizedBox(
                              height: 300,
                              child: PageView.builder(
                                controller: _pageController,
                                itemCount:
                                    furnitureData!['slider_images'].length,
                                onPageChanged: (i) =>
                                    setState(() => currentPage = i),
                                itemBuilder: (_, i) => Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    image: DecorationImage(
                                      image: NetworkImage(
                                        furnitureData!['slider_images'][i],
                                      ),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
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
                                  furnitureData!['slider_images'].length,
                                  (i) => Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 2,
                                    ),
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: currentPage == i
                                          ? Colors.black
                                          : Colors.grey,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // AR 버튼
                            Positioned(
                              bottom: 12,
                              right: 12,
                              child: GestureDetector(
                                onTap: () {
                                  final name = furnitureData!['name'] as String;
                                  final modelPath = _modelMap[name];

                                  if (modelPath == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          '이 상품은 아직 AR 모델이 준비되지 않았어요.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ARPage(
                                        modelPath: modelPath,
                                        productName: name,
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: const [
                                      BoxShadow(
                                        blurRadius: 4,
                                        color: Colors.black12,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.view_in_ar, size: 20),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // 상품 정보
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                furnitureData!['brand'],
                                style: const TextStyle(color: Colors.grey),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                furnitureData!['name'],
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${formatter.format(furnitureData!['min_price'])}원',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),

                        const Divider(height: 1),

                        // 탭 메뉴
                        SizedBox(
                          height: 48,
                          child: Row(
                            children: [
                              _buildTab('상품 정보'),
                              _buildTab('리뷰'),
                              _buildTab('문의'),
                            ],
                          ),
                        ),
                        const Divider(height: 1),

                        // 상세설명 이미지
                        ...furnitureData!['description_images'].map<Widget>((
                          url,
                        ) {
                          return Image.network(url, fit: BoxFit.cover);
                        }).toList(),

                        // 리뷰 섹션
                        _buildReviewSection(),

                        // 문의 섹션
                        _buildInquirySection(),

                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    right: 16,
                    child: FloatingActionButton(
                      mini: true,
                      backgroundColor: Colors.white,
                      onPressed: () {
                        _scrollController.animateTo(
                          0,
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOut,
                        );
                      },
                      child: const Icon(Icons.arrow_upward),
                    ),
                  ),
                ],
              ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 36),
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
                      });

                      widget.onToggleLike(newStatus);

                      await toggleFavorite(
                        productId: widget.productId,
                        contentType: 'new',
                        isFavorited: newStatus,
                      );

                      final count = await fetchLikeCount(
                        widget.productId,
                        'new',
                      );
                      setState(() => likeCount = count);
                    },
                  ),
                  Text('$likeCount', style: const TextStyle(fontSize: 12)),
                ],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _showPurchaseOptions,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF2DFC2),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('구매하기'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTab(String label) {
    final isSelected = selectedTab == label;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => selectedTab = label);
          if (label == '리뷰') {
            _scrollToSection(_reviewKey);
          } else if (label == '문의') {
            _scrollToSection(_inquiryKey);
          }
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.black : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
