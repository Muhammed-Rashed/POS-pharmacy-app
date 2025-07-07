import 'dart:async';
import 'product.dart';
import 'database_helper.dart';
import 'cart_item.dart';
import 'transaction.dart';

class ConflictResolver {
  /// This method compares local and cloud product versions.
  /// If cloud version is newer, it updates the local database.
  /// If local version is newer, it flags it as unsynced.
  static Future<void> resolveStockConflicts(
    List<Product> localProducts,
    List<Product> cloudProducts,
  ) async {
    final db = DatabaseHelper.instance;

    for (final cloudProduct in cloudProducts) {
      // Try to find a matching product in local database using barcode
      final localProduct = localProducts.firstWhere(
        (p) => p.barcode == cloudProduct.barcode,
        orElse: () => Product(name: '', barcode: '', price: 0, stockQuantity: 0),
      );

      if (localProduct.barcode.isNotEmpty) {
        // Compare last updated times
        if (cloudProduct.lastUpdated.isAfter(localProduct.lastUpdated)) {
          // Cloud version is newer update local database with cloud version
          cloudProduct.id = localProduct.id; // Ensure we keep the local DB ID
          await db.updateProduct(cloudProduct);
        } else if (localProduct.lastUpdated.isAfter(cloudProduct.lastUpdated)) {
          // Local version is newer mark it as unsynced to be uploaded later
          localProduct.isSynced = false;
          await db.updateProduct(localProduct);
        }
        // If both timestamps are equal → no action needed
      }
    }
  }

  /// This method is used when syncing offline sales with the cloud.
  /// It checks if each CartItem can still be fulfilled based on cloud stock.
  /// If not, the item is marked for refund.
  static Future<List<CartItem>> resolveOfflineConflictItems({
    required List<CartItem> items, // List of items sold while offline
    required List<Product> cloudProducts, // Latest product stock from cloud
  }) async {
    List<CartItem> refundableItems = []; // Items that can't be fulfilled

    for (final item in items) {
      // Find the matching product in cloud using productId
      final cloudProduct = cloudProducts.firstWhere(
        (p) => p.id == item.productId,
        orElse: () => Product(name: '', barcode: '', price: 0, stockQuantity: 0),
      );

      // If product doesn't exist or not enough stock refund required
      if (cloudProduct.id == null || cloudProduct.stockQuantity < item.quantity) {
        refundableItems.add(item);
      } else {
        // Product is valid and has enough stock reduce stock
        cloudProduct.stockQuantity -= item.quantity;
      }
    }

    return refundableItems;
  }
}
