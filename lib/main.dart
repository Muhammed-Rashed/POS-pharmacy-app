import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'database_helper.dart';
import 'sync_service.dart';
import 'product.dart';
import 'transaction.dart';
import 'cart_item.dart';
import 'cart_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite FFI local database
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // Initialize Firebase cloud backend
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Make sure database is ready before sync
  await DatabaseHelper.instance.database;

  final prefs = await SharedPreferences.getInstance();
  final hasInitialized = prefs.getBool('has_initialized_cloud') ?? false;

  if (!hasInitialized) {
    await SyncService().syncStockUpdatesToCloud(force: true);
    await prefs.setBool('has_initialized_cloud', true);
  }
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();

  
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<_TransactionHistoryPageState> _historyKey = GlobalKey<_TransactionHistoryPageState>();
  final ValueNotifier<bool> historyRefreshTrigger = ValueNotifier(false);

  int _selectedIndex = 0;
  String searchQuery = '';
  bool isOnline = false;
  final SyncService _syncService = SyncService();

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _setupConnectivityListener();
    _setupOnlineSyncListener();
  }

  void _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      isOnline = connectivityResult != ConnectivityResult.none;
    });
    
    if (isOnline) {
      _syncService.performSync();
      historyRefreshTrigger.value = !historyRefreshTrigger.value;
    }
  }

  void _setupConnectivityListener() {
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      setState(() {
        isOnline = result != ConnectivityResult.none;
      });
      
      if (isOnline) {
        _syncService.performSync();
        historyRefreshTrigger.value = !historyRefreshTrigger.value;
      }
    });
  }

  void _setupOnlineSyncListener() {
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      if (result != ConnectivityResult.none) {
        SyncService().performSync(); // Ensure SyncService is accessible
      }
    });
  }

  List<Widget> get _pages => [
    SalesEntryPage(
      onSaleCompleted: () {
        historyRefreshTrigger.value = !historyRefreshTrigger.value;
      },
    ),
    TransactionHistoryPage(refreshTrigger: historyRefreshTrigger),
  ];


  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => CartManager(),
      child: MaterialApp(
        title: 'Pharmacy POS',
        theme: ThemeData(
          primarySwatch: Colors.cyan,
          useMaterial3: true,
        ),
        home: Scaffold(
          key: _scaffoldKey,
          appBar: _buildAppBar(),
          body: IndexedStack(
          index: _selectedIndex,
            children: [
              SalesEntryPage(
                onSaleCompleted: () {
                  historyRefreshTrigger.value = !historyRefreshTrigger.value;
                },
              ),
              TransactionHistoryPage(
                refreshTrigger: historyRefreshTrigger,
              ),
            ],
          ),
          bottomNavigationBar: _buildBottomNavigation(),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.cyan,
      foregroundColor: Colors.white,
      title: const Text('Pharmacy POS'),
      actions: [
        Row(
          children: [
            Icon(
              isOnline ? Icons.cloud_done : Icons.cloud_off,
              color: isOnline ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 4),
            Text(
              isOnline ? 'Online' : 'Offline',
              style: TextStyle(
                color: isOnline ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              icon: const Icon(Icons.sync),
              tooltip: 'Sync Now',
              onPressed: isOnline
                  ? () {
                      _syncService.performSync();
                      ScaffoldMessenger.of(_scaffoldKey.currentContext!)
                          .showSnackBar(
                        const SnackBar(content: Text('Sync started...')),
                      );
                    }
                  : null, // Disabled when offline
              color: isOnline ? Colors.white : Colors.grey[400],
            ),
          ],
        ),
      ],
    );
  }


  Widget _buildBottomNavigation() {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: _selectedIndex,
      selectedItemColor: Colors.cyan,
      unselectedItemColor: Colors.grey,
      onTap: (index) => setState(() => _selectedIndex = index),
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.store), label: 'Sales'),
        BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
      ],
    );
  }
}

// Sales Entry Page
class SalesEntryPage extends StatefulWidget {
  final VoidCallback? onSaleCompleted;

  const SalesEntryPage({super.key, this.onSaleCompleted});

  @override
  State<SalesEntryPage> createState() => _SalesEntryPageState();
}

class _SalesEntryPageState extends State<SalesEntryPage> with TickerProviderStateMixin {
  final TextEditingController barcodeController = TextEditingController();
  List<Product> products = [];
  List<Product> filteredProducts = [];
  String searchQuery = '';
  late TabController _cartTabController;
  
  @override
  void initState() {
    super.initState();
    _loadProducts();
    _cartTabController = TabController(length: 1, vsync: this);
  }

  @override
  void dispose() {
    _cartTabController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    try {
      final loadedProducts = await DatabaseHelper.instance.getProducts();
      setState(() {
        products = loadedProducts;
        filteredProducts = loadedProducts;
      });
    } catch (e) {
      _showErrorSnackBar('Failed to load products: $e');
    }
  }

  void _filterProducts(String query) {
    setState(() {
      searchQuery = query;
      if (query.isEmpty) {
        filteredProducts = products;
      } else {
        filteredProducts = products.where((product) =>
          product.name.toLowerCase().contains(query.toLowerCase()) ||
          product.barcode.contains(query)
        ).toList();
      }
    });
  }

  void _addToCart(Product product) {
    final cartManager = Provider.of<CartManager>(context, listen: false);
    
    try {
      cartManager.addItemToActiveCart(product);
    } catch (e) {
      _showErrorSnackBar(e.toString());
    }
  }

  void _updateCartTabController() {
    final cartManager = Provider.of<CartManager>(context, listen: false);
    final newLength = cartManager.cartCount == 0 ? 1 : cartManager.cartCount;
    
    if (_cartTabController.length != newLength) {
      _cartTabController.dispose();
      _cartTabController = TabController(
        length: newLength,
        vsync: this,
        initialIndex: cartManager.activeCartIndex.clamp(0, newLength - 1),
      );
    }
  }

  void _createNewCart() {
    final cartManager = Provider.of<CartManager>(context, listen: false);
    
    try {
      cartManager.createNewCart();
      _updateCartTabController();
    } catch (e) {
      _showErrorSnackBar(e.toString());
    }
  }

  bool isOfflineMode = false;

  Future<void> _checkout() async {
    final cartManager = Provider.of<CartManager>(context, listen: false);
    final activeCart = cartManager.activeCart;

    if (activeCart == null) {
      _showErrorSnackBar('No active cart');
      return;
    }

    try {
      //  Validate cart contents
      cartManager.validateCartForCheckout(activeCart);

      //  Build transaction object
      final transaction = PosTransaction(
        items: activeCart.items.map((item) {
        final product = products.firstWhere((p) => p.id == item.productId);
        return CartItem(
          productId: item.productId,
          productName: item.productName,
          barcode: product.barcode,
          price: item.price,
          quantity: item.quantity,
        );
      }).toList(),
        totalAmount: activeCart.total,
        timestamp: DateTime.now(),
        isSynced: false,
        isRefund: false,
      );

      final transactionId = await DatabaseHelper.instance.insertTransaction(transaction);
      print('Inserted transaction ID: $transactionId');

      if (transactionId == 0) {
        throw Exception('Transaction insert failed');
      }

      for (final cartItem in activeCart.items) {
        final product = products.firstWhere((p) => p.id == cartItem.productId);
        product.stockQuantity -= cartItem.quantity;
        await DatabaseHelper.instance.updateProduct(product);
      }

      final connectivityResult = await Connectivity().checkConnectivity();
      isOfflineMode = connectivityResult == ConnectivityResult.none;

      //  Sync only if online
      if (!isOfflineMode) {
        await SyncService().performSync();
      } else {
        print("🛑 Offline mode is ON. Skipping sync.");
      }

      //  Clear cart and update UI
      cartManager.closeCart(cartManager.activeCartIndex);
      _updateCartTabController();
      await _loadProducts();

      widget.onSaleCompleted?.call();
      _showSuccessSnackBar(
        'Checkout successful${isOfflineMode ? ' (offline)' : ' and synced to cloud'}',
      );

    } catch (e) {
      _showErrorSnackBar('Checkout failed: $e');
    }
  }



  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CartManager>(
      builder: (context, cartManager, child) {
        _updateCartTabController();
        
        return Row(
          children: [
            // Product Search & Selection
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: barcodeController,
                      onChanged: _filterProducts,
                      decoration: const InputDecoration(
                        labelText: 'Search by name or scan barcode',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.2,
                      ),
                      itemCount: filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = filteredProducts[index];
                        return Card(
                          child: InkWell(
                            onTap: () => _addToCart(product),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const Spacer(),
                                  Text('\$${product.price.toStringAsFixed(2)}'),
                                  Text('Stock: ${product.stockQuantity}',
                                    style: TextStyle(
                                      color: product.stockQuantity > 0 ? Colors.green : Colors.red,
                                    )),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            
            const VerticalDivider(),
            
            // Multi-Tab Cart System
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  // Cart Header with Tab Controls
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Text('Carts', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        IconButton(
                          onPressed: _createNewCart,
                          icon: const Icon(Icons.add),
                          tooltip: 'Create New Cart',
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.cyan,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Cart Tabs
                  if (cartManager.hasActiveCarts)
                    SizedBox(
                      height: 50,
                      child: TabBar(
                        controller: _cartTabController,
                        isScrollable: true,
                        indicatorColor: Colors.cyan,
                        labelColor: Colors.cyan,
                        unselectedLabelColor: Colors.grey,
                        onTap: (index) {
                          cartManager.switchToCart(index);
                        },
                        tabs: cartManager.carts.asMap().entries.map((entry) {
                          final index = entry.key;
                          final cart = entry.value;
                          return Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Tab ${index + 1}'),
                                if (cart.itemCount > 0)
                                  Container(
                                    margin: const EdgeInsets.only(left: 4),
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '${cart.itemCount}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                if (cartManager.carts.length > 1)
                                  GestureDetector(
                                    onTap: () {
                                      try {
                                        cartManager.closeCart(index);
                                        _updateCartTabController();
                                        _showSuccessSnackBar('Cart closed');
                                      } catch (e) {
                                        _showErrorSnackBar(e.toString());
                                      }
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.only(left: 4),
                                      child: Icon(Icons.close, size: 16),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  
                  // Cart Content
                  Expanded(
                    child: cartManager.hasActiveCarts
                        ? _buildCartContent(cartManager)
                        : const Center(
                            child: Text(
                              'No active carts\nTap + to create a new cart',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCartContent(CartManager cartManager) {
    final activeCart = cartManager.activeCart;
    if (activeCart == null) {
      return const Center(child: Text('No active cart'));
    }

    return Column(
      children: [
        // Cart Items
        Expanded(
          child: activeCart.items.isEmpty
              ? const Center(
                  child: Text(
                    'Cart is empty\nAdd products to get started',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: activeCart.items.length,
                  itemBuilder: (context, index) {
                    final item = activeCart.items[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        title: Text(item.productName),
                        subtitle: Text('\$${item.price.toStringAsFixed(2)} each'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () {
                                try {
                                  cartManager.updateItemQuantityInActiveCart(index, item.quantity - 1);
                                } catch (e) {
                                  _showErrorSnackBar(e.toString());
                                }
                              },
                              icon: const Icon(Icons.remove),
                            ),
                            Text('${item.quantity}'),
                            IconButton(
                              onPressed: () {
                                try {
                                  cartManager.updateItemQuantityInActiveCart(index, item.quantity + 1);
                                } catch (e) {
                                  _showErrorSnackBar(e.toString());
                                }
                              },
                              icon: const Icon(Icons.add),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        
        // Cart Total and Checkout
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('\$${activeCart.total.toStringAsFixed(2)}', 
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Items: ${activeCart.itemCount}',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: activeCart.items.isNotEmpty ? () {
                        try {
                          cartManager.clearActiveCart();
                          _showSuccessSnackBar('Cart cleared');
                        } catch (e) {
                          _showErrorSnackBar(e.toString());
                        }
                      } : null,
                      child: const Text('Clear Cart'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: activeCart.items.isNotEmpty ? _checkout : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyan,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Checkout', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class TransactionHistoryPage extends StatefulWidget {
  final ValueNotifier<bool>? refreshTrigger;

  const TransactionHistoryPage({super.key, this.refreshTrigger});

  @override
  State<TransactionHistoryPage> createState() => _TransactionHistoryPageState();
}

class _TransactionHistoryPageState extends State<TransactionHistoryPage> {
  List<PosTransaction> transactions = [];
  List<Product> products = [];
  void reload() {
    _loadTransactions();
    _loadProducts();
  }

  @override
  void initState() {
    super.initState();
    _loadTransactions();
    _loadProducts();

    widget.refreshTrigger?.addListener(() {
      _loadTransactions();
      _loadProducts();
    });
  }

  bool showCloudTransactions = true;

  Future<void> _loadTransactions() async {
    if (showCloudTransactions) {
      transactions = await SyncService().fetchTransactionsFromCloud();
    } else {
      transactions = await DatabaseHelper.instance.getTransactions();
    }
    setState(() {});
  }


  Future<void> _loadProducts() async {
    final loadedProducts = await DatabaseHelper.instance.getProducts();
    setState(() {
      products = loadedProducts;
    });
  }

  Future<void> _processFullRefund(PosTransaction transaction) async {
    final refundTransaction = PosTransaction(
      items: transaction.items.map((item) => CartItem(
      productId: item.productId,
      productName: item.productName,
      barcode: item.barcode,
      price: item.price,
      quantity: item.quantity,
    )).toList(),
      totalAmount: transaction.totalAmount,
      timestamp: DateTime.now(),
      isSynced: false,
      isRefund: true,
      originalTransactionId: transaction.id,
    );

    // Save refund transaction
    await DatabaseHelper.instance.insertTransaction(refundTransaction);

    // Restore stock
    for (final item in transaction.items) {
      final product = products.firstWhere((p) => p.id == item.productId);
      product.stockQuantity += item.quantity;
      await DatabaseHelper.instance.updateProduct(product);
    }

    await _loadTransactions();
    await _loadProducts();

    await SyncService().syncStockUpdatesToCloud();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Full refund processed successfully!')),
      );
    }
  }

  Future<void> _showPartialRefundDialog(PosTransaction transaction) async {
    await showDialog(
      context: context,
      builder: (context) => PartialRefundDialog(
        transaction: transaction,
        products: products,
        onRefundComplete: () {
          _loadTransactions();
          _loadProducts();
        },
      ),
    );
  }

  String _getTransactionStatus(PosTransaction transaction) {
    if (transaction.isRefund == true) {
      return 'Refunded';
    }
    
    // Check if this transaction has been fully refunded
    final refunds = transactions.where((t) => 
      t.isRefund == true && 
      t.originalTransactionId == transaction.id
    ).toList();
    
    if (refunds.isNotEmpty) {
      // Check if it's a full refund
      final totalRefunded = refunds.fold<double>(0, (sum, refund) => sum + refund.totalAmount);
      if (totalRefunded >= transaction.totalAmount) {
        return 'Fully Refunded';
      } else {
        return 'Partially Refunded';
      }
    }
    
    return 'Completed';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Refunded':
        return Colors.red;
      case 'Fully Refunded':
        return Colors.red;
      case 'Partially Refunded':
        return Colors.orange;
      case 'Completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

 @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Show Cloud Transactions'),
              Switch(
                value: showCloudTransactions,
                onChanged: (value) {
                  setState(() {
                    showCloudTransactions = value;
                  });
                  _loadTransactions(); // reload transactions based on the toggle
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final transaction = transactions[index];
              final status = _getTransactionStatus(transaction);
              final isRefundable = transaction.isRefund != true &&
                  !status.contains('Refunded');

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ExpansionTile(
                  title: Row(
                    children: [
                      Expanded(
                        child: Text('Transaction #${transaction.id ?? transaction.cloudId ?? "N/A"}'),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _getStatusColor(status)),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            color: _getStatusColor(status),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    '${transaction.timestamp.toString().split('.')[0]} - \$${transaction.totalAmount.toStringAsFixed(2)}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        transaction.isSynced ? Icons.cloud_done : Icons.cloud_upload,
                        color: transaction.isSynced ? Colors.green : Colors.orange,
                      ),
                      if (!transaction.isSynced) const Text(' Pending'),
                    ],
                  ),
                  children: [
                    ...transaction.items.map((item) =>
                      ListTile(
                        title: Text(item.productName),
                        trailing: Text('${item.quantity} x \$${item.price.toStringAsFixed(2)}'),
                      )
                    ),
                    if (isRefundable)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => _showPartialRefundDialog(transaction),
                              icon: const Icon(Icons.edit),
                              label: const Text('Partial Refund'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => _showFullRefundConfirmation(transaction),
                              icon: const Icon(Icons.undo),
                              label: const Text('Full Refund'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }


  Future<void> _showFullRefundConfirmation(PosTransaction transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Full Refund'),
        content: Text(
          'Are you sure you want to refund the entire transaction of \$${transaction.totalAmount.toStringAsFixed(2)}?\n\nThis will restore all items to stock.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Refund', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _processFullRefund(transaction);
    }
  }
}

// Partial Refund Dialog
class PartialRefundDialog extends StatefulWidget {
  final PosTransaction transaction;
  final List<Product> products;
  final VoidCallback onRefundComplete;

  const PartialRefundDialog({
    super.key,
    required this.transaction,
    required this.products,
    required this.onRefundComplete,
  });

  @override
  State<PartialRefundDialog> createState() => _PartialRefundDialogState();
}

class _PartialRefundDialogState extends State<PartialRefundDialog> {
  late List<CartItem> refundItems;

  @override
  void initState() {
    super.initState();
    // Initialize refund items with zero quantities
    refundItems = widget.transaction.items.map((item) => CartItem(
      productId: item.productId,
      productName: item.productName,
      barcode: item.barcode,
      price: item.price,
      quantity: 0,
    )).toList();
  }

  void _updateRefundQuantity(int index, int newQuantity) {
    final maxQuantity = widget.transaction.items[index].quantity;
    setState(() {
      refundItems[index].quantity = newQuantity.clamp(0, maxQuantity);
    });
  }

  double get refundTotal => refundItems.fold(0, (sum, item) => sum + (item.price * item.quantity));

  bool get hasRefundItems => refundItems.any((item) => item.quantity > 0);

  Future<void> _processPartialRefund() async {
    if (!hasRefundItems) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select items to refund')),
      );
      return;
    }

    // Create refund transaction with only the refunded items
    final refundTransaction = PosTransaction(
      items: refundItems.where((item) => item.quantity > 0).toList(),
      totalAmount: refundTotal,
      timestamp: DateTime.now(),
      isSynced: false,
      isRefund: true,
      originalTransactionId: widget.transaction.id,
    );

    // Save refund transaction
    await DatabaseHelper.instance.insertTransaction(refundTransaction);

    // Restore stock for refunded items
    for (final refundItem in refundItems.where((item) => item.quantity > 0)) {
      final product = widget.products.firstWhere((p) => p.id == refundItem.productId);
      product.stockQuantity += refundItem.quantity;
      await DatabaseHelper.instance.updateProduct(product);
    }

    widget.onRefundComplete();

    await SyncService().syncStockUpdatesToCloud();
    
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Partial refund of \$${refundTotal.toStringAsFixed(2)} processed successfully!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Partial Refund',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: widget.transaction.items.length,
                itemBuilder: (context, index) {
                  final originalItem = widget.transaction.items[index];
                  final refundItem = refundItems[index];
                  
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            originalItem.productName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text('\$${originalItem.price.toStringAsFixed(2)} each'),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text('Original: ${originalItem.quantity}'),
                              const Spacer(),
                              const Text('Refund: '),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    onPressed: refundItem.quantity > 0 
                                      ? () => _updateRefundQuantity(index, refundItem.quantity - 1)
                                      : null,
                                    icon: const Icon(Icons.remove),
                                  ),
                                  Container(
                                    width: 40,
                                    alignment: Alignment.center,
                                    child: Text('${refundItem.quantity}'),
                                  ),
                                  IconButton(
                                    onPressed: refundItem.quantity < originalItem.quantity 
                                      ? () => _updateRefundQuantity(index, refundItem.quantity + 1)
                                      : null,
                                    icon: const Icon(Icons.add),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Refund Total:',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '\$${refundTotal.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: hasRefundItems ? _processPartialRefund : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Process Refund'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}