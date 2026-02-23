import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:dairy_nova_app/customer/cart_screen.dart';
import 'package:dairy_nova_app/models/cart_model.dart';
import 'package:dairy_nova_app/models/product_model.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;

  setUp(() async {
    fakeFirestore = FakeFirebaseFirestore();

    mockUser = MockUser(
      uid: 'test_user_123',
      email: 'test@email.com',
    );

    mockAuth = MockFirebaseAuth(
      signedIn: true,
      mockUser: mockUser,
    );

    // Insert fake cart data into Firestore
    await fakeFirestore
        .collection('users')
        .doc(mockUser.uid)
        .collection('cart')
        .doc('item1')
        .set({
      'name': 'Milk',
      'price': 120,
      'quantity': 2,
      'imageUrl': '',
    });
  });

  Widget createTestWidget() {
    final cartProvider = CartProvider();

    // add a sample product so UI shows items without Firestore
    cartProvider.addItem(Product(
      id: 'p1',
      farmId: 'farm1',
      name: 'Milk',
      category: 'Milk',
      price: 120.0,
      unit: 'Ltr',
      stock: 10,
      imageUrl: '',
    ));

    return ChangeNotifierProvider<CartProvider>.value(
      value: cartProvider,
      child: const MaterialApp(
        home: CartScreen(),
      ),
    );
  }

  testWidgets("Cart Screen loads correctly", (WidgetTester tester) async {
    await tester.pumpWidget(createTestWidget());

    // allow async loading
    await tester.pumpAndSettle();

    expect(find.text("Confirm Order"), findsOneWidget);
  });

  testWidgets("Cart displays items", (WidgetTester tester) async {
    await tester.pumpWidget(createTestWidget());

    await tester.pumpAndSettle();

    expect(find.textContaining("Milk"), findsOneWidget);
  });

  testWidgets("Cart shows quantity", (WidgetTester tester) async {
    await tester.pumpWidget(createTestWidget());

    await tester.pumpAndSettle();

    expect(find.textContaining("2"), findsWidgets);
  });

  testWidgets("Checkout button exists", (WidgetTester tester) async {
    await tester.pumpWidget(createTestWidget());

    await tester.pumpAndSettle();

    expect(find.byType(ElevatedButton), findsWidgets);
  });

  testWidgets("Cart screen does not crash", (WidgetTester tester) async {
    await tester.pumpWidget(createTestWidget());

    await tester.pumpAndSettle();

    expect(find.byType(Scaffold), findsOneWidget);
  });
}