import 'package:flutter/material.dart';
import '../cart/cart_page.dart';
import 'pay_complete.dart';
import '../constants.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class PaymentPage extends StatefulWidget {
  final List<CartItem>? selectItems;
  final int productId;
  final String productName;
  final int quantity;
  final int totalPrice;
  final String selectedColor;
  final String selectedSize;
  final String imageUrl;

  const PaymentPage({
    super.key,
    this.selectItems,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.totalPrice,
    required this.selectedColor,
    required this.selectedSize,
    required this.imageUrl,
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  final formatter = NumberFormat('#,###');

  late Future<Map<String, dynamic>> _addressFuture;

  final TextEditingController _pointController = TextEditingController();
  int userPoint = 0; // 보유 포인트
  int usedPoint = 0; // 사용한 포인트

  // 옵션 ID 찾기
  String? getSelectedOptionId(List<dynamic> options, String selectedColor, String selectedSize) {
    for (var option in options) {
      if (option['color'] == selectedColor && option['size'] == selectedSize) {
        return option['option_id'].toString(); // 명확히 문자열로
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _addressFuture = fetchDefaultAddress();
    loadUserPoint();

    // 포인트 실시간 차감
    _pointController.addListener(() {
      final input = _pointController.text.replaceAll(',', '');
      int parsed = int.tryParse(input) ?? 0;
      if (parsed > userPoint) {
        parsed = userPoint;
        _pointController.text = formatter.format(parsed); // 자동으로 최대값으로 수정
        _pointController.selection = TextSelection.fromPosition(
          TextPosition(offset: _pointController.text.length),
        );
      }
      setState(() {
        usedPoint = parsed;
      });
    });
  }

  // 기본 배송지 조회 api
  Future<Map<String, dynamic>> fetchDefaultAddress() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? '';

    final uri = Uri.parse('$baseUrl/get_default_address/');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data;
    } else {
      throw Exception('배송지 조회 실패: ${response.statusCode}');
    }
  }

  // 포인트 조회 api
  Future<int> fetchUserPoint(String userId) async {
    final url = Uri.parse('$baseUrl/get_user_point/');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode({'user_id': userId}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data['point'] ?? 0;
    } else {
      throw Exception('포인트 정보를 불러오지 못했습니다');
    }
  }

  Future<void> loadUserPoint() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? '';
    try {
      final point = await fetchUserPoint(userId);
      setState(() {
        userPoint = point;
      });
    } catch (e) {
      print('포인트 조회 실패: $e');
    }
  }

  // 옵션 조회 api
  Future<List<dynamic>> fetchFurnitureOptions(int productId) async {
    final url = Uri.parse('$baseUrl/get_furniture_options/${widget.productId}/');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('옵션 정보를 불러오지 못했습니다');
    }
  }

  // 결제하기 api
  Future<void> processPayment() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? '';
    final pointUrl = Uri.parse('$baseUrl/process_payment/');
    final orderUrl = Uri.parse('$baseUrl/create_order/');

    /// 장바구니/바로구매 구분
    String? selectedOptionId;
    if (widget.selectItems == null) {
      // 바로구매일 때만 옵션 찾기
      List<dynamic> optionList = await fetchFurnitureOptions(widget.productId);
      selectedOptionId = getSelectedOptionId(
        optionList,
        widget.selectedColor,
        widget.selectedSize,
      );

      if (selectedOptionId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('선택한 옵션에 해당하는 상품이 없습니다.')),
        );
        return;
      }
    }

    // 포인트 차감 및 적립
    final pointResponse = await http.post(
      pointUrl,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'usedPoint': usedPoint,
        'totalPrice': widget.selectItems != null
            ? widget.selectItems!.fold(
          0,
              (sum, item) => sum + (item.price * item.quantity) - item.discount + item.deliveryFee,
        )
            : widget.totalPrice, // selectItems 있으면 총합 계산
      }),
    );

    if (pointResponse.statusCode == 200) {
      final result = jsonDecode(utf8.decode(pointResponse.bodyBytes));
      print('결제 완료. 적립된 포인트: ${result['earned_point']}');

      // 주문 상세 저장 api
      final orderResponse = await http.post(
        orderUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'total_price': (widget.selectItems != null
              ? widget.selectItems!.fold(
            0,
                (sum, item) => sum + (item.price * item.quantity) - item.discount + item.deliveryFee,
          )
              : widget.totalPrice) -
              usedPoint,
          'items': widget.selectItems != null
              ? widget.selectItems!.map((item) => {
            'option_id': item.optionId,
            'quantity': item.quantity,
          }).toList()
              : [
            {
              'option_id': selectedOptionId,
              'quantity': widget.quantity,
            }
          ]
        }),
      );

      if (orderResponse.statusCode == 200) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const PaymentCompletePage()),
              (route) => route.isFirst, // 홈만 남기고 다 제거
        );
      } else {
        print('주문 생성 실패: ${orderResponse.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('주문 저장에 실패했습니다.')),
        );
      }
    } else {
      print('포인트 처리 실패: ${pointResponse.statusCode}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('결제에 실패했습니다.')),
      );
    }
  }

  static Widget _buildPayOption(String label) {
    return OutlinedButton(
      onPressed: () {},
      child: Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int originalTotal = widget.selectItems != null
         ? widget.selectItems!.fold(
             0,
             (sum, item) =>
                 sum + (item.price * item.quantity) - item.discount + item.deliveryFee)
         : widget.totalPrice;

     // 2) 포인트 차감 후 실제 결제 금액
     final int payablePrice = (originalTotal - usedPoint).clamp(0, originalTotal);

     // 3) 적립 포인트 계산 (예: 결제금액의 1%)
    final int earnedPoint = (payablePrice * 0.01).floor();
    return FutureBuilder<Map<String, dynamic>>(
      future: _addressFuture,
      builder: (context, snapshot) {
        Widget addressSection;

        if (snapshot.connectionState == ConnectionState.waiting) {
          addressSection = const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError) {
          addressSection = const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 8),
              Text('배송지를 불러오는 데 실패했습니다.',
                  style: TextStyle(color: Colors.red)),
            ],
          );
        } else {
          final data = snapshot.data!;
          final name = data['receiver_name'] ?? '';
          final phone = data['phone_number'] ?? '';
          final address = data['address'] ?? '';
          final detailAddress = data['detail_address'] ?? '';

          addressSection = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name),
              Text(phone),
              Text(address + ', ' + detailAddress),
            ],
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              '결제',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 1,
          ),
          body: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 100),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('주문 상품',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      /// 장바구니에서 온 경우 여러 개 표시
                      if (widget.selectItems != null)
                        Column(
                          children: () {
                            Map<String, List<CartItem>> grouped = {};
                            for (var item in widget.selectItems!) {
                              grouped.putIfAbsent(item.optionId, () => []).add(item);
                            }

                            return grouped.entries.map((entry) {
                              final itemList = entry.value;
                              final first = itemList[0]; // 그룹 중 첫 아이템
                              final totalQuantity = itemList.fold(0, (sum, e) => sum + e.quantity);
                              final totalPrice = first.price * totalQuantity;
                              final imageUrl = (first.imageUrl?.startsWith('http') ?? false)
                                  ? first.imageUrl!
                                  : '$baseUrl/media/${first.imageUrl ?? ''}';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.black12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    imageUrl.isNotEmpty
                                        ? Image.network(
                                      imageUrl,
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                    )
                                        : const Icon(
                                      Icons.image_not_supported,
                                      size: 60,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            first.productName,
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          Text('${first.option} | 수량: $totalQuantity개'),
                                        ],
                                      ),
                                    ),
                                    Text('${formatter.format(totalPrice)}원'),
                                  ],
                                ),
                              );
                            }).toList();
                          }(),
                        )
                      else
                      /// 바로 구매인 경우: widget.imageUrl을 이용해 이미지 표시
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              // 여기서 실제 이미지 로딩
                              (() {
                                // widget.imageUrl이 절대경로인지 아닌지 검사
                                final singleImageUrl = widget.imageUrl.startsWith('http')
                                    ? widget.imageUrl
                                    : '$baseUrl/media/${widget.imageUrl}';
                                return singleImageUrl.isNotEmpty
                                    ? Image.network(
                                  singleImageUrl,
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.cover,
                                )
                                    : Container(
                                  width: 64,
                                  height: 64,
                                  color: Colors.grey[300],
                                );
                              })(),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.productName,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    Text('옵션: 수량 ${widget.quantity}개'),
                                  ],
                                ),
                              ),
                              Text('${formatter.format(widget.totalPrice)}원'),
                            ],
                          ),
                        ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('배송지',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          TextButton(
                            onPressed: () {
                              // 주소 변경 기능
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 0),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              '주소 변경',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF916636),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      addressSection,
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 36,
                        child: TextField(
                          decoration: const InputDecoration(
                            contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(),
                            hintText: '요청사항 입력',
                            hintStyle: TextStyle(fontSize: 13),
                          ),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text('포인트',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 36,
                        child: TextField(
                          controller: _pointController,
                          decoration: const InputDecoration(
                            contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(),
                            hintText: '사용할 포인트 입력',
                            hintStyle: TextStyle(fontSize: 13),
                          ),
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '보유: ${formatter.format(userPoint)}P',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text('결제 수단',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      const Text('간편 결제'),
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Color(0xFF916636)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('농협 ****-****-**'),
                            Text('${earnedPoint}P 적립'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('일반 결제'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildPayOption('토스'),
                          _buildPayOption('카카오페이'),
                          _buildPayOption('네이버페이'),
                          _buildPayOption('무통장 입금'),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF2DFC2),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 0),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          processPayment();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: const Color(0xFF916636),
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          '${formatter.format(payablePrice)}원 결제하기',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF916636),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
