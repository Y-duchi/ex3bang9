import 'package:flutter/material.dart';
import 'shopping/shopping.dart';
import 'used/usedT.dart';
import 'community/community_page.dart';
import 'user/User.dart';

class MainPage extends StatefulWidget {
  final int initialIndex;

  const MainPage({super.key, this.initialIndex = 0}); // 👈 기본값 0

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  late int currentIndex;

  final List<Widget> pages = [
    const ShoppingPage(),
    const UsedTradePage(),
    const CommunityPage(),
    const UserPage(),
  ];

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex; // 👈 전달받은 인덱스로 초기화
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        selectedItemColor: const Color(0xFF916636),
        unselectedItemColor: Colors.black,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.shopping_bag), label: '쇼핑'),
          BottomNavigationBarItem(icon: Icon(Icons.swap_horiz), label: '중고거래'),
          BottomNavigationBarItem(icon: Icon(Icons.groups), label: '커뮤니티'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '사용자'),
        ],
      ),
    );
  }
}