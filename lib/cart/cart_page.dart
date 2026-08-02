import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';
import '../shopping/payment_page.dart';

class CartPage extends StatefulWidget {
  final String userId;

  const CartPage({super.key, required this.userId});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  List<CartItem> cartItems = [];
  bool isLoading = true;
  bool isAllSelected = false;

  @override
  void initState() {
    super.initState();
    fetchCartItems(widget.userId);
  }

  Future<void> fetchCartItems(String userId) async {
    try {
      final uri = Uri.parse('$baseUrl/get_cart_items/?user_id=$userId');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final List<dynamic> cartJson = jsonData['cart'];
        setState(() {
          cartItems = cartJson.map((item) => CartItem.fromJson(item)).toList();
          isLoading = false;
        });
      } else {
        throw Exception('장바구니 불러오기 실패');
      }
    } catch (e) {
      print('에러 발생: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> updateQuantityToServer(String optionId, int quantity) async {
    final uri = Uri.parse('$baseUrl/update_cart_quantity/');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'user_id': widget.userId,
        'option_id': optionId,
        'quantity': quantity,
      }),
    );
  }

  ///옵션 업데이트
  Future<void> updateCartOption(String oldOptionId, String newOptionId) async {
    final uri = Uri.parse('$baseUrl/update_cart_option/');
    await http.post(uri, body: {
      'user_id': widget.userId,
      'old_option_id': oldOptionId,
      'new_option_id': newOptionId,
    });
  }

  void _changeOption(int index) async {
    final currentProductId = cartItems[index].productId;

    final uri = Uri.parse('$baseUrl/get_product_options/?product_id=$currentProductId');
    final response = await http.get(uri);

    if (response.statusCode != 200) return;

    final List<dynamic> options = json.decode(response.body)['options'];

    String? selectedOptionId;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('옵션 변경'),
        content: StatefulBuilder(
          builder: (context, setState) {
            return DropdownButton<String>(
              isExpanded: true,
              value: selectedOptionId,
              hint: const Text('옵션을 선택하세요'),
              items: options.map<DropdownMenuItem<String>>((option) {
                final id = option['option_id'];
                final label = "${option['color']} / ${option['size']}";
                return DropdownMenuItem(value: id, child: Text(label));
              }).toList(),
              onChanged: (value) {
                setState(() => selectedOptionId = value);
              },
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('확인'),
          ),
        ],
      ),
    );

    if (selectedOptionId != null) {
      await updateCartOption(cartItems[index].optionId, selectedOptionId!);
      await fetchCartItems(widget.userId);
    }
  }


  //장바구니 제거
  Future<void> deleteCartItemFromServer(String optionId) async {
    final uri = Uri.parse('$baseUrl/delete_cart_items/');
    await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': widget.userId,
        'option_ids': [optionId],
      }),
    );
  }

  void toggleAll(bool? value) {
    setState(() {
      isAllSelected = value ?? false;
      for (var item in cartItems) {
        item.selected = isAllSelected;
      }
    });
  }

  void toggleSingle(int index, bool? value) {
    setState(() {
      cartItems[index].selected = value ?? false;
      isAllSelected = cartItems.every((item) => item.selected);
    });
  }

  void increaseQuantity(int index) async {
    setState(() {
      cartItems[index].quantity++;
    });
    await updateQuantityToServer(cartItems[index].optionId, cartItems[index].quantity);
  }

  void decreaseQuantity(int index) async {
    if (cartItems[index].quantity > 1) {
      setState(() {
        cartItems[index].quantity--;
      });
      await updateQuantityToServer(cartItems[index].optionId, cartItems[index].quantity);
    } else {
      final shouldDelete = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('상품 삭제'),
          content: const Text('장바구니에서 제거하겠습니까?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
          ],
        ),
      );

      if (shouldDelete ?? false) {
        // 수량 0으로 서버에 먼저 업데이트
        await updateQuantityToServer(cartItems[index].optionId, 0);

        // 그 다음 실제 삭제 요청
        await deleteCartItemFromServer(cartItems[index].optionId);

        // UI에서 삭제
        setState(() {
          cartItems.removeAt(index);
          isAllSelected = cartItems.isNotEmpty && cartItems.every((item) => item.selected);
        });
      }
    }
  }

  void removeItem(int index) async {
    await deleteCartItemFromServer(cartItems[index].optionId);
    setState(() {
      cartItems.removeAt(index);
      isAllSelected = cartItems.isNotEmpty && cartItems.every((item) => item.selected);
    });
  }

  int get productTotal =>
      cartItems.fold(0, (sum, item) => sum + (item.price ?? 0) * (item.quantity ?? 0));

  int get totalDiscount =>
      cartItems.fold(0, (sum, item) => sum + (item.discount ?? 0));

  int get totalDeliveryFee =>
      cartItems.fold(0, (sum, item) => sum + (item.deliveryFee ?? 0));

  int get totalAmount => productTotal - totalDiscount + totalDeliveryFee;


  ///결제이동
  void onPay() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');

    if (userId == null) {
      showDialog(
        context: context,
        builder: (context) => const AlertDialog(
          title: Text('오류'),
          content: Text('로그인 정보가 없습니다.'),
        ),
      );
      return;
    }

    final selectedItems = cartItems.where((item) => item.selected).toList();

    if (selectedItems.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => const AlertDialog(
          title: Text('알림'),
          content: Text('선택된 상품이 없습니다.'),
        ),
      );
      return;
    }

    ///선택된 항목들 기준 총 결제 금액 계산
    final totalSelectedAmount = selectedItems.fold(
      0,
          (sum, item) => sum + (item.price * item.quantity) - item.discount + item.deliveryFee,
    );

    ///결제 화면으로 이동 (selectItems 포함)
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentPage(
          selectItems: selectedItems,
          productId: selectedItems[0].cartId,
          productName: selectedItems[0].productName,
          quantity: selectedItems[0].quantity,
          totalPrice: totalSelectedAmount,
          selectedColor: selectedItems[0].option.split(' / ')[0],
          selectedSize: selectedItems[0].option.split(' / ')[1],
          imageUrl: selectedItems[0].imageUrl ?? '',
        ),
      ),
    );

    //결제 완료 후 장바구니 새로고침
    if (result == 'success') {
      await fetchCartItems(userId);
      setState(() {});
    }
  }

  ///카트삭제
  void deleteCartItem(String optionId) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? '';

    final url = Uri.parse('$baseUrl/delete_cart_items/');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'option_id': [optionId]}),
    );

    if (response.statusCode == 200) {
      setState(() {
        cartItems.removeWhere((item) => item.optionId == optionId);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('삭제에 실패했습니다')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('장바구니'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : cartItems.isEmpty
          ? const Center(child: Text('장바구니가 비어있습니다.'))
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Checkbox(
                  value: isAllSelected,
                  onChanged: toggleAll,
                ),
                const Text('전체 선택'),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: cartItems.length,
              itemBuilder: (context, index) {
                final item = cartItems[index];
                final imageUrl = item.imageUrl?.startsWith('http') ?? false
                    ? item.imageUrl!
                    : '$baseUrl/media/${item.imageUrl ?? ''}';

                return Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: item.selected,
                            onChanged: (v) => toggleSingle(index, v),
                          ),
                          imageUrl.isNotEmpty
                              ? Image.network(imageUrl, width: 60, height: 60, fit: BoxFit.cover)
                              : const Icon(Icons.image_not_supported),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.productName, style: const TextStyle(fontSize: 13)),
                                Text(item.option, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton(
                                    onPressed: () => _changeOption(index),
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(0, 0),
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text('옵션 변경', style: TextStyle(fontSize: 10)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => removeItem(index),
                            child: const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Text('x'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => decreaseQuantity(index),
                            child: const CircleAvatar(
                              radius: 12,
                              backgroundColor: Color(0xFFE0E0E0),
                              child: Text('-', style: TextStyle(fontSize: 16)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(item.quantity.toString(), style: const TextStyle(fontSize: 13)),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () => increaseQuantity(index),
                            child: const CircleAvatar(
                              radius: 12,
                              backgroundColor: Color(0xFFE0E0E0),
                              child: Text('+', style: TextStyle(fontSize: 16)),
                            ),
                          ),
                          const Spacer(),
                          Text('${item.price * item.quantity}원',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEDEDED)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _rowText('총 상품 금액', '${productTotal}원'),
                _rowText('상품 할인', '-${totalDiscount}원', color: const Color(0xFFD7763D)),
                _rowText('배송비', '${totalDeliveryFee}원'),
                _rowText('총 결제 금액', '${totalAmount}원', color: const Color(0xFFD7763D), isBold: true),
              ],
            ),
          ),
          InkWell(
            onTap: onPay, // 위에서 만든 함수
            child: Container(
              height: 60,
              width: double.infinity,
              color: const Color(0xFFF4DFB8),
              child: const Center(
                child: Text(
                  '결제하기',
                  style: TextStyle(
                    color: Color(0xFF714322),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rowText(String left, String right, {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            left,
            style: TextStyle(
              color: color ?? Colors.black,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Text(
            right,
            style: TextStyle(
              color: color ?? Colors.black,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class CartItem {
  final int cartId;
  final String productName;
  final String option;
  final String optionId;
  int quantity;
  final int price;
  final String? imageUrl;
  bool selected;
  final int deliveryFee;
  final int discount;
  final String productId;

  CartItem({
    required this.cartId,
    required this.productName,
    required this.option,
    required this.optionId,
    required this.quantity,
    required this.price,
    this.imageUrl,
    this.selected = false,
    required this.deliveryFee,
    required this.discount,
    required this.productId,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      cartId: json['cart_id'],
      productName: json['product_name'] ?? '상품 없음',
      option: json['option'] ?? '옵션 없음',
      optionId: json['option_id'] ?? '',
      quantity: json['quantity'] ?? 1,
      price: json['price'] ?? 0,
      imageUrl: json['image_url'],
      deliveryFee: json['delivery_fee'] ?? 0,
      discount: json['discount'] ?? 0,
      productId: json['product_id'] ?? '',
    );
  }
}