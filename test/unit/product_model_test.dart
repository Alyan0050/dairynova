import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_nova_app/models/product_model.dart';

void main() {
  test('Product.fromFirestore and toMap roundtrip', () {
    final data = {
      'farmId': 'farm1',
      'name': 'Milk',
      'category': 'Milk',
      'price': 120,
      'unit': 'Ltr',
      'stock': 5,
      'imageUrl': 'https://example.com/img.png',
    };

    final p = Product.fromFirestore(data, 'p1');

    expect(p.id, 'p1');
    expect(p.name, 'Milk');
    expect(p.price, 120.0);
    expect(p.stock, 5);

    final map = p.toMap();
    expect(map['farmId'], 'farm1');
    expect(map['name'], 'Milk');
    expect(map['price'], 120.0);
  });
}
