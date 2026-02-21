import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../utils/app_theme.dart';
import '../models/cart_model.dart';
import './farm_products_screen.dart';
import './customer_orders_screen.dart';
import './cart_screen.dart';
import './subscription_management_screen.dart';
import './customer_settings_screen.dart'; // Added to connect profile management

class CustomerHome extends StatefulWidget {
  const CustomerHome({super.key});

  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome> {
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'Milk', 'Yogurt', 'Cheese', 'Butter', 'Ghee'];

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Dairy Nova", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          // Subscriptions Button
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined, color: Colors.white),
            tooltip: "Subscriptions",
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SubscriptionManagementScreen()),
            ),
          ),
          // Order History Button
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined, color: Colors.white),
            tooltip: "Orders",
            onPressed: () => Navigator.push(
              context, 
              MaterialPageRoute(builder: (context) => const CustomerOrdersScreen())
            ),
          ),
          // Cart Button with Badge
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
                tooltip: "Cart",
                onPressed: () => Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (context) => const CartScreen())
                ),
              ),
              if (cart.itemCount > 0)
                Positioned(
                  right: 5,
                  top: 5,
                  child: CircleAvatar(
                    radius: 8,
                    backgroundColor: Colors.red,
                    child: Text(cart.itemCount.toString(), style: const TextStyle(fontSize: 10, color: Colors.white)),
                  ),
                ),
            ],
          ),
          // NEW: Settings/Profile Button
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
            tooltip: "Profile Settings",
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CustomerSettingsScreen()),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildWelcomeHeader(),
          _buildCategoryList(),
          const Expanded(child: _FarmList()),
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Fresh from the Farm,", style: TextStyle(color: Colors.white70, fontSize: 16)),
          SizedBox(height: 5),
          Text("Order Pure Dairy Today!", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildCategoryList() {
    return SizedBox(
      height: 70,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          bool isSelected = _selectedCategory == _categories[index];
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ChoiceChip(
              label: Text(_categories[index]),
              selected: isSelected,
              onSelected: (val) => setState(() => _selectedCategory = _categories[index]),
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(color: isSelected ? Colors.white : AppColors.primary),
            ),
          );
        },
      ),
    );
  }
}

class _FarmList extends StatelessWidget {
  const _FarmList();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('farms')
          .where('status', isEqualTo: 'verified')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No verified farms available."));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var farm = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            String farmId = snapshot.data!.docs[index].id;

            return Card(
              margin: const EdgeInsets.only(bottom: 20),
              elevation: 4,
              shadowColor: Colors.black.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (context) => FarmProductsScreen(farmId: farmId, farmName: farm['farmName']))
                ),
                child: Column(
                  children: [
                    Image.network(
                      farm['farmPhotos'] != null && farm['farmPhotos'].isNotEmpty 
                          ? farm['farmPhotos'][0] 
                          : 'https://via.placeholder.com/150',
                      height: 160, 
                      width: double.infinity, 
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 160,
                        color: Colors.grey[200],
                        child: const Icon(Icons.storefront, size: 50, color: Colors.grey),
                      ),
                    ),
                    ListTile(
                      title: Text(farm['farmName'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(farm['location'] ?? "Location unknown"),
                      trailing: const Icon(Icons.chevron_right, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}