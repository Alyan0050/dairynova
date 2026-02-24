import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../auth/auth_screen.dart';
import '../auth/register_farm_screen.dart';
import './products/product_management_screen.dart';
import './orders/farmer_orders_screen.dart';
import './orders/daily_delivery_list.dart';
import '../models/farm_model.dart';
import '../utils/app_theme.dart';
import '../widgets/farmer_waiting_screen.dart';
import '../widgets/farmer_rejected_screen.dart';
import '../widgets/farmer_stat_card.dart'; 

class FarmerDashboard extends StatefulWidget {
  const FarmerDashboard({super.key});

  @override
  State<FarmerDashboard> createState() => _FarmerDashboardState();
}

class _FarmerDashboardState extends State<FarmerDashboard> {
  int _selectedIndex = 0;
  final User? user = FirebaseAuth.instance.currentUser;
  bool _isUploading = false;
  
  final String _imgBBKey = "35a63ea828f028776d7fb98b32f08d10";

  // --- NEW: STOCK ALERT WIDGET ---
  // This listens specifically for products with 0 stock for this farm
  Widget _buildStockAlertBanner(String farmId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('farmId', isEqualTo: farmId)
          .where('stock', isEqualTo: 0)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.red),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Action Required: ${snapshot.data!.docs.length} products are Out of Stock!",
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _selectedIndex = 1), // Jump to Products tab
                  child: const Text("RESTOCK"),
                )
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  // --- IMAGE UPLOAD LOGIC (ImgBB) ---
  Future<void> _updateFarmPicture(String farmId) async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedImage = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);

    if (pickedImage == null) return;

    File imageFile = File(pickedImage.path); 
    setState(() => _isUploading = true);

    try {
      var request = http.MultipartRequest('POST', Uri.parse('https://api.imgbb.com/1/upload?key=$_imgBBKey'));
      request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var jsonResponse = jsonDecode(responseData);

      if (response.statusCode == 200) {
        String downloadUrl = jsonResponse['data']['url'];

        await FirebaseFirestore.instance.collection('farms').doc(farmId).update({
          'farmPhotos': [downloadUrl], 
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Farm photo updated successfully!")));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload Error: $e")));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // --- STATS BUILDERS ---
  Widget _buildEarningsStat(String farmId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('farmId', isEqualTo: farmId)
          .where('status', isEqualTo: 'Delivered')
          .snapshots(),
      builder: (context, snapshot) {
        double total = 0;
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            total += (doc['totalAmount'] ?? 0).toDouble();
          }
        }
        return FarmerStatCard(
          title: "Total Earnings",
          value: "Rs. ${total.toStringAsFixed(0)}",
          icon: Icons.payments_outlined,
          color: Colors.green,
        );
      },
    );
  }

  Widget _buildNewOrdersStat(String farmId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('farmId', isEqualTo: farmId)
          .where('status', isEqualTo: 'Pending')
          .snapshots(),
      builder: (context, snapshot) {
        int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
        return FarmerStatCard(
          title: "New Orders",
          value: count.toString().padLeft(2, '0'),
          icon: Icons.pending_actions,
          color: Colors.orange,
        );
      },
    );
  }

  Widget _buildActiveProductsStat(String farmId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('farmId', isEqualTo: farmId)
          .snapshots(),
      builder: (context, snapshot) {
        int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
        return FarmerStatCard(
          title: "Active Products",
          value: count.toString().padLeft(2, '0'),
          icon: Icons.grass,
          color: Colors.blue,
        );
      },
    );
  }

  Widget _buildRatingStat(String farmId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('farmId', isEqualTo: farmId)
          .snapshots(),
      builder: (context, snapshot) {
        double totalStars = 0;
        int reviewCount = 0;
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            var data = doc.data() as Map<String, dynamic>;
            if (data['rating'] != null) {
              totalStars += (data['rating'] as num).toDouble();
              reviewCount++;
            }
          }
        }
        double average = reviewCount == 0 ? 0.0 : totalStars / reviewCount;
        return FarmerStatCard(
          title: "Profile Rating",
          value: average == 0.0 ? "N/A" : average.toStringAsFixed(1),
          icon: Icons.star_rate_rounded,
          color: Colors.amber,
        );
      },
    );
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const AuthScreen()),
        (route) => false,
      );
    }
  }

  void _showProfileMenu(Map<String, dynamic> farmData) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const CircleAvatar(backgroundColor: AppColors.primary, child: Icon(Icons.person, color: Colors.white)),
              title: Text(farmData['ownerName'] ?? "Farmer", style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(farmData['farmName'] ?? "Farm Owner"),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: AppColors.primary),
              title: const Text("Update Farm Photo"),
              onTap: () {
                Navigator.pop(context);
                _updateFarmPicture(farmData['id']);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined, color: AppColors.primary),
              title: const Text("Edit Farm Profile"),
              onTap: () {
                Navigator.pop(context);
                final currentFarm = Farm.fromFirestore(farmData, farmData['id'] ?? "");
                Navigator.push(context, MaterialPageRoute(builder: (context) => RegisterFarmScreen(existingFarm: currentFarm)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.error),
              title: const Text("Logout", style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(context);
                _logout();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('farms')
          .where('ownerId', isEqualTo: user?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Scaffold(body: Center(child: Text("No farm found.")));

        var doc = snapshot.data!.docs.first;
        var farmData = doc.data() as Map<String, dynamic>;
        farmData['id'] = doc.id;
        String status = farmData['status'] ?? 'pending';

        if (status == 'pending') return Scaffold(body: FarmerWaitingScreen(farmName: farmData['farmName'] ?? "Farmer"));
        if (status == 'rejected') return Scaffold(body: FarmerRejectedScreen(farmData: farmData));

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(_getAppBarTitle(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            backgroundColor: AppColors.primary,
            actions: [
              if (_isUploading)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 15),
                  child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))),
                )
              else
                IconButton(icon: const Icon(Icons.account_circle, color: Colors.white, size: 28), onPressed: () => _showProfileMenu(farmData)),
            ],
          ),
          body: _getScreen(farmData['id'], farmData),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _selectedIndex,
            selectedItemColor: AppColors.primary,
            unselectedItemColor: AppColors.grey,
            onTap: (index) => setState(() => _selectedIndex = index),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: "Home"),
              BottomNavigationBarItem(icon: Icon(Icons.inventory_2_rounded), label: "Products"),
              BottomNavigationBarItem(icon: Icon(Icons.shopping_cart_rounded), label: "Orders"),
            ],
          ),
        );
      },
    );
  }

  String _getAppBarTitle() {
    switch (_selectedIndex) {
      case 0: return "Farmer Dashboard";
      case 1: return "Product Management";
      case 2: return "Customer Orders";
      default: return "Dairy Nova";
    }
  }

  Widget _getScreen(String farmId, Map<String, dynamic> farmData) {
    switch (_selectedIndex) {
      case 0: return _buildHomeTab(farmId, farmData);
      case 1: return ProductManagementScreen(farmId: farmId);
      case 2: return FarmerOrdersScreen(farmId: farmId);
      default: return _buildHomeTab(farmId, farmData);
    }
  }

  Widget _buildHomeTab(String farmId, Map<String, dynamic> farm) {
    String? farmPhoto = (farm['farmPhotos'] != null && (farm['farmPhotos'] as List).isNotEmpty) 
        ? farm['farmPhotos'][0] 
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderCard(farm, farmPhoto),
          const SizedBox(height: 24),
          
          // ADDED: STOCK ALERT SYSTEM
          _buildStockAlertBanner(farmId),

          const Text("Morning Routine", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              minimumSize: const Size(double.infinity, 55),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              side: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => DailyDeliveryList(farmId: farm['id']))),
            icon: const Icon(Icons.local_shipping_outlined),
            label: const Text("View Daily Delivery List", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 24),
          const Text("Live Performance", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildStatsGrid(farm['id']),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(Map<String, dynamic> farm, String? farmPhoto) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 35, 
            backgroundColor: AppColors.primary, 
            backgroundImage: farmPhoto != null ? NetworkImage(farmPhoto) : null,
            child: farmPhoto == null ? const Icon(Icons.storefront, color: Colors.white, size: 30) : null,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(farm['farmName'] ?? "My Farm", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const Text("Verified Partner", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(String farmId) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: [
        _buildNewOrdersStat(farmId),
        _buildEarningsStat(farmId),
        _buildActiveProductsStat(farmId),
        _buildRatingStat(farmId), 
      ],
    );
  }
}