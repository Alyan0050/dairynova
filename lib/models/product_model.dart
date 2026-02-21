class Product {
  final String id;
  final String farmId;
  final String name;
  final String category; // e.g., Milk, Yogurt, Cheese
  final double price;
  final String unit; // e.g., Ltr, Kg
  final int stock;
  final String imageUrl;

  Product({
    required this.id,
    required this.farmId,
    required this.name,
    required this.category,
    required this.price,
    required this.unit,
    required this.stock,
    required this.imageUrl,
  });

  factory Product.fromFirestore(Map<String, dynamic> data, String id) {
    return Product(
      id: id,
      farmId: data['farmId'] ?? '',
      name: data['name'] ?? '',
      category: data['category'] ?? 'Milk',
      price: (data['price'] ?? 0).toDouble(),
      unit: data['unit'] ?? 'Ltr',
      stock: data['stock'] ?? 0,
      imageUrl: data['imageUrl'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'farmId': farmId,
    'name': name,
    'category': category,
    'price': price,
    'unit': unit,
    'stock': stock,
    'imageUrl': imageUrl,
  };
}