import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';
import 'product.dart';

class SyncService {
  static const String baseUrl = 'https://your-api-endpoint.com/api'; // Replace with your actual API endpoint
  static const String productsEndpoint = '$baseUrl/products';
  static const String transactionsEndpoint = '$baseUrl/transactions';
  static const String stockUpdateEndpoint = '$baseUrl/stock-update';
  
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<void> performSync() async {
    try {
      await syncTransactionsToCloud();
      await syncProductsFromCloud();
      await syncStockUpdatesToCloud();
      await _updateLastSyncTime();
      print('Sync completed successfully');
    } catch (e) {
      print('Sync failed: $e');
    }
  }

  Future<void> syncTransactionsToCloud() async {
    final unsyncedTransactions = await _db.getUnsyncedTransactions();
    
    for (final transaction in unsyncedTransactions) {
      try {
        final response = await http.post(
          Uri.parse(transactionsEndpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${await _getAuthToken()}',
          },
          body: jsonEncode(transaction.toJson()),
        );

        if (response.statusCode == 201) {
          final responseData = jsonDecode(response.body);
          await _db.markTransactionAsSynced(
            transaction.id!,
            responseData['id'].toString(),
          );
          print('Transaction ${transaction.id} synced successfully');
        } else {
          print('Failed to sync transaction ${transaction.id}: ${response.statusCode}');
        }
      } catch (e) {
        print('Error syncing transaction ${transaction.id}: $e');
      }
    }
  }

  Future<void> syncProductsFromCloud() async {
    try {
      final response = await http.get(
        Uri.parse(productsEndpoint),
        headers: {
          'Authorization': 'Bearer ${await _getAuthToken()}',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> productsJson = jsonDecode(response.body);
        
        for (final productJson in productsJson) {
          final cloudProduct = Product.fromJson(productJson);
          final existingProduct = await _db.getProductByBarcode(cloudProduct.barcode);
          
          if (existingProduct == null) {
            // New product from cloud
            await _db.insertProduct(cloudProduct);
          } else {
            // Update existing product if cloud version is newer
            if (cloudProduct.lastUpdated.isAfter(existingProduct.lastUpdated)) {
              cloudProduct.id = existingProduct.id;
              await _db.updateProduct(cloudProduct);
            }
          }
        }
        print('Products synced from cloud successfully');
      }
    } catch (e) {
      print('Error syncing products from cloud: $e');
    }
  }

  Future<void> syncStockUpdatesToCloud() async {
    final unsyncedProducts = await _db.getUnsyncedProducts();
    
    for (final product in unsyncedProducts) {
      try {
        final response = await http.put(
          Uri.parse('$stockUpdateEndpoint/${product.id}'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${await _getAuthToken()}',
          },
          body: jsonEncode({
            'stock_quantity': product.stockQuantity,
            'last_updated': product.lastUpdated.toIso8601String(),
          }),
        );

        if (response.statusCode == 200) {
          await _db.markProductAsSynced(product.id!);
          print('Stock update for product ${product.id} synced successfully');
        } else {
          print('Failed to sync stock for product ${product.id}: ${response.statusCode}');
        }
      } catch (e) {
        print('Error syncing stock for product ${product.id}: $e');
      }
    }
  }

  Future<String> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token') ?? '';
  }

  Future<void> _updateLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_sync', DateTime.now().toIso8601String());
  }

  Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSyncString = prefs.getString('last_sync');
    return lastSyncString != null ? DateTime.parse(lastSyncString) : null;
  }
}

// api_service.dart

class ApiService {
  static const String baseUrl = 'https://your-api-endpoint.com/api';
  
  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<http.Response> get(String endpoint) async {
    final headers = await _getHeaders();
    final uri = Uri.parse('$baseUrl$endpoint');
    return await http.get(uri, headers: headers);
  }

  static Future<http.Response> post(String endpoint, Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final uri = Uri.parse('$baseUrl$endpoint');
    return await http.post(uri, headers: headers, body: jsonEncode(data));
  }

  static Future<http.Response> put(String endpoint, Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final uri = Uri.parse('$baseUrl$endpoint');
    return await http.put(uri, headers: headers, body: jsonEncode(data));
  }

  static Future<http.Response> delete(String endpoint) async {
    final headers = await _getHeaders();
    final uri = Uri.parse('$baseUrl$endpoint');
    return await http.delete(uri, headers: headers);
  }

  static Future<bool> testConnection() async {
    try {
      final response = await get('/health');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}