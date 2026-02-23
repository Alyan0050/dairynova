import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:dairy_nova_app/auth/register_farm_screen.dart';

void main() {
  testWidgets('RegisterFarmScreen shows CNIC and farm photo boxes', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: RegisterFarmScreen()));

    expect(find.text('CNIC Document'), findsOneWidget);
    expect(find.text('Farm Photos'), findsOneWidget);
    // There should be a grid of photo boxes (5 items)
    expect(find.byType(GridView), findsOneWidget);
  });
}
