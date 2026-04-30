class CartItem {
  final int productId;
  final String name;
  final double price;
  final int quantity;

  CartItem({
    required this.productId,
    required this.name,
    required this.price,
    this.quantity = 1,
  });

  double get lineTotal => price * quantity;

  CartItem copyWith({int? productId, String? name, double? price, int? quantity}) {
    return CartItem(
      productId: productId ?? this.productId,
      name:      name      ?? this.name,
      price:     price     ?? this.price,
      quantity:  quantity  ?? this.quantity,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is CartItem && productId == other.productId;

  @override
  int get hashCode => productId.hashCode;
}
