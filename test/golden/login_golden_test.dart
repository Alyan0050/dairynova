import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Login UI basic layout', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Text('Dairy Nova'),
              TextField(),
              TextField(),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Dairy Nova'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  });
}
