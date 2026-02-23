import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_nova_app/models/product_model.dart';
import 'package:dairy_nova_app/models/cart_model.dart';

void main() {
  test('CartProvider add/remove/total', () {
    final cart = CartProvider();

    final product = Product(
      id: 'p1',
      farmId: 'farm1',
      name: 'Milk',
      category: 'Milk',
      price: 100.0,
      unit: 'Ltr',
      stock: 10,
      imageUrl: '',
    );

    expect(cart.itemCount, 0);

    cart.addItem(product);
    expect(cart.itemCount, 1);
    expect(cart.totalAmount, 100.0);

    cart.addItem(product);
    expect(cart.itemCount, 1);
    expect(cart.totalAmount, 200.0);

    cart.removeItem('p1');
    expect(cart.itemCount, 0);
    expect(cart.totalAmount, 0.0);
  });
}
