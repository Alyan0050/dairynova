import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../models/cart_model.dart';
import '../models/product_model.dart';
import '../utils/app_theme.dart';
import './cart_screen.dart';

class FarmProductsScreen extends StatefulWidget {
  final String farmId;
  final String farmName;
  final String categoryFilter; // Correctly defined parameter

  const FarmProductsScreen({
    super.key,
    required this.farmId,
    required this.farmName,
    this.categoryFilter = 'All', // Default value to prevent null issues
  });

  @override
  State<FarmProductsScreen> createState() => _FarmProductsScreenState();
}

class _FarmProductsScreenState extends State<FarmProductsScreen> {
  late String _currentCategory;

  @override
  void initState() {
    super.initState();
    // Initialize the local filter state with the value passed from CustomerHome
    _currentCategory = widget.categoryFilter;
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.farmName,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          _buildCartBadge(cart),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBanner(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // Logic: Filters by farmId AND category if a specific filter is active
              stream: _currentCategory == 'All'
                  ? FirebaseFirestore.instance
                      .collection('products')
                      .where('farmId', isEqualTo: widget.farmId)
                      .snapshots()
                  : FirebaseFirestore.instance
                      .collection('products')
                      .where('farmId', isEqualTo: widget.farmId)
                      .where('category', isEqualTo: _currentCategory)
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off, size: 60, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text("No products found for $_currentCategory"),
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.65,
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
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBanner() {
    if (_currentCategory == 'All') return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: AppColors.primary.withOpacity(0.1),
      child: Row(
        children: [
          const Icon(Icons.filter_list, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            "Showing: $_currentCategory",
            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => setState(() => _currentCategory = 'All'),
            child: const Text("Clear Filter"),
          ),
        ],
      ),
    );
  }

  Widget _buildCartBadge(CartProvider cart) {
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.shopping_cart),
          onPressed: () {
            ScaffoldMessenger.of(context).clearSnackBars();
            Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen()));
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
    );
  }

  Widget _buildProductCard(BuildContext context, Product product) {
    final cart = Provider.of<CartProvider>(context);
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
                    child: (product.imageUrl != null && product.imageUrl.isNotEmpty)
                        ? Image.network(
                            product.imageUrl,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
                          )
                        : Container(width: double.infinity, height: double.infinity, color: Colors.grey[200], child: const Icon(Icons.image),),
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
                Text("Rs. ${product.price} / ${product.unit}", style: const TextStyle(color: AppColors.primary, fontSize: 13)),
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