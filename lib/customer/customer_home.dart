import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../utils/app_theme.dart';
import '../models/cart_model.dart';
import './farm_products_screen.dart';
import './customer_orders_screen.dart';
import './cart_screen.dart';
import './subscription_management_screen.dart';
import './customer_settings_screen.dart';

class CustomerHome extends StatefulWidget {
  const CustomerHome({super.key});

  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome> {
  String _selectedCategory = 'All';
  String _searchQuery = ""; 
  // Categories match the 'category' field in your Firestore products collection
  final List<String> _categories = ['All', 'Milk', 'Yogurt', 'Cheese', 'Butter', 'Ghee'];
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined, color: Colors.white),
            tooltip: "Subscriptions",
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SubscriptionManagementScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined, color: Colors.white),
            tooltip: "Orders",
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CustomerOrdersScreen())),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
                tooltip: "Cart",
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CartScreen())),
              ),
              if (cart.itemCount > 0)
                Positioned(
                  right: 5, top: 5,
                  child: CircleAvatar(
                    radius: 8, backgroundColor: Colors.red,
                    child: Text(cart.itemCount.toString(), style: const TextStyle(fontSize: 10, color: Colors.white)),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
            tooltip: "Settings",
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CustomerSettingsScreen())),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndWelcomeHeader(), 
          _buildCategoryList(),
          Expanded(
            child: _FarmList(
              selectedCategory: _selectedCategory,
              searchQuery: _searchQuery,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndWelcomeHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 25),
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Fresh from the Farm,", style: TextStyle(color: Colors.white70, fontSize: 14)),
          const Text("Order Pure Dairy Today!", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          // Search Bar Implementation
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
              decoration: InputDecoration(
                hintText: "Search dairy farms (e.g. Hamza Dairy)...",
                prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                suffixIcon: _searchQuery.isNotEmpty 
                  ? IconButton(
                      icon: const Icon(Icons.clear), 
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = "");
                      },
                    ) 
                  : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryList() {
    return SizedBox(
      height: 65,
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
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          );
        },
      ),
    );
  }
}

class _FarmList extends StatelessWidget {
  final String selectedCategory;
  final String searchQuery;
  const _FarmList({required this.selectedCategory, required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      // Only display farms that have been verified by the Admin
      stream: FirebaseFirestore.instance
          .collection('farms')
          .where('status', isEqualTo: 'verified')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No verified farms available right now."));
        }

        // Local Filtering for search and category
        var farms = snapshot.data!.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          var name = (data['farmName'] ?? "").toString().toLowerCase();
          
          // Matches search query if provided
          return name.contains(searchQuery);
        }).toList();

        if (farms.isEmpty) {
          return const Center(child: Text("No farms found matching your search."));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: farms.length,
          itemBuilder: (context, index) {
            var farm = farms[index].data() as Map<String, dynamic>;
            String farmId = farms[index].id;

            return Card(
              margin: const EdgeInsets.only(bottom: 20),
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (context) => FarmProductsScreen(
                    farmId: farmId, 
                    farmName: farm['farmName'],
                    categoryFilter: selectedCategory, // Passes the active filter
                  ))
                ),
                child: Column(
                  children: [
                    Image.network(
                      farm['farmPhotos'] != null && farm['farmPhotos'].isNotEmpty 
                          ? farm['farmPhotos'][0] 
                          : 'https://via.placeholder.com/150',
                      height: 160, width: double.infinity, fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 160, color: Colors.grey[200],
                        child: const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                      ),
                    ),
                    ListTile(
                      title: Text(farm['farmName'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(farm['location'] ?? "Location not specified"),
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