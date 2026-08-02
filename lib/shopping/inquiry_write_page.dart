import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import '../constants.dart';

class InquiryWritePage extends StatefulWidget {
  final bool isEditing;
  final Map<String, dynamic>? existingInquiry;
  final String productImageUrl;
  final String productName;
  final int productPrice;
  final String option;
  final List<String> existingImages;
  final int productId;

  const InquiryWritePage({
    super.key,
    this.isEditing = false,
    this.existingInquiry,
    required this.productImageUrl,
    required this.productName,
    required this.productPrice,
    required this.option,
    required this.existingImages,
    required this.productId,
  });

  @override
  State<InquiryWritePage> createState() => _InquiryWritePageState();
}

class _InquiryWritePageState extends State<InquiryWritePage> {
  String selectedType = '';
  String? selectedOptionId;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final List<XFile> selectedImages = [];
  List<String> existingImageUrls = [];
  List<Map<String, dynamic>> options = [];
  bool isPrivate = false;

  Future<void> fetchOptions() async {
    final url = Uri.parse('$baseUrl/get_furniture_options/${widget.productId}/');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      setState(() {
        options = data.map((e) => {
          'id': e['option_id'].toString(),
          'label': '${e['color']} / ${e['size']}',
        }).toList();
      });
    }
  }

  Future<void> pickImages() async {
    final picker = ImagePicker();
    final List<XFile>? images = await picker.pickMultiImage();

    if (images != null) {
      if (selectedImages.length + existingImageUrls.length + images.length > 10) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('최대 10장까지 업로드 가능합니다.')),
        );
        return;
      }
      setState(() {
        selectedImages.addAll(images);
      });
    }
  }

  Future<void> submitInquiry() async {
    if (selectedType.isEmpty || _titleController.text.trim().isEmpty || _contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('필수 항목을 모두 입력해 주세요.')),
      );
      return;
    }
    if (selectedOptionId == null || selectedOptionId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('옵션을 선택해 주세요.')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? '';

    if (widget.isEditing) {
      final uri = Uri.parse('$baseUrl/update_inquiry/${widget.existingInquiry!['inquiry_id']}/');
      final response = await http.put(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'title': _titleController.text,
          'content': _contentController.text,
          'inquiry_type': selectedType,
          'is_private': isPrivate.toString(),
        }),
      );

      if (response.statusCode == 200) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('문의가 수정되었습니다.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('문의 수정에 실패했습니다.')),
        );
      }
    } else {
      final uri = Uri.parse('$baseUrl/create_inquiry/');
      final request = http.MultipartRequest('POST', uri)
        ..fields['option_id'] = selectedOptionId ?? ''
        ..fields['user_id'] = userId
        ..fields['product_id'] = widget.productId.toString()
        ..fields['inquiry_type'] = selectedType
        ..fields['title'] = _titleController.text
        ..fields['content'] = _contentController.text
        ..fields['is_private'] = isPrivate ? 'true' : 'false';

      for (var image in selectedImages) {
        request.files.add(await http.MultipartFile.fromPath(
          'images',
          image.path,
          filename: p.basename(image.path),
        ));
      }

      final response = await request.send();

      if (response.statusCode == 201) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('문의가 등록되었습니다.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('문의 등록에 실패했습니다.')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    fetchOptions();
    if (widget.isEditing && widget.existingInquiry != null) {
      selectedType = widget.existingInquiry!['inquiry_type'] ?? '';
      selectedOptionId = widget.existingInquiry!['option_id']?.toString();
      _titleController.text = widget.existingInquiry!['title'] ?? '';
      _contentController.text = widget.existingInquiry!['content'] ?? '';
      isPrivate = widget.existingInquiry!['is_private'].toString() == 'true';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? '문의 수정' : '문의 작성'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    widget.productImageUrl,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey[300],
                      child: const Icon(Icons.image_not_supported),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.productName, style: const TextStyle(fontSize: 14)),
                    Text('${widget.productPrice}원', style: const TextStyle(fontSize: 12)),
                    Text(widget.option, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedType.trim().isEmpty ? null : selectedType.trim(),
              hint: const Text('문의 유형 선택'),
              items: ['배송', '상품', '재입고', '기타']
                  .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                  .toList(),
              onChanged: (val) => setState(() => selectedType = val ?? ''),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedOptionId,
              hint: const Text('옵션 선택'),
              items: options.map((option) {
                return DropdownMenuItem<String>(
                  value: option['id'],
                  child: Text(option['label']),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  selectedOptionId = val;
                });
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: '제목'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _contentController,
              maxLines: 5,
              decoration: const InputDecoration(labelText: '내용'),
            ),
            CheckboxListTile(
              value: isPrivate,
              onChanged: (val) => setState(() => isPrivate = val ?? false),
              title: const Text('비밀글'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...selectedImages.map((img) => Image.file(File(img.path), width: 80, height: 100)),
                if (selectedImages.length < 10)
                  GestureDetector(
                    onTap: pickImages,
                    child: Container(
                      width: 80,
                      height: 100,
                      color: Colors.grey[300],
                      child: const Icon(Icons.add),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: submitInquiry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF916636),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(widget.isEditing ? '수정 완료' : '작성 완료'),
                )
            ),
          ],
        ),
      ),
    );
  }
}