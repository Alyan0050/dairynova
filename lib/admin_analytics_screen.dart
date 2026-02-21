import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_theme.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  // Default filter set to Last 7 Days as per Dairy Nova requirements
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  String _filterLabel = "Last 7 Days";

  void _updateFilter(int days, String label) {
    setState(() {
      _startDate = DateTime.now().subtract(Duration(days: days));
      _filterLabel = label;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Platform Analytics", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black87,
        elevation: 0,
        actions: [
          PopupMenuButton<int>(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onSelected: (days) {
              String label = days == 0 ? "Today" : "Last $days Days";
              _updateFilter(days, label);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 0, child: Text("Today")),
              const PopupMenuItem(value: 7, child: Text("Last 7 Days")),
              const PopupMenuItem(value: 30, child: Text("Last 30 Days")),
            ],
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('orderDate', isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate))
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          
          double totalRev = 0;
          Map<String, double> farmRevenue = {};
          
          // Aggregate revenue only for Delivered orders
          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            double amount = (data['totalAmount'] ?? data['total'] ?? 0).toDouble();
            String fId = data['farmId'] ?? "Unknown";

            if (data['status'] == 'Delivered') {
              totalRev += amount;
              farmRevenue[fId] = (farmRevenue[fId] ?? 0) + amount;
            }
          }

          // Determine the ID of the top-performing farm
          String topFarmId = "N/A";
          double topFarmAmount = 0;
          if (farmRevenue.isNotEmpty) {
            var sortedFarms = farmRevenue.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));
            topFarmId = sortedFarms.first.key;
            topFarmAmount = sortedFarms.first.value;
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Performance: $_filterLabel", 
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Icon(Icons.trending_up, color: Colors.green.shade700),
                ],
              ),
              const SizedBox(height: 15),
              _buildRevenueChart(docs),
              const SizedBox(height: 25),
              
              const Text("Key Performance Indicators", 
                  style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),

              // DYNAMIC TOP FARM LOOKUP
              topFarmId == "N/A" 
                ? _metricTile(icon: Icons.stars, color: Colors.amber, title: "Top Farm: N/A", value: "Rs. 0")
                : FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('farms').doc(topFarmId).get(),
                    builder: (context, farmSnap) {
                      String realName = "Loading...";
                      if (farmSnap.hasData && farmSnap.data!.exists) {
                        realName = (farmSnap.data!.data() as Map<String, dynamic>)['farmName'] ?? "Unnamed Farm";
                      } else if (farmSnap.connectionState == ConnectionState.done && !farmSnap.data!.exists) {
                        realName = "Farm Not Found";
                      }

                      return _metricTile(
                        icon: Icons.stars,
                        color: Colors.amber,
                        title: "Top Farm: $realName",
                        value: "Rs. ${topFarmAmount.toStringAsFixed(0)}",
                      );
                    },
                  ),
                  
              const SizedBox(height: 10),
              _metricTile(
                icon: Icons.account_balance_wallet,
                color: Colors.green,
                title: "Total Revenue",
                value: "Rs. ${totalRev.toStringAsFixed(0)}",
              ),
              const SizedBox(height: 10),
              _metricTile(
                icon: Icons.shopping_cart,
                color: Colors.blue,
                title: "Order Volume",
                value: "${docs.length} Orders",
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRevenueChart(List<QueryDocumentSnapshot> docs) {
    return Container(
      height: 240,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          const Text("Order Value Distribution", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: docs.take(6).map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              double val = (data['totalAmount'] ?? data['total'] ?? 0).toDouble();
              double normalizedHeight = (val / 2000) * 150; 
              if (normalizedHeight > 150) normalizedHeight = 150;
              
              return _Bar(
                label: doc.id.substring(0, 3).toUpperCase(),
                height: normalizedHeight > 10 ? normalizedHeight : 10,
                color: data['status'] == 'Delivered' ? AppColors.primary : Colors.blue.shade300,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _metricTile({required IconData icon, required Color color, required String title, required String value}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        trailing: Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.grey.shade800)),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final String label;
  final double height;
  final Color color;
  const _Bar({required this.label, required this.height, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 32,
          height: height,
          decoration: BoxDecoration(
            color: color, 
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
      ],
    );
  }
}