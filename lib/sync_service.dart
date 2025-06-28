import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'database_helper.dart';
import 'product.dart';
import 'transaction.dart';
import 'conflict_resolver.dart';

class SyncService {
  static const String baseUrl = 'https://your-api-endpoint.com/api'; // not used here
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<void> performSync() async {
    try {
      print('🔄 Starting sync process...');

      await syncTransactionsToCloud();
      await syncProductsFromCloud();
      await syncStockUpdatesToCloud();
      await _updateLastSyncTime();

      print('✅ Sync completed successfully');
    } catch (e) {
      print('❌ Sync failed: $e');
    }
  }

  Future<String> manualSync(BuildContext context) async {
    try {
      await performSync();
      _showSnackBar(context, 'Sync completed successfully.');
      return 'Sync completed';
    } catch (e) {
      _showSnackBar(context, 'Sync failed: $e', isError: true);
      return 'Sync failed';
    }
  }

  void _showSnackBar(BuildContext context, String message, {bool isError = false}) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
        ),
      );
    }
  }

  Future<void> _updateLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_sync_time', DateTime.now().toIso8601String());
  }

  Future<void> logSyncActivity(String result) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_sync_result', result);
    await prefs.setString('last_sync_time', DateTime.now().toIso8601String());
  }

  Future<String?> getLastSyncResult() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('last_sync_result');
  }

  Future<void> schedulePeriodicSync() async {
    // WorkManager plugin would be needed
  }

  // 🔁 PUSH unsynced local transactions to Firestore
  Future<void> syncTransactionsToCloud() async {
    final unsynced = await _db.getUnsyncedTransactions();

    for (final tx in unsynced) {
      final doc = await firestore.collection('transactions').add(tx.toMap());
      await _db.markTransactionAsSynced(tx.id!, doc.id);
      print("☁️ Synced transaction ${tx.id} to Firestore");
    }
  }

  // 🔁 PULL Firestore products and resolve conflict
  Future<void> syncProductsFromCloud() async {
    final cloudSnapshot = await firestore.collection('products').get();
    final localProducts = await _db.getProducts();

    List<Product> cloudProducts = cloudSnapshot.docs.map((doc) {
      final data = doc.data();
      return Product(
        id: null,
        name: data['name'],
        barcode: data['barcode'],
        price: (data['price'] as num).toDouble(),
        stockQuantity: data['stock_quantity'],
        lastUpdated: DateTime.parse(data['last_updated']),
        isSynced: true,
      );
    }).toList();

    await ConflictResolver.resolveStockConflicts(localProducts, cloudProducts);
  }

  // 🔁 PUSH local unsynced products to Firestore
  Future<void> syncStockUpdatesToCloud() async {
    final unsynced = await _db.getUnsyncedProducts();

    for (final product in unsynced) {
      await firestore.collection('products').doc(product.barcode).set({
        'name': product.name,
        'barcode': product.barcode,
        'price': product.price,
        'stock_quantity': product.stockQuantity,
        'last_updated': product.lastUpdated.toIso8601String(),
      });

      await _db.markProductAsSynced(product.id!);
      print("☁️ Synced ${product.name} to Firestore");
    }
  }
}
