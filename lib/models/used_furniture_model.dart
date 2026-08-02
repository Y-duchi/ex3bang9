class UsedFurniture {
  final int postId;
  final String userId;
  final String? nickname;
  final String title;
  final String content;
  final int price;
  final String category;
  final String address;
  final String? detailAddress;
  final String transactionType;
  final bool isDirectTrade;
  final bool isSold;
  final String createdAt;
  final List<String> imageUrls;
  final double latitude;
  final double longitude;
  final String email;
  int views;

  UsedFurniture({
    required this.postId,
    required this.userId,
    required this.nickname,
    required this.title,
    required this.content,
    required this.price,
    required this.category,
    required this.address,
    required this.detailAddress,
    required this.transactionType,
    required this.isDirectTrade,
    required this.isSold,
    required this.createdAt,
    required this.imageUrls,
    required this.latitude,
    required this.longitude,
    required this.email,
    required this.views,
  });

  factory UsedFurniture.fromJson(Map<String, dynamic> json) {
    return UsedFurniture(
      postId: json['post_id'],
      userId: json['user_id'],
      nickname: json['nickname'],
      title: json['title'],
      content: json['content'],
      price: json['price'],
      category: json['category'],
      address: json['address'],
      detailAddress: json['detail_address'],
      transactionType: json['transaction_type'],
      isDirectTrade: json['is_direct_trade'],
      isSold: json['is_sold'],
      createdAt: json['created_at'],
      imageUrls: (json['images'] as List<dynamic>?)
          ?.map((img) => img['image_url'] as String)
          .toList() ??
          [],
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      email: json['email'],
      views: json['views'] ?? 0,
    );
  }
}