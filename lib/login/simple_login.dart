// lib/login/simple_login.dart

import 'package:flutter/material.dart';
import 'package:flutter_naver_login/flutter_naver_login.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../constants.dart';
import 'login_screen.dart';
import 'package:bang9_test/main2.dart';

class SimpleLogin {
  /// 카카오 로그인
  static Future<void> signInWithKakao(BuildContext context) async {
    try {
      OAuthToken token;
      if (await isKakaoTalkInstalled()) {
        token = await UserApi.instance.loginWithKakaoTalk();
      } else {
        token = await UserApi.instance.loginWithKakaoAccount();
      }

      final user = await UserApi.instance.me();
      final kakaoId = user.id.toString();
      final nicknameFromSdk = user.kakaoAccount?.profile?.nickname ?? '';
      final email = user.kakaoAccount?.email ?? '';

      final response = await http.post(
        Uri.parse('$baseUrl/kakao_login/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'kakao_id': kakaoId,
          'nickname': nicknameFromSdk,
          'email': email,
        }),
      );

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        // 로그인 타입
        await prefs.setString('login_type', 'kakao');
        // 사용자 정보
        await prefs.setString('user_id',  data['user_id']);
        await prefs.setString('nickname', data['nickname']);
        await prefs.setInt('points',     data['points'] as int);

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainPage(initialIndex: 0,)),
              (_) => false,
        );
      } else {
        _showErrorDialog(context, data['message']);
      }
    } catch (e) {
      print('카카오 로그인 실패: $e');
      _showErrorDialog(context, '카카오 로그인 중 오류가 발생했습니다.');
    }
  }

  /// 카카오 로그아웃
  Future<void> logoutFromKakao(BuildContext context) async {
    try {
      await UserApi.instance.logout();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("로그아웃 되었습니다.")),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (_) => false,
      );
    } catch (e) {
      print('카카오 로그아웃 오류: $e');
    }
  }

  /// 네이버 로그인
  static Future<void> signInWithNaver(BuildContext context) async {
    try {
      final loginResult = await FlutterNaverLogin.logIn();
      if (loginResult.status != NaverLoginStatus.loggedIn) {
        _showErrorDialog(context, '네이버 로그인에 실패했습니다.');
        return;
      }

      final accessToken = (await FlutterNaverLogin.currentAccessToken).accessToken;
      final profileResp = await http.get(
        Uri.parse('https://openapi.naver.com/v1/nid/me'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      final profileData = jsonDecode(profileResp.body)['response'];

      final response = await http.post(
        Uri.parse('$baseUrl/naver_login/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'naver_id': profileData['id'],
          'username': profileData['name'] ?? '',
          'nickname': profileData['nickname'] ?? '',
          'email':    profileData['email'] ?? '',
          'phone':    profileData['mobile'] ?? '',
        }),
      );

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        // 로그인 타입
        await prefs.setString('login_type', 'naver');
        // 사용자 정보
        await prefs.setString('user_id',  data['user_id']);
        await prefs.setString('nickname', data['nickname']);
        await prefs.setInt('points',     data['points'] as int);

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainPage(initialIndex: 0,)),
              (_) => false,
        );
      } else {
        _showErrorDialog(context, data['message']);
      }
    } catch (e) {
      print('네이버 로그인 오류: $e');
      _showErrorDialog(context, '네이버 로그인 중 오류가 발생했습니다.');
    }
  }

  static void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
}

/// 네이버 로그아웃
Future<void> logoutFromNaver(BuildContext context) async {
  try {
    await FlutterNaverLogin.logOutAndDeleteToken();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("로그아웃 되었습니다.")),
    );

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
    );
  } catch (e) {
    print('네이버 로그아웃 오류: $e');
  }
}
