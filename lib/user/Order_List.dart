import 'review_write_page.dart';
import 'package:flutter/material.dart';
import '../constants.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

void main() => runApp(const MaterialApp(
  debugShowCheckedModeBanner: false,
  home: OrderPage(),
));

class OrderPage extends StatefulWidget {
  const OrderPage({super.key});

  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  late Future<List<dynamic>> _orderFuture;

  @override
  void initState() {
    super.initState();
    _orderFuture = fetchOrderHistory();
  }

  ///리뷰 수 갱신
  int reviewCount = 0;

  Future<void> fetchReviewCount() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? '';

    final response = await http.get(
        Uri.parse('$baseUrl/get_my_review_count/?user_id=$userId'));
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      setState(() {
        reviewCount = data['count'] ?? 0;
      });
    } else {
      debugPrint('리뷰 개수 불러오기 실패: ${response.statusCode}');
    }
  }

  ///리뷰 유무 확인
  Future<bool> hasUserReviewed(String userId, String optionId) async {
    final response = await http.get(Uri.parse(
        '$baseUrl/has_user_reviewed_option/?user_id=$userId&option_id=$optionId'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['review_exists'] ?? false;
    } else {
      return false; // API 실패 시 그냥 보여줌
    }
  }

  // 주문 내역 불러오기 api
  Future<List<dynamic>> fetchOrderHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? '';

    final url = Uri.parse('$baseUrl/get_user_orders/');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('주문 내역 조회 실패: ${response.statusCode}');
    }
  }

  Widget buildOrderItem(dynamic item, String orderStatus, String userId) {
    return FutureBuilder<bool>(
      future: hasUserReviewed(userId, item['option_id']),
      builder: (context, snapshot) {
        final hasReviewed = snapshot.data ?? false;

        return Column(
          children: [
            Row(
              children: [
                Image.network(item['furniture_image'] ?? '',
                  width: 66,
                  height: 66,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      Container(width: 66, height: 66, color: Colors.grey),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['furniture_brand'] ?? '',
                          style: const TextStyle(fontSize: 12)),
                      Text(item['furniture_name'] ?? '',
                          style: const TextStyle(fontSize: 12)),
                      Text('${item['color'] ?? ''} / ${item['size'] ??
                          ''} / ${item['quantity'] ?? ''}개',
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(orderStatus ?? '',
                        style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('${NumberFormat('#,###').format(item['price'] ?? 0)}원',
                        style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 4),
                    if (!hasReviewed)
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) {
                                final firstImage = item['furniture_image'] as String? ??
                                    '';

                                return ReviewWritePage(
                                  isEditing: false,
                                  optionId: item['option_id'] ?? '옵션 불러오기 실패',
                                  productName: item['furniture_name'],
                                  color: item['color'],
                                  size: item['size'],
                                  productImageUrl: firstImage,
                                );
                              },
                            ),
                          ).then((_) {
                            fetchReviewCount(); // 작성 후 리프레시
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4DFB8),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('리뷰', style: TextStyle(
                              fontSize: 10, color: Colors.black)),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              height: 1,
              color: const Color(0xFFD9D9D9),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        title: const Text('주문 내역', style: TextStyle(color: Colors.black)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _orderFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('주문 내역을 불러오지 못했습니다.'));
          } else {
            final orders = snapshot.data!;
            return FutureBuilder<String>(
              future: SharedPreferences.getInstance().then((prefs) =>
              prefs.getString('user_id') ?? ''),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData)
                  return const SizedBox(); // or loading
                final userId = userSnapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    final orderStatus = order['order_status'];
                    final date = order['order_date'];
                    final total = order['total_price'];
                    final items = order['items'] as List<dynamic>;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(date, style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        ...items.map((item) =>
                            buildOrderItem(item, orderStatus, userId)).toList(),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                              '총 ${NumberFormat('#,###').format(total)}원',
                              style: const TextStyle(fontSize: 14)),
                        ),
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                );
              },
            );
          }
        },
      ),
    );
  }
}