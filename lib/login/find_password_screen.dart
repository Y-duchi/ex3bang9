import 'package:flutter/material.dart';

class FindPasswordScreen extends StatefulWidget {
  const FindPasswordScreen({super.key});

  @override
  State<FindPasswordScreen> createState() => _FindPasswordScreenState();
}

class _FindPasswordScreenState extends State<FindPasswordScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final codeController = TextEditingController();
  bool codeSent = false;

  void sendVerificationCode() {
    setState(() {
      codeSent = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('인증번호가 전송되었습니다.')),
    );
  }

  void verifyCode() {
    String code = codeController.text.trim();
    if (code == '123456') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('임시 비밀번호가 이메일로 전송되었습니다.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('인증번호가 올바르지 않습니다.')),
      );
    }
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool obscure = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Container(
        height: 45,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFD9D9D9)),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: TextField(
          controller: controller,
          obscureText: obscure,
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: label,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('비밀번호 찾기'),
        backgroundColor: const Color(0xFFF4DFB8),
        foregroundColor: Colors.brown,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            const Text(
              '비밀번호를 찾고자 하는 계정의 정보를 입력해주세요.',
              style: TextStyle(fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _buildTextField('이름', nameController),
            _buildTextField('이메일', emailController),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: sendVerificationCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF4DFB8),
                foregroundColor: Colors.brown,
              ),
              child: const Text('인증번호 전송'),
            ),
            if (codeSent) ...[
              const SizedBox(height: 20),
              _buildTextField('인증번호', codeController),
              ElevatedButton(
                onPressed: verifyCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF4DFB8),
                  foregroundColor: Colors.brown,
                ),
                child: const Text('확인'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
