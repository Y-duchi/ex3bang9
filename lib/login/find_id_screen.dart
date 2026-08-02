import 'package:flutter/material.dart';

class FindIdScreen extends StatefulWidget {
  const FindIdScreen({super.key});

  @override
  State<FindIdScreen> createState() => _FindIdScreenState();
}

class _FindIdScreenState extends State<FindIdScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final codeController = TextEditingController();

  bool codeSent = false;
  String? foundId;

  void sendVerificationCode() {
    setState(() {
      codeSent = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('인증번호가 전송되었습니다.')),
    );
  }

  void findId() {
    // 실제로는 서버에서 인증번호 확인 및 아이디 조회
    String code = codeController.text.trim();
    if (code == '123456') {
      setState(() {
        foundId = 'example123'; // 찾은 아이디 (mock)
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('인증번호가 올바르지 않습니다.')),
      );
    }
  }

  Widget _buildTextField(String label, TextEditingController controller) {
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
        title: const Text('아이디 찾기'),
        backgroundColor: const Color(0xFFF4DFB8),
        foregroundColor: Colors.brown,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildTextField('이름을 입력해주세요.', nameController),
            _buildTextField('이메일을 입력해주세요.', emailController),
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
              _buildTextField('인증번호를 입력해주세요.', codeController),
              ElevatedButton(
                onPressed: findId,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF4DFB8),
                  foregroundColor: Colors.brown,
                ),
                child: const Text('아이디 찾기'),
              ),
            ],
            if (foundId != null) ...[
              const SizedBox(height: 30),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF6D5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.brown),
                ),
                child: Text(
                  '찾은 아이디: $foundId',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.brown,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
