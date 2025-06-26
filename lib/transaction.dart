import 'dart:convert';
import 'cart_item.dart';

class PosTransaction {
  int? id;
  List<CartItem> items;
  bool? isRefund;
  int? originalTransactionId;
  double totalAmount;
  DateTime timestamp;
  bool isSynced;
  String? cloudId;

  PosTransaction({
    this.id,
    required this.items,
    required this.totalAmount,
    required this.timestamp,
    this.isSynced = false,
    this.cloudId,
    this.isRefund,
    this.originalTransactionId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'items': jsonEncode(items.map((item) => item.toMap()).toList()),
      'total_amount': totalAmount,
      'timestamp': timestamp.toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
      'cloud_id': cloudId,
      'isRefund': (isRefund ?? false) ? 1 : 0,
      'originalTransactionId': originalTransactionId,
    };
  }

  factory PosTransaction.fromMap(Map<String, dynamic> map) {
    List<dynamic> itemsJson = jsonDecode(map['items']);
    List<CartItem> items = itemsJson.map((item) => CartItem.fromMap(item)).toList();
    
    return PosTransaction(
      id: map['id'],
      items: items,
      totalAmount: map['total_amount'],
      timestamp: DateTime.parse(map['timestamp']),
      isSynced: map['is_synced'] == 1,
      cloudId: map['cloud_id'],
      isRefund: (map['isRefund'] ?? 0) == 1,
      originalTransactionId: map['originalTransactionId']?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': cloudId,
      'items': items.map((item) => item.toJson()).toList(),
      'total_amount': totalAmount,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory PosTransaction.fromJson(Map<String, dynamic> json) {
    List<dynamic> itemsJson = json['items'];
    List<CartItem> items = itemsJson.map((item) => CartItem.fromJson(item)).toList();
    
    return PosTransaction(
      items: items,
      totalAmount: json['total_amount'].toDouble(),
      timestamp: DateTime.parse(json['timestamp']),
      isSynced: true,
      cloudId: json['id'].toString(),
      
    );
  }
}