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
        title: const Text("Confirm Order", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: cart.items.isEmpty
          ? _buildEmptyState()
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildItems(cart),
                        _buildSubscriptionPicker(), 
                        _buildAddress(),
                        _buildPriceSummary(cart),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                _buildBottom(cart),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_basket_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text("Your cart is empty", style: TextStyle(fontSize: 18, color: Colors.grey)),
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
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(item.product.imageUrl, width: 50, height: 50, fit: BoxFit.cover),
            ),
            title: Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("Rs ${item.product.price} x ${item.quantity}"),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => cart.removeItem(item.product.id),
            ),
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
            const Row(
              children: [
                Icon(Icons.repeat, size: 18, color: AppColors.primary),
                SizedBox(width: 8),
                const Text("Delivery Schedule", style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _typeChip("one-time", "One-time"),
                const SizedBox(width: 10),
                _typeChip("subscription", "Subscription"),
              ],
            ),
            if (_orderType == 'subscription') ...[
              const SizedBox(height: 15),
              const Text("How often should we deliver?", style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _frequency,
                    isExpanded: true,
                    items: ['Daily', 'Weekly', 'Monthly'].map((String value) {
                      return DropdownMenuItem<String>(value: value, child: Text(value));
                    }).toList(),
                    onChanged: (val) => setState(() => _frequency = val!),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _typeChip(String type, String label) {
    bool isSelected = _orderType == type;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) => setState(() => _orderType = type),
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
    );
  }

  Widget _buildAddress() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _addressController,
        maxLines: 2,
        decoration: InputDecoration(
          labelText: "Delivery Address",
          hintText: "Enter house #, street, and area",
          prefixIcon: const Icon(Icons.location_on, color: AppColors.primary),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildPriceSummary(CartProvider cart) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _summaryRow("Subtotal", "Rs ${cart.totalAmount}"),
          _summaryRow("Delivery Fee", "Rs 50"),
          const Divider(),
          _summaryRow("Total Payable", "Rs ${cart.totalAmount + 50}", isTotal: true),
        ],
      ),
    );
  }
Widget _summaryRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      // We remove the MainAxisAlignment.between and use a Spacer instead
      child: Row(
        children: [
          Text(
            label, 
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal, 
              fontSize: isTotal ? 16 : 14,
            ),
          ),
          // This Spacer pushes the following text to the far right
          const Spacer(), 
          Text(
            value, 
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal, 
              fontSize: isTotal ? 16 : 14, 
              color: isTotal ? AppColors.primary : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildBottom(CartProvider cart) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
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
              : Text("Place ${_orderType == 'subscription' ? 'Subscription' : 'Order'}", 
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Future<void> _handleCheckout(CartProvider cart) async {
    final address = _addressController.text.trim();
    
    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a delivery address")));
      return;
    }

    setState(() => _isPlacingOrder = true);

    try {
      final success = await cart.placeOrder(
        address,
        orderType: _orderType,
        frequency: _orderType == 'subscription' ? _frequency : null,
      );

      if (success && mounted) {
        // Clear screen stack and return to home on success
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_orderType == 'subscription' ? "Subscription started!" : "Order placed successfully!"), 
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Stock check failed. Some items might be unavailable."), backgroundColor: Colors.red),
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