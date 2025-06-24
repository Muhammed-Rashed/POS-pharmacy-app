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
      items: cartItems,
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

// Transaction History Page
class TransactionHistoryPage extends StatefulWidget {
  const TransactionHistoryPage({super.key});

  @override
  State<TransactionHistoryPage> createState() => _TransactionHistoryPageState();
}

class _TransactionHistoryPageState extends State<TransactionHistoryPage> {
  List<PosTransaction> transactions = [];

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    final loadedTransactions = await DatabaseHelper.instance.getTransactions();
    setState(() {
      transactions = loadedTransactions;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final transaction = transactions[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            title: Text('Transaction #${transaction.id}'),
            subtitle: Text('${transaction.timestamp.toString().split('.')[0]} - \$${transaction.totalAmount.toStringAsFixed(2)}'),
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
            children: transaction.items.map((item) => 
              ListTile(
                title: Text(item.productName),
                trailing: Text('${item.quantity} x \$${item.price.toStringAsFixed(2)}'),
              )
            ).toList(),
          ),
        );
      },
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
                      Text('\$${product.price.toStringAsFixed(2)}'),
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