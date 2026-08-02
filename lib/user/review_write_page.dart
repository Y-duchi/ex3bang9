import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import '../constants.dart';

class ReviewWritePage extends StatefulWidget {
  final bool isEditing;
  final Map<String, dynamic>? existingReview;
  final String optionId;
  final String productName;
  final String color;
  final String size;
  final String productImageUrl;

  const ReviewWritePage({
    super.key,
    this.isEditing = false,
    this.existingReview,
    required this.optionId,
    required this.productName,
    required this.color,
    required this.size,
    required this.productImageUrl,
  });

  @override
  State<ReviewWritePage> createState() => _ReviewWritePageState();
}

class _ReviewWritePageState extends State<ReviewWritePage> {
  int selectedStars = 0;
  final TextEditingController _reviewController = TextEditingController();
  final List<XFile> selectedImages = [];
  List<String> existingImageUrls = [];

  @override
  void initState() {
    super.initState();
    if (widget.isEditing && widget.existingReview != null) {
      selectedStars = widget.existingReview!['rating']?.toInt() ?? 0;
      _reviewController.text = widget.existingReview!['content'] ?? '';
      existingImageUrls = List<String>.from(widget.existingReview!['review_images'] ?? []);
    }
  }

  Future<void> pickImages(BuildContext context) async {
    final picker = ImagePicker();
    final List<XFile>? images = await picker.pickMultiImage();

    if (images != null) {
      if (selectedImages.length + existingImageUrls.length + images.length > 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('최대 3장까지 업로드 가능합니다.')),
        );
        return;
      }
      setState(() {
        selectedImages.addAll(images);
      });
    }
  }

  Future<void> submitReview(BuildContext context) async {
    if (_reviewController.text.trim().length < 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('본문을 20자 이상 작성해주세요.')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? '';

    if (widget.isEditing) {
      final uri = Uri.parse('$baseUrl/update_new_review/${widget.existingReview!['new_review_id']}/');
      final response = await http.put(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: JsonEncoder().convert({
          'user_id': userId,
          'rating': selectedStars,
          'content': _reviewController.text,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('리뷰가 수정되었습니다.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('리뷰 수정에 실패했습니다.')),
        );
      }
    } else {
      final uri = Uri.parse('$baseUrl/create_new_furniture_review/');
      final request = http.MultipartRequest('POST', uri)
        ..fields['user_id'] = userId
        ..fields['option_id'] = widget.optionId
        ..fields['rating'] = selectedStars.toString()
        ..fields['content'] = _reviewController.text;

      for (var image in selectedImages) {
        request.files.add(await http.MultipartFile.fromPath(
          'images',
          image.path,
          filename: basename(image.path),
        ));
      }

      final response = await request.send();

      if (!mounted) return;

      if (response.statusCode == 201) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('리뷰가 등록되었습니다.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('리뷰 등록에 실패했습니다.')),
        );
      }
    }
  }

  Widget buildStarRating() {
    return Row(
      children: List.generate(5, (index) {
        return IconButton(
          icon: Icon(
            index < selectedStars ? Icons.star : Icons.star_border,
            color: Colors.amber,
          ),
          onPressed: () {
            setState(() {
              selectedStars = index + 1;
            });
          },
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('후기 작성', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: Colors.white,
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () => submitReview(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF916636),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(widget.isEditing ? '수정 완료' : '작성 완료', style: const TextStyle(fontSize: 16)),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('이 상품 어떠셨나요?', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: widget.productImageUrl.isNotEmpty
                      ? Image.network(
                    widget.productImageUrl,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                  )
                      : Container(
                    width: 60,
                    height: 60,
                    color: Colors.grey[300],
                    child: const Icon(Icons.image_not_supported),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.productName, style: const TextStyle(fontSize: 14)),
                    Text('${widget.color} / ${widget.size}', style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            buildStarRating(),
            const SizedBox(height: 16),
            const Text('어떤 점이 좋았나요?', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            const Text('본문 입력 (필수)', style: TextStyle(fontSize: 16)),
            TextField(
              controller: _reviewController,
              maxLines: 5,
              maxLength: 300,
              decoration: const InputDecoration(
                hintText: '다른 회원들도 도움이 될 수 있도록 상품에 대한 의견을 자세히 작성해 주세요.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text('사진 첨부', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...existingImageUrls.map((url) => Stack(
                  children: [
                    Image.network(url, width: 80, height: 100, fit: BoxFit.cover),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            existingImageUrls.remove(url);
                          });
                        },
                        child: const Icon(Icons.cancel, color: Colors.red, size: 18),
                      ),
                    )
                  ],
                )),
                ...selectedImages.map((img) => Image.file(
                  File(img.path),
                  width: 80,
                  height: 100,
                  fit: BoxFit.cover,
                )),
                if (selectedImages.length + existingImageUrls.length < 3)
                  GestureDetector(
                    onTap: () => pickImages(context),
                    child: Container(
                      width: 80,
                      height: 100,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                      ),
                      child: Center(child: Text('+ ${selectedImages.length + existingImageUrls.length}/3')),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}