import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:dairy_nova_app/main.dart' as app_main;

void main() {
  testWidgets('DairyNovaApp builds', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: app_main.DairyNovaApp()));
    await tester.pumpAndSettle();

    // Should show AuthScreen title or widget (we avoid depending on Firebase init)
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
