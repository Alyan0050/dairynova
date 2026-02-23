import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets("Full app login flow", (tester) async {

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              TextField(key: Key("email")),
              TextField(key: Key("password")),
              ElevatedButton(
                key: Key("loginBtn"),
                onPressed: () {},
                child: Text("Login"),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.enterText(find.byKey(Key("email")), "test@gmail.com");

    await tester.enterText(find.byKey(Key("password")), "123456");

    await tester.tap(find.byKey(Key("loginBtn")));

    await tester.pumpAndSettle();

    expect(find.text("Login"), findsOneWidget);
  });
}
