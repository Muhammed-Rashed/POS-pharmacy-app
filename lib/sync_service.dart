import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'database_helper.dart';
import 'product.dart';
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

    if (unsynced.isEmpty) return;

    final cloudSnapshot = await firestore.collection('products').get();
    final cloudProducts = cloudSnapshot.docs.map((doc) {
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

    for (final tx in unsynced) {
      final refundableItems = await ConflictResolver.resolveOfflineConflictItems(
        items: tx.items,
        cloudProducts: cloudProducts,
      );

      if (refundableItems.isEmpty) {
        final doc = await firestore.collection('transactions').add(tx.toMap());
        await _db.markTransactionAsSynced(tx.id!, doc.id);
        print("☁️ Synced transaction ${tx.id} to Firestore");
      } else {
        print("⚠️ Conflict in transaction ${tx.id}. Refund required for:");
        for (final item in refundableItems) {
          print("- ${item.productName} x${item.quantity}");
        }

        // ❗ Trigger refund logic
        // Option 1: Automatically create a refund transaction
        // Option 2: Queue for user resolution with a dialog
      }
    }
  }

  // PULL Firestore products and resolve conflict
  Future<void> syncProductsFromCloud() async {
    final cloudSnapshot = await firestore.collection('products').get();
    final db = await _db.database;

    for (final doc in cloudSnapshot.docs) {
      final data = doc.data();
      final barcode = data['barcode'];
      
      final localProduct = await _db.getProductByBarcode(barcode);

      final updatedProduct = Product(
        id: localProduct?.id, // Use local ID if exists
        name: data['name'],
        barcode: barcode,
        price: (data['price'] as num).toDouble(),
        stockQuantity: data['stock_quantity'],
        lastUpdated: DateTime.parse(data['last_updated']),
        isSynced: true,
      );

      if (localProduct == null) {
        await _db.insertProduct(updatedProduct);
      } else {
        await _db.updateProduct(updatedProduct);
      }
    }

    print("⬇️ Local DB updated from Firestore (cloud is source of truth)");
  }


  // PUSH local unsynced products to Firestore
  Future<void> syncStockUpdatesToCloud() async {
    final unsynced = await _db.getUnsyncedProducts();

    for (final localProduct in unsynced) {
      final cloudDoc = await firestore.collection('products').doc(localProduct.barcode).get();

      if (cloudDoc.exists) {
        final cloudData = cloudDoc.data()!;
        final cloudTime = DateTime.parse(cloudData['last_updated']);

        // Skip if cloud version is newer
        if (cloudTime.isAfter(localProduct.lastUpdated)) {
          print("⚠️ Skipped syncing ${localProduct.name} due to newer cloud version");
          continue;
        }
      }

      // Push local data to cloud
      await firestore.collection('products').doc(localProduct.barcode).set({
        'name': localProduct.name,
        'barcode': localProduct.barcode,
        'price': localProduct.price,
        'stock_quantity': localProduct.stockQuantity,
        'last_updated': localProduct.lastUpdated.toIso8601String(),
      });

      await _db.markProductAsSynced(localProduct.id!);
      print("☁️ Synced ${localProduct.name} to Firestore");
    }
  }

}
