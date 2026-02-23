import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:dairy_nova_app/models/cart_model.dart';
import 'package:dairy_nova_app/models/product_model.dart';

class _TestUser {
  final String uid;
  _TestUser(this.uid);
}

void main() {
  test('placeOrder succeeds and updates stock and creates order', () async {
    final fake = FakeFirebaseFirestore();

    // Seed product in Firestore
    await fake.collection('products').doc('prod1').set({
      'stock': 10,
      'name': 'Fresh Milk',
      'farmId': 'farmA',
      'price': 12.5,
    });

    // Seed user doc
    await fake.collection('users').doc('user123').set({'name': 'Test User'});

    final cart = CartProvider();
    final product = Product(
      id: 'prod1',
      farmId: 'farmA',
      name: 'Fresh Milk',
      category: 'Milk',
      price: 12.5,
      unit: 'Ltr',
      stock: 5,
      imageUrl: '',
    );

    cart.addItem(product);

    final success = await cart.placeOrder('123 Main St', firestore: fake, userForTest: _TestUser('user123'));

    expect(success, isTrue);

    // Verify order created
    final orders = await fake.collection('orders').get();
    expect(orders.docs.isNotEmpty, isTrue);

    // Verify stock decreased
    final prodSnap = await fake.collection('products').doc('prod1').get();
    expect(prodSnap.get('stock'), 9);

    // Cart should be cleared
    expect(cart.itemCount, 0);
  });

  test('placeOrder fails when Firestore stock insufficient', () async {
    final fake = FakeFirebaseFirestore();

    // Seed product with 0 stock in Firestore
    await fake.collection('products').doc('prod2').set({
      'stock': 0,
      'name': 'Cheese',
      'farmId': 'farmB',
      'price': 20.0,
    });

    // Seed user doc
    await fake.collection('users').doc('user456').set({'name': 'Low Stock User'});

    final cart = CartProvider();
    final product = Product(
      id: 'prod2',
      farmId: 'farmB',
      name: 'Cheese',
      category: 'Dairy',
      price: 20.0,
      unit: 'Kg',
      stock: 10,
      imageUrl: '',
    );

    cart.addItem(product);

    final success = await cart.placeOrder('456 Oak St', firestore: fake, userForTest: _TestUser('user456'));

    expect(success, isFalse);

    // Cart should remain
    expect(cart.itemCount, greaterThan(0));
  });
}
