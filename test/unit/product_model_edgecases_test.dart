import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_nova_app/models/product_model.dart';

void main() {
  test('Product.fromFirestore handles string price and stock', () {
    final data = {
      'farmId': 'f1',
      'name': 'Yogurt',
      'category': 'Yogurt',
      'price': '45.5',
      'unit': 'Pack',
      'stock': '3',
      'imageUrl': ''
    };

    final p = Product.fromFirestore(data, 'p2');

    expect(p.id, 'p2');
    expect(p.price, 45.5);
    expect(p.stock, 3);
  });
}
