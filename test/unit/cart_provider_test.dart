import 'package:flutter_test/flutter_test.dart';

class Cart {
  List<String> items = [];

  void addItem(String item) {
    items.add(item);
  }

  void removeItem(String item) {
    items.remove(item);
  }
}

void main() {
  late Cart cart;

  setUp(() {
    cart = Cart();
  });

  test("Add item to cart", () {
    cart.addItem("Milk");

    expect(cart.items.length, 1);
  });

  test("Remove item from cart", () {
    cart.addItem("Milk");
    cart.removeItem("Milk");

    expect(cart.items.isEmpty, true);
  });
}
