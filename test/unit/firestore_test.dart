import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

void main() {
  test('Firestore add test', () async {
    final firestore = FakeFirebaseFirestore();

    await firestore.collection('cart').add({
      'name': 'Milk',
      'price': 120,
    });

    final snapshot = await firestore.collection('cart').get();

    expect(snapshot.docs.length, 1);
  });
}
