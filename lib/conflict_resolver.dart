import 'dart:async';
import 'product.dart';
import 'database_helper.dart';
import 'cart_item.dart';
import 'transaction.dart';

class ConflictResolver {
  static Future<void> resolveStockConflicts(List<Product> localProducts, List<Product> cloudProducts) async {
    final db = DatabaseHelper.instance;

    for (final cloudProduct in cloudProducts) {
      final localProduct = localProducts.firstWhere(
        (p) => p.barcode == cloudProduct.barcode,
        orElse: () => Product(name: '', barcode: '', price: 0, stockQuantity: 0),
      );

      if (localProduct.barcode.isNotEmpty) {
        if (cloudProduct.lastUpdated.isAfter(localProduct.lastUpdated)) {
          cloudProduct.id = localProduct.id;
          await db.updateProduct(cloudProduct);
        } else if (localProduct.lastUpdated.isAfter(cloudProduct.lastUpdated)) {
          localProduct.isSynced = false;
          await db.updateProduct(localProduct);
        }
      }
    }
  }

  static Future<List<CartItem>> resolveOfflineConflictItems({
    required List<CartItem> items,
    required List<Product> cloudProducts,
  }) async {
    List<CartItem> refundableItems = [];

    for (final item in items) {
      final cloudProduct = cloudProducts.firstWhere(
        (p) => p.id == item.productId,
        orElse: () => Product(name: '', barcode: '', price: 0, stockQuantity: 0),
      );

      if (cloudProduct.id == null || cloudProduct.stockQuantity < item.quantity) {
        refundableItems.add(item);
      } else {
        cloudProduct.stockQuantity -= item.quantity;
      }
    }

    return refundableItems;
  }
}
