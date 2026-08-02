import 'package:flutter/material.dart';
import '../constants.dart';
import '../login/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';

class UserInfoEditPage extends StatefulWidget {
  const UserInfoEditPage({super.key});

  @override
  State<UserInfoEditPage> createState() => _UserInfoEditPageState();
}

class _UserInfoEditPageState extends State<UserInfoEditPage> {
  bool isEditingName = false;
  bool isEditingNickname = false;
  bool isEditingPhone = false;
  bool isEditingEmail = false;

  final nameController = TextEditingController();
  final nicknameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();

  String? profileImageUrl;

  @override
  void initState() {
    super.initState();
    fetchUserInfo();
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
        nameController.text = data['name'] ?? '';
        nicknameController.text = data['nickname'] ?? '';
        phoneController.text = data['phone'] ?? '';
        emailController.text = data['email'] ?? '';
        profileImageUrl = data['profile_image'];
      });
    } else {
      print('사용자 정보 불러오기 실패: ${response.body}');
    }
  }

  // 회원 정보 수정 api
  Future<void> updateUserField(String field, String value) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    if (userId == null) return;

    final response = await http.post(
      Uri.parse('$baseUrl/update_user_field/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'field': field,
        'value': value,
      }),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$field 수정 완료')),
      );
    } else {
      print('수정 실패: ${response.body}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('수정 실패')),
      );
    }
  }

  // 프로필 이미지 저장 api
  Future<void> uploadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/upload_profile_image/'));
      request.fields['user_id'] = userId!;
      request.files.add(await http.MultipartFile.fromPath('image', pickedFile.path));

      var response = await request.send();

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('프로필 이미지 업로드 완료')));
        setState(() {});
        await fetchUserInfo(); // 이미지 다시 불러오기
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('업로드 실패')));
      }
    }
  }

  Future<void> _confirmAndDeleteAccount(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('회원 탈퇴'),
        content: const Text('정말 탈퇴하시겠습니까?\n모든 정보가 삭제됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('아니요'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('예'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');

      if (userId == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인 정보가 없습니다.')),
        );
        return;
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/delete_user/$userId/'),
      );

      print('탈퇴 응답 코드: ${response.statusCode}');
      print('탈퇴 응답 내용: ${response.body}');

      if (response.statusCode == 200) {
        await prefs.clear();

        if (!context.mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('회원 탈퇴가 완료되었습니다.')),
        );

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      } else {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('탈퇴 실패: ${response.body}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('회원 정보 수정'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: Colors.white,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              const SizedBox(height: 12),
              GestureDetector(
                onTap: uploadProfileImage,
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.grey.shade300,
                      backgroundImage: profileImageUrl != null
                          ? NetworkImage(profileImageUrl!) // 프로필 이미지가 있을 경우
                          : null,
                      child: profileImageUrl == null
                          ? const Icon(Icons.person, size: 40, color: Colors.white) // 기본 아이콘
                          : null,
                    ),
                    const SizedBox(height: 8),
                    const Text('사진 업로드', style: TextStyle(fontSize: 14, color: Colors.black)),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              _buildEditableField('이름', nameController, isEditingName,
                      () => setState(() => isEditingName = true),
                      () => setState(() => isEditingName = false)),
              const SizedBox(height: 16),
              _buildEditableField('닉네임', nicknameController, isEditingNickname,
                      () => setState(() => isEditingNickname = true),
                      () => setState(() => isEditingNickname = false)),
              const SizedBox(height: 16),
              _buildEditableField('전화번호', phoneController, isEditingPhone,
                      () => setState(() => isEditingPhone = true),
                      () => setState(() => isEditingPhone = false)),
              const SizedBox(height: 16),
              _buildEditableField('이메일', emailController, isEditingEmail,
                      () => setState(() => isEditingEmail = true),
                      () => setState(() => isEditingEmail = false)),
              const Spacer(),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => _confirmAndDeleteAccount(context),
                  child: const Text(
                    '회원 탈퇴',
                    style: TextStyle(fontSize: 14, color: Colors.red),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditableField(
      String label,
      TextEditingController controller,
      bool isEditing,
      VoidCallback onEdit,
      VoidCallback onDone,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 14, color: Colors.black)),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            isEditing
                ? Expanded(
              child: TextField(
                controller: controller,
                autofocus: true,
                onSubmitted: (_) => onDone(),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                  border: UnderlineInputBorder(),
                ),
              ),
            )
                : Expanded(
              child: Text(
                controller.text,
                style: const TextStyle(fontSize: 16, color: Colors.black),
              ),
            ),
            IconButton(
              icon: Icon(isEditing ? Icons.check : Icons.edit, size: 18, color: Colors.black54),
              onPressed: () async {
                if (isEditing) {
                  await updateUserField(
                    // label에 따라 필드명 맞춤
                    label == '이름' ? 'username' :
                    label == '닉네임' ? 'nickname' :
                    label == '전화번호' ? 'phone' :
                    label == '이메일' ? 'email' : '',
                    controller.text,
                  );
                  onDone();
                } else {
                  onEdit();
                }
              },
            ),
          ],
        ),
        const Divider(thickness: 1, color: Color(0xFFD9D9D9)),
      ],
    );
  }
}