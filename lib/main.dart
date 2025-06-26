import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'database_helper.dart';
import 'sync_service.dart';
import 'product.dart';
import 'transaction.dart';
import 'cart_item.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  await DatabaseHelper.instance.database;

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  String searchQuery = '';
  bool isOnline = false;
  final SyncService _syncService = SyncService();

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _setupConnectivityListener();
  }

  void _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      isOnline = connectivityResult != ConnectivityResult.none;
    });
    
    if (isOnline) {
      _syncService.performSync();
    }
  }

  void _setupConnectivityListener() {
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      setState(() {
        isOnline = result != ConnectivityResult.none;
      });
      
      if (isOnline) {
        _syncService.performSync();
      }
    });
  }

  final List<Widget> _pages = [
    const SalesEntryPage(),
    const TransactionHistoryPage(),
    const StockPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pharmacy POS',
      theme: ThemeData(
        primarySwatch: Colors.cyan,
        useMaterial3: true,
      ),
      home: Scaffold(
        key: _scaffoldKey,
        drawer: _buildDrawer(),
        appBar: _buildAppBar(),
        body: _pages[_selectedIndex],
        bottomNavigationBar: _buildBottomNavigation(),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.cyan),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pharmacy POS', 
                  style: TextStyle(color: Colors.white, fontSize: 24)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      isOnline ? Icons.cloud_done : Icons.cloud_off,
                      color: isOnline ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        color: isOnline ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text('Sync Now'),
            enabled: isOnline,
            onTap: isOnline ? () {
              _syncService.performSync();
              Navigator.pop(context);
            } : null,
          ),
          const ListTile(
            leading: Icon(Icons.settings),
            title: Text('Settings'),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.cyan,
      foregroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.menu),
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      title: const Text('Pharmacy POS'),
      actions: [
        Container(
          width: 200,
          margin: const EdgeInsets.only(right: 10),
          child: TextField(
            onChanged: (value) => setState(() => searchQuery = value),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
              hintText: 'Search products...',
              hintStyle: const TextStyle(color: Colors.white70),
              filled: true,
              fillColor: Colors.white24,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
            ),
          ),
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
        BottomNavigationBarItem(icon: Icon(Icons.inventory), label: 'Stock'),
      ],
    );
  }
}

// Enhanced Sales Entry Page
class SalesEntryPage extends StatefulWidget {
  const SalesEntryPage({super.key});

  @override
  State<SalesEntryPage> createState() => _SalesEntryPageState();
}

class _SalesEntryPageState extends State<SalesEntryPage> {
  final TextEditingController barcodeController = TextEditingController();
  final List<CartItem> cartItems = [];
  List<Product> products = [];
  List<Product> filteredProducts = [];
  String searchQuery = '';
  
  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final loadedProducts = await DatabaseHelper.instance.getProducts();
    setState(() {
      products = loadedProducts;
      filteredProducts = loadedProducts;
    });
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
    if (product.stockQuantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product out of stock')),
      );
      return;
    }

    setState(() {
      final existingIndex = cartItems.indexWhere((item) => item.productId == product.id);
      if (existingIndex >= 0) {
        cartItems[existingIndex].quantity++;
      } else {
        cartItems.add(CartItem(
          productId: product.id!,
          productName: product.name,
          price: product.price,
          quantity: 1,
        ));
      }
    });
  }

  void _updateCartItemQuantity(int index, int newQuantity) {
    setState(() {
      if (newQuantity <= 0) {
        cartItems.removeAt(index);
      } else {
        cartItems[index].quantity = newQuantity;
      }
    });
  }

  double get total => cartItems.fold(0, (sum, item) => sum + (item.price * item.quantity));

  Future<void> _checkout() async {
    if (cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart is empty')),
      );
      return;
    }

    // Create transaction
    final transaction = PosTransaction(
      items: cartItems.map((item) => CartItem(
        productId: item.productId,
        productName: item.productName,
        price: item.price,
        quantity: item.quantity,
      )).toList(),
      totalAmount: total,
      timestamp: DateTime.now(),
      isSynced: false,
    );

    // Save transaction to local database
    await DatabaseHelper.instance.insertTransaction(transaction);

    // Update stock locally
    for (final cartItem in cartItems) {
      final product = products.firstWhere((p) => p.id == cartItem.productId);
      product.stockQuantity -= cartItem.quantity;
      await DatabaseHelper.instance.updateProduct(product);
    }

    setState(() {
      cartItems.clear();
    });

    await _loadProducts(); // Refresh product list

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sale completed successfully!')),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        
        // Cart
        Expanded(
          flex: 2,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                child: const Text('Cart', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: cartItems.length,
                  itemBuilder: (context, index) {
                    final item = cartItems[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        title: Text(item.productName),
                        subtitle: Text('\$${item.price.toStringAsFixed(2)} each'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () => _updateCartItemQuantity(index, item.quantity - 1),
                              icon: const Icon(Icons.remove),
                            ),
                            Text('${item.quantity}'),
                            IconButton(
                              onPressed: () => _updateCartItemQuantity(index, item.quantity + 1),
                              icon: const Icon(Icons.add),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('\$${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: cartItems.isNotEmpty ? _checkout : null,
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
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class TransactionHistoryPage extends StatefulWidget {
  const TransactionHistoryPage({super.key});

  @override
  State<TransactionHistoryPage> createState() => _TransactionHistoryPageState();
}

class _TransactionHistoryPageState extends State<TransactionHistoryPage> {
  List<PosTransaction> transactions = [];
  List<Product> products = [];

  @override
  void initState() {
    super.initState();
    _loadTransactions();
    _loadProducts();
  }

  Future<void> _loadTransactions() async {
    final loadedTransactions = await DatabaseHelper.instance.getTransactions();
    setState(() {
      transactions = loadedTransactions;
    });
  }

  Future<void> _loadProducts() async {
    final loadedProducts = await DatabaseHelper.instance.getProducts();
    setState(() {
      products = loadedProducts;
    });
  }

  Future<void> _processFullRefund(PosTransaction transaction) async {
    // Create refund transaction
    final refundTransaction = PosTransaction(
      items: transaction.items.map((item) => CartItem(
        productId: item.productId,
        productName: item.productName,
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
    return ListView.builder(
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
                  child: Text('Transaction #${transaction.id}'),
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
              ).toList(),
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

// Enhanced Stock Page
class StockPage extends StatefulWidget {
  const StockPage({super.key});

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  List<Product> products = [];
  List<Product> filteredProducts = [];
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final loadedProducts = await DatabaseHelper.instance.getProducts();
    setState(() {
      products = loadedProducts;
      filteredProducts = loadedProducts;
    });
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: _filterProducts,
            decoration: const InputDecoration(
              labelText: 'Search products',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: filteredProducts.length,
            itemBuilder: (context, index) {
              final product = filteredProducts[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  title: Text(product.name),
                  subtitle: Text('Barcode: ${product.barcode}'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('\${product.price.toStringAsFixed(2)}'),
                      Text(
                        'Stock: ${product.stockQuantity}',
                        style: TextStyle(
                          color: product.stockQuantity > 0 ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}