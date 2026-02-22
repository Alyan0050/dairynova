import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../models/cart_model.dart';
import '../models/product_model.dart';
import '../utils/app_theme.dart';
import './cart_screen.dart';

class FarmProductsScreen extends StatelessWidget {
  final String farmId;
  final String farmName;

  const FarmProductsScreen({
    super.key,
    required this.farmId,
    required this.farmName,
  });

  @override
  Widget build(BuildContext context) {
    // We listen to the cart to update the badge and button states in real-time
    final cart = Provider.of<CartProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          farmName,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: () {
                  ScaffoldMessenger.of(context).clearSnackBars();
                  Future.microtask(() {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CartScreen()),
                    );
                  });
                },
              ),
              if (cart.itemCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: CircleAvatar(
                    radius: 8,
                    backgroundColor: Colors.red,
                    child: Text(
                      cart.itemCount.toString(),
                      style: const TextStyle(fontSize: 10, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('products')
            .where('farmId', isEqualTo: farmId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No products found."));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.65, // Increased height slightly for stock info
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var product = Product.fromFirestore(
                snapshot.data!.docs[index].data() as Map<String, dynamic>,
                snapshot.data!.docs[index].id,
              );
              return _buildProductCard(context, product);
            },
          );
        },
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, Product product) {
    // listen: true is required here to rebuild button when cart quantity changes
    final cart = Provider.of<CartProvider>(context);
    
    // Check if more can be added based on current cart and available stock
    final bool canAdd = cart.canAddMore(product);
    final bool isOutOfStock = product.stock <= 0;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                  child: Image.network(
                    product.imageUrl,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
                  ),
                ),
                if (isOutOfStock)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: Text("OUT OF STOCK", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  "Rs. ${product.price} / ${product.unit}",
                  style: const TextStyle(color: AppColors.primary, fontSize: 13),
                ),
                // Show current stock availability to the user
                Text(
                  isOutOfStock ? "Unavailable" : "Stock: ${product.stock} left",
                  style: TextStyle(
                    fontSize: 11, 
                    color: isOutOfStock ? Colors.red : (product.stock < 5 ? Colors.orange : Colors.grey)
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canAdd ? AppColors.primary : Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                    ),
                    // Button disables if stock is 0 OR limit reached in cart
                    onPressed: !canAdd ? null : () {
                      cart.addItem(product);
                      ScaffoldMessenger.of(context).clearSnackBars();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("${product.name} added to cart"),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                          action: SnackBarAction(
                            label: "UNDO",
                            textColor: Colors.yellow,
                            onPressed: () => cart.removeItem(product.id),
                          ),
                        ),
                      );
                    },
                    child: Text(
                      isOutOfStock ? "Sold Out" : (!canAdd ? "Limit Reached" : "Add to Cart"), 
                      style: const TextStyle(fontSize: 11)
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}