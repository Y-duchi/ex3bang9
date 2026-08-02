import 'package:bang9_test/login/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../login/simple_login.dart';
import 'Address_management_page.dart';
import 'ID_page.dart';
import 'user_info_edit_page.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: SettingsPage(),
  ));
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('설정', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 12),
          const Text('내 정보', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildListTile('회원 정보 수정', onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const UserInfoEditPage()),
            );
          }),
          _buildListTile('배송지 관리', onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddressManagementPage()),
            );
          }),
          _buildListTile('2차 인증', onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => IDPage()),
            );
          }),
          const SizedBox(height: 24),
          const Divider(thickness: 1, color: Color(0xFFD9D9D9)),
          const SizedBox(height: 24),
          const Text('설정', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildListTile('로그아웃', onTap: () => logout(context)),
        ],
      ),
    );
  }

  // 로그인 타입에 따라 로그아웃 분기
  Future<void> logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();

    final loginType = prefs.getString('login_type');

    final keysToRemove = [
      'login_type',
      'user_token',
      'refresh_token',
      'user_id',
      'username',
      'nickname',
      'email',
      'phone',
      'points',
      'certification',
    ];
    for (var key in keysToRemove) {
      await prefs.remove(key);
    }
    try {
      if (loginType == 'kakao') {
        await SimpleLogin().logoutFromKakao(context);
      } else if (loginType == 'naver') {
        await logoutFromNaver(context);
      }
    } catch (_) {
      // 무시
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('로그아웃 되었습니다'),
        duration: Duration(seconds: 2),
      ),
    );

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
    );
  }


  Widget _buildListTile(String title, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 14)),
            const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
      ),
    );
  }
}
