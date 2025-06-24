import 'product.dart';
import 'database_helper.dart';

class ConflictResolver {
  static Future<void> resolveStockConflicts(List<Product> localProducts, List<Product> cloudProducts) async {
    final db = DatabaseHelper.instance;
    
    for (final cloudProduct in cloudProducts) {
      final localProduct = localProducts.firstWhere(
        (p) => p.barcode == cloudProduct.barcode,
        orElse: () => Product(name: '', barcode: '', price: 0, stockQuantity: 0),
      );
      
      if (localProduct.barcode.isNotEmpty) {
        // Conflict resolution strategy: Last update wins
        if (cloudProduct.lastUpdated.isAfter(localProduct.lastUpdated)) {
          // Cloud version is newer
          cloudProduct.id = localProduct.id;
          await db.updateProduct(cloudProduct);
          print('Resolved conflict for ${cloudProduct.name}: Used cloud version');
        } else if (localProduct.lastUpdated.isAfter(cloudProduct.lastUpdated)) {
          // Local version is newer, keep local but mark for sync
          localProduct.isSynced = false;
          await db.updateProduct(localProduct);
          print('Resolved conflict for ${localProduct.name}: Kept local version');
        }
        // If timestamps are equal, keep local version
      }
    }
  }

  static Future<Product> mergeProductData(Product local, Product cloud) async {
    // Custom merge logic - you can customize this based on your business rules
    
    // Use the most recent price
    final price = local.lastUpdated.isAfter(cloud.lastUpdated) ? local.price : cloud.price;
    
    // For stock, use the higher value to avoid overselling
    final stock = local.stockQuantity > cloud.stockQuantity ? local.stockQuantity : cloud.stockQuantity;
    
    // Use the most recent update timestamp
    final lastUpdated = local.lastUpdated.isAfter(cloud.lastUpdated) ? local.lastUpdated : cloud.lastUpdated;
    
    return Product(
      id: local.id,
      name: cloud.name, // Assume cloud has the authoritative product name
      barcode: local.barcode,
      price: price,
      stockQuantity: stock,
      lastUpdated: lastUpdated,
      isSynced: false, // Mark for sync to propagate the merged data
    );
  }
}