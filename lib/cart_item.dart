class CartItem {
  int productId;
  String productName;
  String barcode; // ✅ New field
  double price;
  int quantity;

  CartItem({
    required this.productId,
    required this.productName,
    required this.barcode, // ✅ Add here
    required this.price,
    required this.quantity,
  });

  Map<String, dynamic> toMap() {
    return {
      'product_id': productId,
      'product_name': productName,
      'barcode': barcode, // ✅ Add here
      'price': price,
      'quantity': quantity,
    };
  }

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      productId: map['product_id'],
      productName: map['product_name'],
      barcode: map['barcode'], // ✅ Add here
      price: map['price'],
      quantity: map['quantity'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'product_name': productName,
      'barcode': barcode, // ✅ Add here
      'price': price,
      'quantity': quantity,
    };
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      productId: json['product_id'],
      productName: json['product_name'],
      barcode: json['barcode'], // ✅ Add here
      price: json['price'].toDouble(),
      quantity: json['quantity'],
    );
  }
}
