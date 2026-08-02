/// 임시저장 페이지

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DraftsPage extends StatefulWidget {
  final List<Map<String, dynamic>>? drafts;

  const DraftsPage({super.key, this.drafts});

  @override
  State<DraftsPage> createState() => _DraftsPageState();
}

class _DraftsPageState extends State<DraftsPage> {
  List<Map<String, dynamic>> _drafts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.drafts == null) {
      _loadDrafts();
    } else {
      _drafts = widget.drafts!;
      _isLoading = false;
    }
  }

  Future<void> _loadDrafts() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');

    if (userId == null) return;

    final response = await http.get(
      Uri.parse('$baseUrl/community/drafts/?user_id=$userId'),
    );

    if (response.statusCode == 200) {
      final decoded = utf8.decode(response.bodyBytes);
      final List<dynamic> result = jsonDecode(decoded);
      setState(() {
        _drafts = result.map((e) => Map<String, dynamic>.from(e)).toList();
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("임시글 불러오기 실패: ${response.statusCode}")),
      );
    }
  }

  Future<void> _deleteDraft(int draftId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/community/drafts/$draftId/'),
    );

    if (response.statusCode == 204) {
      setState(() {
        _drafts.removeWhere((draft) => draft['id'] == draftId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("임시글이 삭제되었습니다")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("삭제 실패: ${response.statusCode}")),
      );
    }
  }

  Widget _buildImageThumbnails(List<String> imageUrls) {
    return Row(
      children: imageUrls.take(3).map((url) {
        return Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: Image.network(
            url,
            width: 50,
            height: 50,
            fit: BoxFit.cover,
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('임시글 목록')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _drafts.isEmpty
          ? const Center(child: Text("저장된 임시글이 없습니다"))
          : ListView.builder(
        itemCount: _drafts.length,
        itemBuilder: (context, index) {
          final draft = _drafts[index];

          // ✅ 여기서 image_url 리스트 파싱
          final List<dynamic> imageObjs = draft['images'] ?? [];
          final List<String> imageUrls = imageObjs
              .map((e) => e['image_url'] as String?)
              .where((url) => url != null)
              .cast<String>()
              .toList();

          return ListTile(
            title: Text(draft['title'] ?? ''),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  draft['content'] ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (imageUrls.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildImageThumbnails(imageUrls),
                ],
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteDraft(draft['id']),
            ),
            onTap: () {
              Navigator.pop<Map<String, dynamic>>(context, {
                'title': draft['title'] ?? '',
                'content': draft['content'] ?? '',
                'image_urls': imageUrls,
              });
            },
          );
        },
      ),
    );
  }
}