import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:dairy_nova_app/farmer/products/add_product_screen.dart';

void main() {
  testWidgets('AddProductScreen basic UI elements', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: AddProductScreen(farmId: 'farm1')));

    // initial UI shows upload image placeholder and form fields
    expect(find.text('Product Photo'), findsOneWidget);
    expect(find.widgetWithIcon(ElevatedButton, Icons.add), findsNothing);
    expect(find.byType(TextFormField), findsWidgets);
  });
}
