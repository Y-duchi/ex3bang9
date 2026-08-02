import 'dart:convert';
import '../top_bar/top_bar.dart';
import 'shopping_Favorite.dart';
import 'used_Favorite.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import 'Activity_Page.dart';
import 'Order_List.dart';
import 'On_Sale_Page.dart';
import 'Sold_Detail_Page.dart';
import 'Settings.dart';
import 'Shopping_Detail_Page.dart';
import 'Used_Market_Detail_Page.dart';

class UserPage extends StatefulWidget {
  const UserPage({Key? key}) : super(key: key);

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  String? userId;

  @override
  void initState() {
    super.initState();
    loadUserId();
  }

  Future<void> loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userId = prefs.getString('user_id');
    });
  }

  @override
  Widget build(BuildContext context) {
    if (userId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TopBar(
                currentUserId: userId!,
                showBackButton: false,
              ),
              const SizedBox(height: 12),
              const ProfileCard(),
              const SizedBox(height: 12),
              const OrderStats(),
              const SizedBox(height: 12),
              const DeliveryList(),
              const SizedBox(height: 12),
              const Favorites(),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileCard extends StatefulWidget {
  const ProfileCard({super.key});

  @override
  State<ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<ProfileCard> {
  int _point = 0;
  String? nickname;
  String? profileImageUrl;

  @override
  void initState() {
    super.initState();
    loadUserPoint();
    fetchUserInfo();
  }

  // 포인트 조회 api
  Future<int> fetchUserPoint() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');

    final response = await http.post(
      Uri.parse('$baseUrl/get_user_point/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['point'] ?? 0;
    } else {
      throw Exception('포인트를 불러오지 못했습니다');
    }
  }

  Future<void> loadUserPoint() async {
    try {
      final point = await fetchUserPoint();
      setState(() {
        _point = point;
      });
    } catch (e) {
      print('포인트 조회 실패: $e');
    }
  }

  // 회원 정보 조회 api
  Future<void> fetchUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');

    final response = await http.post(
      Uri.parse('$baseUrl/get_user_info/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      setState(() {
        nickname = data['nickname'];
        profileImageUrl = data['profile_image'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: Colors.grey.shade300,
          backgroundImage:
          profileImageUrl != null ? NetworkImage(profileImageUrl!) : null,
          child: profileImageUrl == null
              ? const Icon(Icons.person, size: 32, color: Colors.white)
              : null,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(nickname ?? '닉네임', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),),
              Text('포인트: $_point', style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.settings, color: Colors.black),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            );
          },
        ),
      ],
    );
  }
}

class OrderStats extends StatefulWidget {
  const OrderStats({super.key});

  @override
  State<OrderStats> createState() => _OrderStatsState();
}

class _OrderStatsState extends State<OrderStats> {
  int orderCount = 0;
  int reviewCount = 0;
  int countOnSale = 0;
  int countSold = 0;

  @override
  void initState() {
    super.initState();
    loadOrderCount();
    fetchReviewCount();
    fetchSaleCounts();
  }

  //주문 내역 개수 불러오기 api
  Future<int> fetchOrderCount() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');

    final response = await http.post(
      Uri.parse('$baseUrl/get_user_order_count/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['count'] ?? 0;
    } else {
      throw Exception('주문 개수를 불러오지 못했습니다');
    }
  }

  Future<void> loadOrderCount() async {
    try {
      final count = await fetchOrderCount();
      setState(() {
        orderCount = count;
      });
    } catch (e) {
      print('주문 수 조회 실패: $e');
    }
  }

  Future<void> fetchReviewCount() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? '';

    if (userId.isNotEmpty) {
      final url = Uri.parse('$baseUrl/get_my_review_count/?user_id=$userId');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          reviewCount = data['count'];
        });
      }
    }
  }

  Future<void> fetchSaleCounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? '';
      print("user_id: $userId");

      if (userId.isEmpty) {
        print("user_id is empty");
        return;
      }

      final url = Uri.parse('$baseUrl/get_user_sale_counts/?user_id=$userId');
      print("url: $url");

      final response = await http.get(url);
      print("status: ${response.statusCode}");
      print("body: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            countOnSale = data['on_sale'] ?? 0;
            countSold = data['sold'] ?? 0;
          });
          print("Updated: $countOnSale / $countSold");
        }
      }
    } catch (e, stack) {
      print("fetchSaleCounts error: $e");
      print("stack: $stack");
    }
  }


  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          StatBox(title: '주문내역', value: '$orderCount'),
          StatBox(title: '나의 리뷰', value: '$reviewCount'),
          StatBox(title: '판매중', value: '$countOnSale'),
          StatBox(title: '판매 완료', value: '$countSold'),
        ],
      ),
    );
  }
}

class StatBox extends StatelessWidget {
  final String title;
  final String value;
  const StatBox({super.key, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    final Widget content = Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
              fontSize: 20,
              color: Color(0xFFD7763D),
              fontWeight: FontWeight.bold,
            )),
      ],
    );

    void navigate() {
      if (title == '주문내역') {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderPage()));
      } else if (title == '나의 리뷰') {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const MyReviewAndInquiryPage()));
      } else if (title == '판매중') {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const OnSalePage()));
      } else if (title == '판매 완료') {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const SoldDetailPage()));
      }
    }

    return GestureDetector(
      onTap: navigate,
      child: content,
    );
  }
}


class DeliveryList extends StatefulWidget {
  const DeliveryList({super.key});

  @override
  State<DeliveryList> createState() => _DeliveryListState();
}

class _DeliveryListState extends State<DeliveryList> {
  late Future<List<dynamic>> _deliveryOrders;

  @override
  void initState() {
    super.initState();
    _deliveryOrders = fetchOrderHistory();
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _deliveryOrders,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return const Text('배송 정보를 불러오지 못했습니다.');
        } else {
          final orders = snapshot.data!;
          final filteredOrders = orders.where((order) {
            final items = order['items'] as List<dynamic>;
            // 모든 상품이 배송 완료일 경우 제외
            return items.any((item) => order['order_status'] != '배송 완료');
          }).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('배송조회', style: TextStyle(fontSize: 14)),
              const SizedBox(height: 8),
              ...filteredOrders.map((order) {
                final items = order['items'] as List<dynamic>;
                final total = order['total_price'];
                final date = order['order_date'];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...items.where((item) => order['order_status'] != '배송 완료').map((item) {
                      return DeliveryItem(
                        brand: item['furniture_brand'] ?? '',
                        name: item['furniture_name'] ?? '',
                        option: '${item['color']} / ${item['size']} / ${item['quantity']}개',
                        price: '${NumberFormat('#,###').format(item['price'])}원',
                        status: order['order_status'],
                        imageUrl: item['furniture_image'] ?? '',
                      );
                    }).toList(),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text('총 ${NumberFormat('#,###').format(total)}원'),
                    ),
                    const SizedBox(height: 12),
                  ],
                );
              }).toList(),
            ],
          );
        }
      },
    );
  }
}

class DeliveryItem extends StatelessWidget {
  final String brand, name, option, price, status, imageUrl;
  const DeliveryItem({
    super.key,
    required this.brand,
    required this.name,
    required this.option,
    required this.price,
    required this.status,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.network(
          imageUrl,
          width: 66,
          height: 66,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              Container(width: 66, height: 66, color: Colors.grey),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(brand, style: const TextStyle(fontSize: 12)),
              Text(name, style: const TextStyle(fontSize: 12)),
              Text(option, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(price, style: const TextStyle(fontSize: 14)),
            Text(status, style: const TextStyle(fontSize: 12)),
            const Text('배송조회', style: TextStyle(fontSize: 12)),
          ],
        ),
      ],
    );
  }
}

class Favorites extends StatelessWidget {
  const Favorites({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildSection(
          context,
          '쇼핑',
          Icons.shopping_bag,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShoppingDetailPage())),
        ),
        const SizedBox(height: 16),
        ShoppingFavorite(),
        buildSection(
          context,
          '중고거래',
          Icons.sync_alt,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UsedMarketDetailPage())),
        ),
        const SizedBox(height: 8),
        UsedFavorite(),
      ],
    );
  }

  Widget buildSection(BuildContext context, String title, IconData icon, VoidCallback onTap) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 6),
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
        GestureDetector(
          onTap: onTap,
          child: const Text('상세보기 >', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}