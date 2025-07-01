class CartItem {
  int productId;
  String productName;
  String barcode;
  double price;
  int quantity;

  CartItem({
    required this.productId,
    required this.productName,
    required this.barcode,
    required this.price,
    required this.quantity,
  });

  Map<String, dynamic> toMap() {
    return {
      'product_id': productId,
      'product_name': productName,
      'barcode': barcode,
      'price': price,
      'quantity': quantity,
    };
  }

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      productId: map['product_id'],
      productName: map['product_name'],
      barcode: map['barcode'],
      price: map['price'],
      quantity: map['quantity'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'product_name': productName,
      'barcode': barcode,
      'price': price,
      'quantity': quantity,
    };
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      productId: json['product_id'] ?? 0,
      productName: json['product_name'] ?? 'Unknown Product',
      barcode: json['barcode'] ?? 'UNKNOWN',
      price: (json['price'] is num) ? (json['price'] as num).toDouble() : 0.0,
      quantity: json['quantity'] ?? 0,
    );
  }
}
