import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  
  String _orderType = 'one-time'; 
  String _frequency = 'Daily';

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
                        _buildSubscriptionPicker(), 
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
          title: Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text("Rs ${item.product.price} x ${item.quantity}"),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => cart.removeItem(item.product.id),
          ),
        );
      },
    );
  }

  Widget _buildSubscriptionPicker() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
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
      selectedColor: AppColors.primary.withOpacity(0.2),
    );
  }

  Widget _buildAddress() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _addressController,
        decoration: InputDecoration(
          labelText: "Delivery Address",
          hintText: "Enter your house/street info",
          prefixIcon: const Icon(Icons.location_on, color: AppColors.primary),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildBottom(CartProvider cart) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _isPlacingOrder ? null : () => _handleCheckout(cart),
          child: _isPlacingOrder
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text("Place Order (Rs ${cart.totalAmount})", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  // --- REFINED CHECKOUT HANDLER ---
  Future<void> _handleCheckout(CartProvider cart) async {
    final address = _addressController.text.trim();
    
    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a delivery address")));
      return;
    }

    setState(() => _isPlacingOrder = true);

    try {
      // Use the placeOrder method from CartProvider which now handles:
      // 1. Transactional stock reduction
      // 2. Fetching actual customer name
      // 3. Saving the order with the correct customerId
      final success = await cart.placeOrder(address);

      if (success && mounted) {
        Navigator.pop(context); // Go back to Home
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Order placed! Stock updated."), backgroundColor: Colors.green),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Order failed. Check stock or connection."), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isPlacingOrder = false);
    }
  }
}