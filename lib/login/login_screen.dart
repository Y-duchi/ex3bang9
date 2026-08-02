// lib/views/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_naver_login/flutter_naver_login.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import '../login/sign_up_screen.dart';
import 'sign_up_screen.dart';
import 'find_id_screen.dart';
import 'find_password_screen.dart';
import '../constants.dart';
import 'package:bang9_test/main2.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bang9_test/login/simple_login.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final idController = TextEditingController();
    final pwController = TextEditingController();

    // 로그인 성공 시 유저 아이디 저장
    Future<void> saveUserId(String userId) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', userId);
    }

    Future<void> startPortfolioDemo() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', 'portfolio_demo');
      await prefs.setString('nickname', '방꾸석 데모');
      await prefs.setString('email', 'demo@local.invalid');
      await prefs.setString('login_type', 'portfolio_demo');
      await prefs.setBool('certified', true);

      if (!context.mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const MainPage(initialIndex: 0),
        ),
      );
    }

    // 로그인 API
    Future<void> login() async {
      var url = Uri.parse('$baseUrl/login/');
      var response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': idController.text,
          'password': pwController.text,
        }),
      );

      var data = jsonDecode(utf8.decode(response.bodyBytes));

      if (data['success']) {
        // 유저 아이디 저장
        String userId = data['user_id'];
        await saveUserId(userId);

        // ─── 여기에 닉네임(과 포인트)도 저장 ───
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('nickname', data['nickname']);
        await prefs.setString('email', data['email']);
        await prefs.setBool(
          'certified',
          data['certification'] == true || data['certification'] == 1,
        );
        //await prefs.setInt('points', data['points']);  // 필요하면 활성화

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const MainPage(initialIndex: 0),
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(content: Text(data['message'])),
        );
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 로고 + 앱 타이틀
                Column(
                  children: [
                    Center(
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 240,
                        height: 200,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),

                const SizedBox(height: 40),

                if (portfolioDemo) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F1E7),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Text(
                      '로컬 포트폴리오 데모',
                      style: TextStyle(
                        color: Color(0xFF7A5731),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],

                // 아이디 입력
                Container(
                  width: 300,
                  height: 45,
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFD9D9D9)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextField(
                    controller: idController,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: '아이디를 입력해주세요.',
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                // 비밀번호 입력
                Container(
                  width: 300,
                  height: 45,
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFD9D9D9)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextField(
                    controller: pwController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: '비밀번호를 입력해주세요.',
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                // 로그인 버튼
                InkWell(
                  onTap: portfolioDemo ? startPortfolioDemo : login,
                  borderRadius: BorderRadius.circular(20),
                  child: Ink(
                    width: 340,
                    height: 55,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4DFB8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Center(
                      child: Text(
                        portfolioDemo ? '데모 시작' : '로그인',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.brown,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                // 아이디/비밀번호 찾기 + 회원가입 버튼 분리
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FindIdScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        '아이디 찾기',
                        style: TextStyle(fontSize: 12, color: Colors.black),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FindPasswordScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        '비밀번호 찾기',
                        style: TextStyle(fontSize: 12, color: Colors.black),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SignUpScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        '회원가입',
                        style: TextStyle(fontSize: 12, color: Colors.black),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                // 소셜 로그인은 실제 provider 키를 넣은 non-demo 빌드에서만 노출
                if (!portfolioDemo)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 카카오
                      GestureDetector(
                        onTap: () => SimpleLogin.signInWithKakao(context),
                        child: const CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.transparent,
                          backgroundImage: AssetImage(
                            'assets/images/kakao_icon.png',
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      // 네이버
                      GestureDetector(
                        onTap: () => SimpleLogin.signInWithNaver(context),
                        child: const CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.transparent,
                          backgroundImage: AssetImage(
                            'assets/images/naver_icon.png',
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
