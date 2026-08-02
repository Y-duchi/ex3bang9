import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';

// 좋아요 상태 변경
Future<void> toggleFavorite({
  required int productId,
  required String contentType,
  required bool isFavorited,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final userId = prefs.getString('user_id');
  if (userId == null) return;

  await http.post(
    Uri.parse('$baseUrl/favorite_items/'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'user_id': userId,
      'content_type': contentType,
      'furniture_id': productId,
      'is_favorited': isFavorited,
    }),
  );
}
// 좋아요 개수
Future<int> fetchLikeCount(int furnitureId, String contentType) async {
  final url = Uri.parse('$baseUrl/favorite/count/?furniture_id=$furnitureId&content_type=$contentType');
  final response = await http.get(url);

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return data['like_count'] ?? 0;
  } else {
    throw Exception('좋아요 수 불러오기 실패: ${response.statusCode}');
  }
}

