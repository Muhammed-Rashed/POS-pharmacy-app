import 'package:flutter/foundation.dart';
import 'cart_item.dart';
import 'product.dart';

class CustomerCart {
  final String id;
  String customerName;
  List<CartItem> items;
  DateTime createdAt;
  DateTime lastUpdated;

  CustomerCart({
    required this.id,
    required this.customerName,
    List<CartItem>? items,
    DateTime? createdAt,
    DateTime? lastUpdated,
  }) : items = items ?? [],
       createdAt = createdAt ?? DateTime.now(),
       lastUpdated = lastUpdated ?? DateTime.now();

  double get total => items.fold(0, (sum, item) => sum + (item.price * item.quantity));
  
  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  void addItem(CartItem item) {
    final existingIndex = items.indexWhere((i) => i.productId == item.productId);
    if (existingIndex >= 0) {
      items[existingIndex].quantity += item.quantity;
    } else {
      items.add(item);
    }
    lastUpdated = DateTime.now();
  }

  void updateItemQuantity(int itemIndex, int newQuantity) {
    if (itemIndex >= 0 && itemIndex < items.length) {
      if (newQuantity <= 0) {
        items.removeAt(itemIndex);
      } else {
        items[itemIndex].quantity = newQuantity;
      }
      lastUpdated = DateTime.now();
    }
  }

  void removeItem(int itemIndex) {
    if (itemIndex >= 0 && itemIndex < items.length) {
      items.removeAt(itemIndex);
      lastUpdated = DateTime.now();
    }
  }

  void clear() {
    items.clear();
    lastUpdated = DateTime.now();
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_name': customerName,
      'items': items.map((item) => item.toMap()).toList(),
      'created_at': createdAt.toIso8601String(),
      'last_updated': lastUpdated.toIso8601String(),
    };
  }

  factory CustomerCart.fromMap(Map<String, dynamic> map) {
    return CustomerCart(
      id: map['id'],
      customerName: map['customer_name'],
      items: (map['items'] as List).map((item) => CartItem.fromMap(item)).toList(),
      createdAt: DateTime.parse(map['created_at']),
      lastUpdated: DateTime.parse(map['last_updated']),
    );
  }
}

class CartManager extends ChangeNotifier {
  final List<CustomerCart> _carts = [];
  int _activeCartIndex = 0;
  static const int maxCarts = 10;

  List<CustomerCart> get carts => List.unmodifiable(_carts);
  int get activeCartIndex => _activeCartIndex;
  CustomerCart? get activeCart => _carts.isNotEmpty ? _carts[_activeCartIndex] : null;
  bool get hasActiveCarts => _carts.isNotEmpty;
  int get cartCount => _carts.length;

  String _generateCartId() {
    return 'cart_${DateTime.now().millisecondsSinceEpoch}_${_carts.length}';
  }

  CustomerCart createNewCart({String? customerName}) {
    try {
      if (_carts.length >= maxCarts) {
        throw CartException('Maximum number of carts ($maxCarts) reached');
      }

      final cart = CustomerCart(
        id: _generateCartId(),
        customerName: customerName ?? 'Customer ${_carts.length + 1}',
      );

      _carts.add(cart);
      _activeCartIndex = _carts.length - 1;
      notifyListeners();
      
      return cart;
    } catch (e) {
      throw CartException('Failed to create new cart: $e');
    }
  }

  void switchToCart(int index) {
    try {
      if (index < 0 || index >= _carts.length) {
        throw CartException('Invalid cart index: $index');
      }
      _activeCartIndex = index;
      notifyListeners();
    } catch (e) {
      throw CartException('Failed to switch cart: $e');
    }
  }

  void updateCartCustomerName(int cartIndex, String newName) {
    try {
      if (cartIndex < 0 || cartIndex >= _carts.length) {
        throw CartException('Invalid cart index: $cartIndex');
      }
      if (newName.trim().isEmpty) {
        throw CartException('Customer name cannot be empty');
      }
      
      _carts[cartIndex].customerName = newName.trim();
      _carts[cartIndex].lastUpdated = DateTime.now();
      notifyListeners();
    } catch (e) {
      throw CartException('Failed to update customer name: $e');
    }
  }

  void addItemToActiveCart(Product product, {int quantity = 1}) {
    try {
      if (activeCart == null) {
        createNewCart();
      }

      if (product.stockQuantity <= 0) {
        throw StockException('Product "${product.name}" is out of stock');
      }

      // Check if adding this quantity would exceed available stock
      final existingItem = activeCart!.items.firstWhere(
        (item) => item.productId == product.id,
        orElse: () => CartItem(
          productId: -1,
          productName: '',
          barcode: '',
          price: 0,
          quantity: 0,
        ),
      );

      final totalRequestedQuantity = (existingItem.productId != -1 ? existingItem.quantity : 0) + quantity;
      
      if (totalRequestedQuantity > product.stockQuantity) {
        throw StockException(
          'Cannot add $quantity units. Only ${product.stockQuantity - (existingItem.productId != -1 ? existingItem.quantity : 0)} units available'
        );
      }

      final cartItem = CartItem(
        productId: product.id!,
        productName: product.name,
        barcode: product.barcode,
        price: product.price,
        quantity: quantity,
      );

      activeCart!.addItem(cartItem);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  void updateItemQuantityInActiveCart(int itemIndex, int newQuantity) {
    try {
      if (activeCart == null) {
        throw CartException('No active cart');
      }

      if (itemIndex < 0 || itemIndex >= activeCart!.items.length) {
        throw CartException('Invalid item index: $itemIndex');
      }

      activeCart!.updateItemQuantity(itemIndex, newQuantity);
      notifyListeners();
    } catch (e) {
      throw CartException('Failed to update item quantity: $e');
    }
  }

  void removeItemFromActiveCart(int itemIndex) {
    try {
      if (activeCart == null) {
        throw CartException('No active cart');
      }

      activeCart!.removeItem(itemIndex);
      notifyListeners();
    } catch (e) {
      throw CartException('Failed to remove item: $e');
    }
  }

  CustomerCart closeCart(int cartIndex) {
    try {
      if (cartIndex < 0 || cartIndex >= _carts.length) {
        throw CartException('Invalid cart index: $cartIndex');
      }

      final closedCart = _carts.removeAt(cartIndex);
      
      // Adjust active cart index if necessary
      if (_activeCartIndex >= _carts.length && _carts.isNotEmpty) {
        _activeCartIndex = _carts.length - 1;
      } else if (_carts.isEmpty) {
        _activeCartIndex = 0;
      }

      notifyListeners();
      return closedCart;
    } catch (e) {
      throw CartException('Failed to close cart: $e');
    }
  }

  void clearActiveCart() {
    try {
      if (activeCart == null) {
        throw CartException('No active cart to clear');
      }

      activeCart!.clear();
      notifyListeners();
    } catch (e) {
      throw CartException('Failed to clear cart: $e');
    }
  }

  void clearAllCarts() {
    try {
      _carts.clear();
      _activeCartIndex = 0;
      notifyListeners();
    } catch (e) {
      throw CartException('Failed to clear all carts: $e');
    }
  }

  // Validation methods
  bool validateCartForCheckout(CustomerCart cart) {
    if (cart.items.isEmpty) {
      throw CartException('Cart is empty');
    }

    for (final item in cart.items) {
      if (item.quantity <= 0) {
        throw CartException('Invalid quantity for item: ${item.productName}');
      }
    }

    if (cart.total <= 0) {
      throw CartException('Invalid cart total');
    }

    return true;
  }

  // Helper methods for persistence (if needed)
  List<Map<String, dynamic>> exportCarts() {
    return _carts.map((cart) => cart.toMap()).toList();
  }

  void importCarts(List<Map<String, dynamic>> cartsData) {
    try {
      _carts.clear();
      for (final cartData in cartsData) {
        _carts.add(CustomerCart.fromMap(cartData));
      }
      _activeCartIndex = _carts.isNotEmpty ? 0 : 0;
      notifyListeners();
    } catch (e) {
      throw CartException('Failed to import carts: $e');
    }
  }
}

// Custom exceptions
class CartException implements Exception {
  final String message;
  CartException(this.message);
  
  @override
  String toString() => 'CartException: $message';
}

class StockException implements Exception {
  final String message;
  StockException(this.message);
  
  @override
  String toString() => 'StockException: $message';
}