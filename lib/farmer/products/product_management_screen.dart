import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_product_screen.dart';
import '../../utils/app_theme.dart';
import '../../models/product_model.dart'; // Ensure you have this model for easy parsing

class ProductManagementScreen extends StatelessWidget {
  final String farmId;
  const ProductManagementScreen({super.key, required this.farmId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
            return _buildEmptyState(context);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var productMap = doc.data() as Map<String, dynamic>;
              // Convert to Product object for cleaner code
              Product product = Product.fromFirestore(productMap, doc.id);
              
              return _buildProductCard(context, product);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AddProductScreen(farmId: farmId)),
        ),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inventory_2_outlined, size: 80, color: AppColors.grey),
          const SizedBox(height: 16),
          const Text(
            "No products added yet.", 
            style: TextStyle(fontSize: 18, color: AppColors.grey)
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AddProductScreen(farmId: farmId)),
            ),
            child: const Text(
              "Add Your First Product", 
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)
            ),
          )
        ],
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, Product product) {
    // Logic for stock color coding
    Color stockColor = Colors.green;
    String stockText = "${product.stock} ${product.unit} left";
    
    if (product.stock == 0) {
      stockColor = Colors.red;
      stockText = "Out of Stock";
    } else if (product.stock < 10) {
      stockColor = Colors.orange;
      stockText = "Low Stock: ${product.stock}";
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: AppColors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddProductScreen(
              farmId: farmId, 
              existingProduct: product, // Pass product to edit
            ),
          ),
        ),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            product.imageUrl, 
            width: 60, 
            height: 60, 
            fit: BoxFit.cover,
            errorBuilder: (ctx, _, __) => const Icon(Icons.broken_image, size: 40),
          ),
        ),
        title: Text(
          product.name, 
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Price: Rs. ${product.price}", style: const TextStyle(color: AppColors.grey)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: stockColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                stockText,
                style: TextStyle(color: stockColor, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.error),
              onPressed: () => _confirmDelete(context, product.id),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Product?"),
        content: const Text("This action cannot be undone. All related data will be removed."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("Cancel", style: TextStyle(color: AppColors.grey))
          ),
          TextButton(
            onPressed: () {
              FirebaseFirestore.instance.collection('products').doc(docId).delete();
              Navigator.pop(context);
            }, 
            child: const Text("Delete", style: TextStyle(color: AppColors.error))
          ),
        ],
      ),
    );
  }
}