import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets("Login screen UI test", (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: const [
              TextField(key: Key("email")),
              TextField(key: Key("password")),
              ElevatedButton(
                key: Key("loginBtn"),
                onPressed: null,
                child: Text("Login"),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byKey(const Key("email")), findsOneWidget);
    expect(find.byKey(const Key("password")), findsOneWidget);
    expect(find.byKey(const Key("loginBtn")), findsOneWidget);
  });
}
