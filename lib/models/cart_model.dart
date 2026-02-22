import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'product_model.dart';

class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});
}

class CartProvider with ChangeNotifier {
  final Map<String, CartItem> _items = {};

  Map<String, CartItem> get items => {..._items};

  int get itemCount => _items.length;

  double get totalAmount {
    double total = 0.0;
    _items.forEach((key, cartItem) {
      total += cartItem.product.price * cartItem.quantity;
    });
    return total;
  }

  bool canAddMore(Product product) {
    final existingItem = _items[product.id];
    if (existingItem == null) {
      return product.stock > 0;
    }
    return existingItem.quantity < product.stock;
  }

  void addItem(Product product) {
    if (!canAddMore(product)) return;

    if (_items.containsKey(product.id)) {
      _items.update(
        product.id,
        (existing) => CartItem(
          product: existing.product,
          quantity: existing.quantity + 1,
        ),
      );
    } else {
      _items.putIfAbsent(product.id, () => CartItem(product: product));
    }
    notifyListeners();
  }

  void removeItem(String productId) {
    _items.remove(productId);
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }

  // --- UPDATED: TRANSACTION-SAFE PLACE ORDER ---
  Future<bool> placeOrder(String deliveryAddress, {String orderType = 'one-time', String? frequency}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _items.isEmpty) return false;

    final firestore = FirebaseFirestore.instance;

    try {
      final userDoc = await firestore.collection('users').doc(user.uid).get();
      String actualName = userDoc.data()?['name'] ?? "New Customer";
      final String primaryFarmId = _items.values.first.product.farmId;

      await firestore.runTransaction((transaction) async {
        // 1. ALL READS FIRST: Collect snapshots and validate stock
        List<Map<String, dynamic>> stockUpdates = [];

        for (var cartItem in _items.values) {
          DocumentReference productRef = firestore.collection('products').doc(cartItem.product.id);
          DocumentSnapshot productSnap = await transaction.get(productRef); // READ operation

          if (!productSnap.exists) {
            throw Exception("Product ${cartItem.product.name} no longer exists.");
          }

          int currentStock = productSnap.get('stock') ?? 0;

          if (currentStock < cartItem.quantity) {
            throw Exception("Not enough stock for ${cartItem.product.name}.");
          }

          stockUpdates.add({
            'ref': productRef,
            'newStock': currentStock - cartItem.quantity,
          });
        }

        // 2. ALL WRITES AFTER READS: Update stock and create order
        for (var update in stockUpdates) {
          transaction.update(update['ref'], {'stock': update['newStock']}); // WRITE operation
        }

        DocumentReference orderRef = firestore.collection('orders').doc();
        transaction.set(orderRef, {
          'customerId': user.uid,
          'customerName': actualName,
          'farmId': primaryFarmId,
          'deliveryAddress': deliveryAddress,
          'totalAmount': totalAmount,
          'status': 'Pending',
          'orderType': orderType, // Added for subscriptions
          'frequency': frequency,  // Added for subscriptions
          'orderDate': FieldValue.serverTimestamp(),
          'items': _items.values.map((i) => {
            'productId': i.product.id,
            'name': i.product.name,
            'price': i.product.price,
            'quantity': i.quantity,
            'farmId': i.product.farmId,
          }).toList(),
        });
      });

      clearCart();
      return true;
    } catch (e) {
      debugPrint("Order/Stock Error: $e");
      return false;
    }
  }
}