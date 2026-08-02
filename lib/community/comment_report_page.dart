/// 댓글신고 페이지

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants.dart';

class CommentReportPage extends StatefulWidget {
  final int commentId;
  final String reporterEmail;

  const CommentReportPage({
    super.key,
    required this.commentId,
    required this.reporterEmail,
  });

  @override
  State<CommentReportPage> createState() => _CommentReportPageState();
}

class _CommentReportPageState extends State<CommentReportPage> {
  final List<String> reasons = [
    '스팸홍보/도배글입니다',
    '불법정보를 포함하고 있습니다',
    '청소년에게 유해한 내용입니다',
    '욕설/생명경시/차별적 표현입니다',
    '개인정보 노출 게시물입니다',
    '불쾌한 표현이 있습니다'
        '기타 부적절한 행위가 있어요',
    '작성자 신고하기',
  ];

  String? selectedReason;
  final TextEditingController contentController = TextEditingController();
  bool isSubmitting = false;

  @override
  void dispose() {
    contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (selectedReason == null || contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('신고 사유와 내용을 모두 입력해주세요.')),
      );
      return;
    }

    setState(() => isSubmitting = true);

    final url = Uri.parse('$baseUrl/report/comment/');
    final payload = {
      'comment_id': widget.commentId,
      'reporter_email': widget.reporterEmail,
      'reason': selectedReason,
      'content': contentController.text.trim(),
    };


    print('[신고 요청] $payload');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      print('[응답 상태] ${response.statusCode}');
      print('[응답 본문] ${response.body}');

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('신고가 접수되었습니다.')),
        );
        Navigator.pop(context);
      } else {
        final error = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('신고 실패: ${error['detail'] ?? '서버 오류'}')),
        );
      }
    } catch (e) {
      print('[요청 에러] $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('요청 중 오류가 발생했습니다.')),
      );
    }

    setState(() => isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('신고하기', style: TextStyle(color: Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: const BackButton(color: Colors.black),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              '게시글을 신고하는 이유를 선택해주세요.',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: selectedReason,
              hint: const Text('신고 사유 선택'),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: (v) => setState(() => selectedReason = v),
            ),
            const SizedBox(height: 24),
            const Text(
              '내용 (필수)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: contentController,
              maxLines: 8,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: '신고 내용을 입력해주세요.',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        child: ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8B6439),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('신고하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}