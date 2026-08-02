class FurnitureOptions {
  final String optionId;
  final int productId;
  final String size;
  final String color;
  final int price;
  final int stock;

  FurnitureOptions({
    required this.optionId,
    required this.productId,
    required this.size,
    required this.color,
    required this.price,
    required this.stock,
  });

  factory FurnitureOptions.fromJson(Map<String, dynamic> json) {
    return FurnitureOptions(
      optionId: json['option_id'],
      productId: json['product_id'],
      size: json['size'],
      color: json['color'],
      price: json['price'],
      stock: json['stock'],
    );
  }
}