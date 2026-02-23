import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // Needed for platform checks
import 'package:cloud_firestore/cloud_firestore.dart';
import './admin_analytics_screen.dart';
import './admin_settings_screen.dart';
import './admin_verification_screen.dart';
import '../admin/verified_farms_screen.dart'; 
import './admin_analytics_servics.dart'; 

const Color kPrimaryColor = Color(0xFF2E7D32);

// ================= MAIN DASHBOARD =================

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;

  // Added VerifiedFarmsScreen to the main navigation stack
  final List<Widget> _screens = const [
    DashboardHome(),
    AdminVerificationScreen(),
    VerifiedFarmsScreen(),
    AdminAnalyticsScreen(),
    AdminSettingsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      appBar: AppBar(
        backgroundColor: kPrimaryColor,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Dairy Nova Admin",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active, color: Colors.white),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                builder: (context) => const NotificationSheet(),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: kPrimaryColor,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.pending_actions), label: 'Approve'),
          BottomNavigationBarItem(icon: Icon(Icons.verified_user), label: 'Farms'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics_outlined), label: 'Stats'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_suggest), label: 'Settings'),
        ],
      ),
    );
  }
}

// ================= HOME OVERVIEW =================

class DashboardHome extends StatelessWidget {
  const DashboardHome({super.key});

  @override
  Widget build(BuildContext context) {
    // Uses kIsWeb to resolve the yellow warning line and show platform status
    final String platformMsg = kIsWeb ? "Admin Web Portal" : "Admin Mobile App";

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("System Overview",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kPrimaryColor)),
            Text(platformMsg, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 16),

        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            // 1. Total Customers
            StreamBuilder<int>(
              stream: AdminAnalytics.customerCount,
              builder: (context, snapshot) => _StatCard(
                title: "Total Customers",
                value: "${snapshot.data ?? 0}",
                icon: Icons.people_alt,
                color: Colors.green,
              ),
            ),
            // 2. Active Verified Farms - FIXED: Matches status string in Firestore
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('farms')
                  .where('status', isEqualTo: 'verified') 
                  .snapshots(),
              builder: (context, snapshot) {
                final count = snapshot.data?.docs.length ?? 0;
                return _StatCard(
                  title: "Active Farms",
                  value: "$count",
                  icon: Icons.check_circle,
                  color: Colors.blue,
                );
              },
            ),
            // 3. Pending Verifications
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('farms')
                  .where('status', isEqualTo: 'pending')
                  .snapshots(),
              builder: (context, snapshot) {
                final count = snapshot.data?.docs.length ?? 0;
                return _StatCard(
                  title: "Pending Farms",
                  value: "$count",
                  icon: Icons.hourglass_empty_rounded,
                  color: Colors.orange,
                );
              },
            ),
            // 4. Financial Revenue
            StreamBuilder<double>(
              stream: AdminAnalytics.totalRevenueStream,
              builder: (context, snapshot) => _StatCard(
                title: "Total Revenue",
                value: "Rs. ${snapshot.data?.toStringAsFixed(0) ?? '0'}",
                icon: Icons.account_balance_wallet,
                color: Colors.purple,
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),
        const Text("Recent Activity",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),

        // Recent Orders List with Null Safety to prevent red screen error
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('orders')
              .orderBy('orderDate', descending: true)
              .limit(5)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Text("No recent orders found.");

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                final order = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                final customer = order['customerName'] ?? 'Guest';
                final status = order['status'] ?? 'Processing';
                final amount = (order['totalAmount'] ?? 0).toString();

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: kPrimaryColor,
                      child: Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 20),
                    ),
                    title: Text("Order: $customer", style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text("Status: $status"),
                    trailing: Text("Rs. $amount",
                        style: const TextStyle(fontWeight: FontWeight.bold, color: kPrimaryColor)),
                  ),
                );
              },
            );
          },
        ),
      ]),
    );
  }
}

// ================= NOTIFICATION SHEET =================

class NotificationSheet extends StatelessWidget {
  const NotificationSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          const Text("Pending Approvals", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Divider(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('farms')
                  .where('status', isEqualTo: 'pending')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No new notifications."));
                }
                return ListView(
                  children: snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return ListTile(
                      leading: const Icon(Icons.notification_important, color: Colors.orange),
                      title: Text(data['farmName'] ?? 'New Farm Registered'),
                      subtitle: const Text("Awaiting verification check"),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ================= STAT CARD WIDGET =================

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 30, color: color),
          const SizedBox(height: 10),
          FittedBox(
            child: Text(
              value,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}