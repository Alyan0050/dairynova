import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_product_screen.dart';
import '../../utils/app_theme.dart'; // The yellow line will disappear once we use AppColors

class ProductManagementScreen extends StatelessWidget {
  final String farmId;
  const ProductManagementScreen({super.key, required this.farmId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Removed the AppBar from here because it's now handled by the FarmerDashboard
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
              var product = snapshot.data!.docs[index].data() as Map<String, dynamic>;
              String docId = snapshot.data!.docs[index].id;
              return _buildProductCard(context, product, docId);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AddProductScreen(farmId: farmId)),
        ),
        backgroundColor: AppColors.primary, // Using the theme to remove the yellow line
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

  Widget _buildProductCard(BuildContext context, Map<String, dynamic> product, String docId) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: AppColors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            product['imageUrl'], 
            width: 50, 
            height: 50, 
            fit: BoxFit.cover,
            errorBuilder: (ctx, _, __) => const Icon(Icons.broken_image),
          ),
        ),
        title: Text(
          product['name'], 
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)
        ),
        subtitle: Text(
          "Price: Rs. ${product['price']} | Stock: ${product['stock']}",
          style: const TextStyle(color: AppColors.grey),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.error),
          onPressed: () => _confirmDelete(context, docId),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Product?"),
        content: const Text("This action cannot be undone."),
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