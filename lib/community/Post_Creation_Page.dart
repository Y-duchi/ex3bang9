/// 글작성 페이지
///
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';
import 'Drafts_Page.dart';

class PostCreationPage extends StatefulWidget {
  final String? initialTitle;
  final String? initialContent;
  final int? postId;

  // 🟡 추가: draft 불러올 때 이미지 url 리스트 받기
  final List<String>? imageUrls;

  const PostCreationPage({
    super.key,
    this.initialTitle,
    this.initialContent,
    this.postId,
    this.imageUrls,
  });

  @override
  State<PostCreationPage> createState() => _PostCreationPageState();
}

class _PostCreationPageState extends State<PostCreationPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  List<File> _selectedImages = [];
  List<String> _networkImages = []; // ✅ 네트워크 이미지 리스트
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.initialTitle ?? '';
    _contentController.text = widget.initialContent ?? '';
    if (widget.imageUrls != null) {
      _networkImages = widget.imageUrls!;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final List<XFile> pickedFiles = await _picker.pickMultiImage();
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(pickedFiles.map((xfile) => File(xfile.path)));
      });
    }
  }

  Future<void> _uploadPost() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목과 내용을 입력해주세요')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다')),
      );
      return;
    }

    final isEditing = widget.postId != null;
    final uri = isEditing
        ? Uri.parse('$baseUrl/community/posts/${widget.postId}/')
        : Uri.parse('$baseUrl/community/posts/');

    final request = http.MultipartRequest(isEditing ? 'PUT' : 'POST', uri)
      ..fields['title'] = title
      ..fields['content'] = content
      ..fields['user_id'] = userId;

    // ✅ 새로 선택한 이미지
    for (var imageFile in _selectedImages) {
      request.files.add(await http.MultipartFile.fromPath('images', imageFile.path));
    }

    // ✅ 임시글에서 불러온 이미지 URL → 파일로 다시 업로드
    for (var url in _networkImages) {
      final response = await http.get(Uri.parse(url));
      final bytes = response.bodyBytes;
      final fileName = url.split('/').last;

      request.files.add(
        http.MultipartFile.fromBytes(
          'images',
          bytes,
          filename: fileName,
        ),
      );
    }

    final response = await request.send();

    if (response.statusCode == 200 || response.statusCode == 201) {
      final respStr = await response.stream.bytesToString();
      final post = jsonDecode(respStr);

      Navigator.of(context).pop(<String, String>{
        'title': post['title'] ?? '',
        'content': post['content'] ?? '',
        'date': (post['created_at'] ?? '').split('T')[0],
        'likes': '0',
        'comments': '0',
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('업로드 실패: ${response.statusCode}')),
      );
    }
  }

  Future<void> _saveDraft() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("제목과 내용을 입력해주세요")),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("로그인이 필요합니다")),
      );
      return;
    }

    final uri = Uri.parse('$baseUrl/community/drafts/');
    final request = http.MultipartRequest('POST', uri)
      ..fields['title'] = title
      ..fields['content'] = content
      ..fields['user_id'] = userId;

    for (var imageFile in _selectedImages) {
      request.files.add(await http.MultipartFile.fromPath('images', imageFile.path));
    }

    final response = await request.send();

    if (response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("임시저장되었습니다")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("임시저장 실패: ${response.statusCode}")),
      );
    }
  }

  Future<void> _goToDraftsPage() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("로그인이 필요합니다")),
      );
      return;
    }

    final response = await http.get(
      Uri.parse('$baseUrl/community/drafts/?user_id=$userId'),
    );

    if (response.statusCode == 200) {
      final decoded = utf8.decode(response.bodyBytes);
      final List<dynamic> draftList = jsonDecode(decoded);

      final draft = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (context) => DraftsPage(drafts: draftList.cast<Map<String, dynamic>>()),
        ),
      );

      if (draft != null) {
        setState(() {
          _titleController.text = draft['title'] ?? '';
          _contentController.text = draft['content'] ?? '';
          _networkImages = (draft['image_urls'] as List<dynamic>?)?.cast<String>() ?? [];
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("임시글을 불러왔습니다")),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("임시글 불러오기 실패: ${response.statusCode}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final allImagesWidgets = [
      ..._networkImages.map((url) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          width: MediaQuery.of(context).size.width * 0.4,
          fit: BoxFit.cover,
        ),
      )),
      ..._selectedImages.map((file) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          file,
          width: MediaQuery.of(context).size.width * 0.4,
          fit: BoxFit.cover,
        ),
      )),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 상단바
            Container(
              height: 44,
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Text(
                    '게시글 작성',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: _uploadPost,
                    child: const Text(
                      '업로드',
                      style: TextStyle(
                        color: Color(0xFFAA7D48),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 80,
                  top: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 제목
                    Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black.withOpacity(0.26)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: '제목',
                          hintStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 내용
                    Container(
                      height: 200,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black.withOpacity(0.26)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextField(
                        controller: _contentController,
                        maxLines: null,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: '글작성',
                          hintStyle: TextStyle(fontSize: 15, color: Colors.black54),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (allImagesWidgets.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: allImagesWidgets,
                      ),
                  ],
                ),
              ),
            ),
            // 하단 버튼
            Container(
              height: 60,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.camera_alt, color: Colors.black),
                    onPressed: _pickImages,
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: _saveDraft,
                        child: const Text(
                          '임시저장',
                          style: TextStyle(
                            color: Color(0xFF444444),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _goToDraftsPage,
                        child: const Text(
                          '임시글 보기',
                          style: TextStyle(
                            color: Color(0xFF444444),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}