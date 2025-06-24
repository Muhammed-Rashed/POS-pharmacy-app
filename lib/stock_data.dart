class StockItem {
  final String name;
  final int inStock;
  final double originalPrice;
  final double discountPrice;
  final String barCode;

  StockItem({
    required this.name,
    required this.inStock,
    required this.originalPrice,
    required this.discountPrice,
    required this.barCode,
  });
}

class StockData {
  static List<StockItem> stocks = [
    StockItem(
      name: 'Paracetamol',
      inStock: 50,
      originalPrice: 5.0,
      discountPrice: 3.5,
      barCode: '1234567890123',
    ),
    StockItem(
      name: 'Face Wash',
      inStock: 20,
      originalPrice: 10.0,
      discountPrice: 10.0,
      barCode: '2345678901234',
    ),
    StockItem(
      name: 'Sunscreen',
      inStock: 15,
      originalPrice: 12.0,
      discountPrice: 9.0,
      barCode: '3456789012345',
    ),
  ];

  static void addStock(StockItem item) {
    stocks.add(item);
  }

  static void removeStock(int index) {
    if (index >= 0 && index < stocks.length) {
      stocks.removeAt(index);
    }
  }

  static void clearAll() {
    stocks.clear();
  }
}
