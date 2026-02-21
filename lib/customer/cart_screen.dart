import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/cart_model.dart';
import '../utils/app_theme.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final TextEditingController _addressController = TextEditingController();
  bool _isPlacingOrder = false;
  
  // FR-05: Subscription Variables
  String _orderType = 'one-time'; 
  String _frequency = 'Daily';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
      }
    });
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Confirm Order", style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: cart.items.isEmpty
          ? const Center(child: Text("Your cart is empty"))
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildItems(cart),
                        _buildSubscriptionPicker(), // FR-05 UI
                        _buildAddress(),
                      ],
                    ),
                  ),
                ),
                _buildBottom(cart),
              ],
            ),
    );
  }

  Widget _buildItems(CartProvider cart) {
    final items = cart.items.values.toList();
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        return ListTile(
          title: Text(item.product.name),
          subtitle: Text("Rs ${item.product.price} x ${item.quantity}"),
          trailing: IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => cart.removeItem(item.product.id),
          ),
        );
      },
    );
  }

  Widget _buildSubscriptionPicker() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Order Type", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: [
                _typeChip("one-time", "One-time"),
                const SizedBox(width: 10),
                _typeChip("subscription", "Subscription"),
              ],
            ),
            if (_orderType == 'subscription') ...[
              const SizedBox(height: 15),
              const Text("Delivery Frequency", style: TextStyle(fontSize: 12, color: Colors.grey)),
              DropdownButton<String>(
                value: _frequency,
                isExpanded: true,
                items: ['Daily', 'Weekly', 'Monthly'].map((String value) {
                  return DropdownMenuItem<String>(value: value, child: Text(value));
                }).toList(),
                onChanged: (val) => setState(() => _frequency = val!),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _typeChip(String type, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _orderType == type,
      onSelected: (val) => setState(() => _orderType = type),
      selectedColor: AppColors.primary.withValues(alpha: 0.2),
    );
  }

  Widget _buildAddress() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _addressController,
        decoration: InputDecoration(
          hintText: "Enter delivery address",
          prefixIcon: const Icon(Icons.location_on),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _buildBottom(CartProvider cart) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 15),
          ),
          onPressed: _isPlacingOrder ? null : () => _placeOrder(cart),
          child: _isPlacingOrder
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text("Place Order (Rs ${cart.totalAmount})", style: const TextStyle(color: Colors.white)),
        ),
      ),
    );
  }

  Future<void> _placeOrder(CartProvider cart) async {
    if (_addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter address")));
      return;
    }

    setState(() => _isPlacingOrder = true);
    final user = FirebaseAuth.instance.currentUser;

    try {
      // 1. Fetch current customer name to sync with dashboards
      final userDoc = await FirebaseFirestore.instance.collection("users").doc(user?.uid).get();
      final String customerName = userDoc.data()?['name'] ?? "New Customer";

      // 2. Group items by farm if necessary, or place single order
      // In this current logic, we take the farmId from the first product
      final farmId = cart.items.values.first.product.farmId;

      await FirebaseFirestore.instance.collection("orders").add({
        "customerId": user?.uid,
        "customerName": customerName, // Critical field for Farmer/Customer view
        "farmId": farmId,
        "deliveryAddress": _addressController.text.trim(),
        "totalAmount": cart.totalAmount,
        "status": "Pending",
        "orderDate": FieldValue.serverTimestamp(),
        "orderType": _orderType, 
        "frequency": _orderType == 'subscription' ? _frequency : null, 
        "items": cart.items.values.map((i) => {
          "name": i.product.name,
          "quantity": i.quantity,
          "price": i.product.price,
        }).toList(),
      });

      cart.clearCart();
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Order placed successfully"), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isPlacingOrder = false);
    }
  }
}