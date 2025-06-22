import 'package:flutter/material.dart';

void main() {
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

  // Placeholder page widgets
  final List<Widget> _pages = [
    const HomePage(),
    const CartPage(),
    Center(child: Text('Shop Page (Coming Soon)')),
    Center(child: Text('Stock Page (Coming Soon)')),
  ];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        key: _scaffoldKey,
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: const [
              DrawerHeader(
                decoration: BoxDecoration(
                  color: Colors.cyan,
                ),
                child: Text(
                  'Menu',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.history),
                title: Text('History'),
              ),
              ListTile(
                leading: Icon(Icons.attach_money),
                title: Text('Money'),
              ),
              ListTile(
                leading: Icon(Icons.settings),
                title: Text('Settings'),
              ),
            ],
          ),
        ),
        appBar: AppBar(
          backgroundColor: Colors.cyan,
          leading: IconButton(
            icon: const Icon(Icons.list, color: Colors.white),
            onPressed: () {
              _scaffoldKey.currentState?.openDrawer();
            },
          ),
          actions: [
            Container(
              width: 200,
              margin: const EdgeInsets.only(right: 10),
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    searchQuery = value;
                  });
                },
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                  hintText: 'Search...',
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
        ),
        body: _pages[_selectedIndex],
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          selectedItemColor: Colors.blue,
          unselectedItemColor: Colors.grey,
          selectedLabelStyle: const TextStyle(color: Colors.blue),
          unselectedLabelStyle: const TextStyle(color: Colors.black),
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.store),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.shopping_cart_rounded),
              label: 'Cart',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.shopping_bag_rounded),
              label: 'Shop',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.warehouse),
              label: 'Stock',
            ),
          ],
        ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 5,
      padding: const EdgeInsets.all(12),
      itemBuilder: (context, index) {
        return InkWell(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Going to history for card #$index")),
            );
          },
          child: Card(
            elevation: 4,
            margin: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text("Mohamed's Pharma",
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 10),
                  Text("Paracetamol x2 - \$10"),
                  Text("Sunscreen x1 - \$8"),
                  Text("Face Wash x3 - \$21"),
                  SizedBox(height: 10),
                  Text("Total after discount: \$35",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.green)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  List<int> selectedIndexes = [];
  bool selectionMode = false;
  String searchQuery = '';

  void toggleSelectionMode(int index) {
    setState(() {
      selectionMode = true;
      if (selectedIndexes.contains(index)) {
        selectedIndexes.remove(index);
        if (selectedIndexes.isEmpty) selectionMode = false;
      } else {
        selectedIndexes.add(index);
      }
    });
  }

  void clearSelection() {
    setState(() {
      selectionMode = false;
      selectedIndexes.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          if (selectionMode)
            Container(
              color: Colors.grey.shade200,
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Text('${selectedIndexes.length} selected'),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      // TODO: handle batch delete
                    },
                    child: const Text('Delete'),
                  ),
                  TextButton(
                    onPressed: () {
                      // TODO: handle batch buy
                    },
                    child: const Text('Buy'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 3 / 2,
              ),
              itemCount: 8,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (ctx) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.delete),
                            title: const Text('Delete Item'),
                            onTap: () {
                              Navigator.pop(ctx);
                              // TODO: delete logic
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.shopping_cart),
                            title: const Text('Buy This Item'),
                            onTap: () {
                              Navigator.pop(ctx);
                              // TODO: buy logic
                            },
                          ),
                        ],
                      ),
                    );
                  },
                  onLongPress: () => toggleSelectionMode(index),
                  child: Card(
                    color: selectedIndexes.contains(index)
                        ? Colors.blue.shade100
                        : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Item Name', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('Amount: 20'),
                          Text('Price: \$200 (Before: \$250)'),
                          Text('Manufacturer: PharmaX'),
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
    );
  }
}
