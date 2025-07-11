class Product {
  int? id;
  String name;
  String barcode;
  double price;
  int stockQuantity;
  DateTime lastUpdated;
  bool isSynced;

  // 'id' is only used locally in SQLite
  // 'barcode' is used as Firestore doc ID


  Product({
    this.id,
    required this.name,
    required this.barcode,
    required this.price,
    required this.stockQuantity,
    DateTime? lastUpdated,
    this.isSynced = false,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'barcode': barcode,
      'price': price,
      'stock_quantity': stockQuantity,
      'last_updated': lastUpdated.toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      name: map['name'],
      barcode: map['barcode'],
      price: map['price'],
      stockQuantity: map['stock_quantity'],
      lastUpdated: DateTime.parse(map['last_updated']),
      isSynced: map['is_synced'] == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'barcode': barcode,
      'price': price,
      'stock_quantity': stockQuantity,
      'last_updated': lastUpdated.toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      name: json['name'],
      barcode: json['barcode'],
      price: json['price'].toDouble(),
      stockQuantity: json['stock_quantity'],
      lastUpdated: DateTime.parse(json['last_updated']),
      isSynced: true,
    );
  }

  factory Product.fromFirestore(Map<String, dynamic> data) {
    return Product(
      id: null,
      name: data['name'],
      barcode: data['barcode'],
      price: (data['price'] as num).toDouble(),
      stockQuantity: data['stock_quantity'],
      lastUpdated: DateTime.tryParse(data['last_updated']) ?? DateTime.now(),
      isSynced: true,
    );
  }

}