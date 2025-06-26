import 'dart:async';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'product.dart';
import 'transaction.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('pos_database.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    // Products table
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        barcode TEXT NOT NULL UNIQUE,
        price REAL NOT NULL,
        stock_quantity INTEGER NOT NULL,
        last_updated TEXT NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Transactions table
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        items TEXT NOT NULL,
        total_amount REAL NOT NULL,
        timestamp TEXT NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0,
        cloud_id TEXT,
        isRefund INTEGER DEFAULT 0,
        originalTransactionId INTEGER
      )
    ''');

    // Insert sample products for testing
    await _insertSampleProducts(db);
  }

  Future<void> _insertSampleProducts(Database db) async {
    final sampleProducts = [
      Product(name: 'Paracetamol 500mg', barcode: '1234567890123', price: 5.99, stockQuantity: 100),
      Product(name: 'Ibuprofen 200mg', barcode: '1234567890124', price: 7.50, stockQuantity: 75),
      Product(name: 'Vitamin C 1000mg', barcode: '1234567890125', price: 12.99, stockQuantity: 50),
      Product(name: 'Sunscreen SPF 50', barcode: '1234567890126', price: 15.99, stockQuantity: 25),
      Product(name: 'Face Wash Gentle', barcode: '1234567890127', price: 8.99, stockQuantity: 30),
      Product(name: 'Antiseptic Cream', barcode: '1234567890128', price: 6.50, stockQuantity: 40),
      Product(name: 'Cough Syrup', barcode: '1234567890129', price: 9.99, stockQuantity: 20),
      Product(name: 'First Aid Kit', barcode: '1234567890130', price: 25.99, stockQuantity: 15),
    ];

    for (final product in sampleProducts) {
      await db.insert('products', product.toMap());
    }
  }

  // Product operations
  Future<List<Product>> getProducts() async {
    final db = await instance.database;
    final result = await db.query('products');
    return result.map((map) => Product.fromMap(map)).toList();
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    final db = await instance.database;
    final result = await db.query(
      'products',
      where: 'barcode = ?',
      whereArgs: [barcode],
    );
    if (result.isNotEmpty) {
      return Product.fromMap(result.first);
    }
    return null;
  }

  Future<int> insertProduct(Product product) async {
    final db = await instance.database;
    return await db.insert('products', product.toMap());
  }

  Future<int> updateProduct(Product product) async {
    final db = await instance.database;
    return await db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<void> updateProductStock(int productId, int newStock) async {
    final db = await instance.database;
    await db.update(
      'products',
      {
        'stock_quantity': newStock,
        'last_updated': DateTime.now().toIso8601String(),
        'is_synced': 0,
      },
      where: 'id = ?',
      whereArgs: [productId],
    );
  }

  Future<List<Product>> getUnsyncedProducts() async {
    final db = await instance.database;
    final result = await db.query(
      'products',
      where: 'is_synced = ?',
      whereArgs: [0],
    );
    return result.map((map) => Product.fromMap(map)).toList();
  }

  Future<void> markProductAsSynced(int productId) async {
    final db = await instance.database;
    await db.update(
      'products',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [productId],
    );
  }

  // Transaction operations
  Future<int> insertTransaction(PosTransaction transaction) async {
    final db = await instance.database;
    return await db.insert('transactions', transaction.toMap());
  }

  Future<List<PosTransaction>> getTransactions() async {
    final db = await instance.database;
    final result = await db.query('transactions', orderBy: 'timestamp DESC');
    return result.map((map) => PosTransaction.fromMap(map)).toList();
  }

  Future<List<PosTransaction>> getUnsyncedTransactions() async {
    final db = await instance.database;
    final result = await db.query(
      'transactions',
      where: 'is_synced = ?',
      whereArgs: [0],
    );
    return result.map((map) => PosTransaction.fromMap(map)).toList();
  }

  Future<void> markTransactionAsSynced(int transactionId, String cloudId) async {
    final db = await instance.database;
    await db.update(
      'transactions',
      {
        'is_synced': 1,
        'cloud_id': cloudId,
      },
      where: 'id = ?',
      whereArgs: [transactionId],
    );
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}