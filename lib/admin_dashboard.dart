import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import './admin_analytics_screen.dart';
import './admin_settings_screen.dart';
import './admin_verification_screen.dart';
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

  final List<Widget> _screens = const [
    DashboardHome(),
    AdminVerificationScreen(),
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
        title: const Text(
          "Dairy Nova Admin",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
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
        type: BottomNavigationBarType.fixed,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.verified_user), label: 'Verify'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Analytics'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

// ================= HOME =================

class DashboardHome extends StatelessWidget {
  const DashboardHome({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("System Overview",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kPrimaryColor)),
        const SizedBox(height: 16),

        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            StreamBuilder<int>(
              stream: AdminAnalytics.customerCount,
              builder: (context, snapshot) => _StatCard(
                title: "Total Customers",
                value: "${snapshot.data ?? 0}",
                icon: Icons.people,
                color: Colors.green,
              ),
            ),
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
                  icon: Icons.warning_amber,
                  color: Colors.orange,
                );
              },
            ),
            StreamBuilder<double>(
              stream: AdminAnalytics.totalRevenueStream,
              builder: (context, snapshot) => _StatCard(
                title: "Total Revenue",
                value: "Rs. ${snapshot.data?.toStringAsFixed(0) ?? '0'}",
                icon: Icons.payments,
                color: Colors.purple,
              ),
            ),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('riders').snapshots(),
              builder: (context, snapshot) {
                final count = snapshot.data?.docs.length ?? 0;
                return _StatCard(
                  title: "Active Riders",
                  value: "$count",
                  icon: Icons.motorcycle,
                  color: Colors.blue,
                );
              },
            ),
          ],
        ),

        const SizedBox(height: 24),
        const Text("Recent Activity",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),

        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('orders')
              .orderBy('orderDate', descending: true)
              .limit(5)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const LinearProgressIndicator();
            if (snapshot.data!.docs.isEmpty) return const Text("No recent orders.");

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                final order = snapshot.data!.docs[index].data() as Map<String, dynamic>;

                final customer = order['customerName'] ?? order['customer'] ?? 'Customer';
                final status = order['status'] ?? 'Pending';
                final amount = order['totalAmount'] ?? order['total'] ?? 0;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: kPrimaryColor,
                      child: Icon(Icons.shopping_basket, color: Colors.white),
                    ),
                    title: Text("Order from $customer"),
                    subtitle: Text("Status: $status"),
                    trailing: Text("Rs. $amount",
                        style: const TextStyle(fontWeight: FontWeight.bold)),
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

// ================= ALERTS =================

class NotificationSheet extends StatelessWidget {
  const NotificationSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 400,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('farms')
            .where('status', isEqualTo: 'pending')
            .limit(5)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No urgent alerts."));
          }

          return ListView(
            children: snapshot.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return ListTile(
                leading: const Icon(Icons.warning, color: Colors.orange),
                title: Text("New Farm: ${data['farmName'] ?? 'Unnamed Farm'}"),
                subtitle: const Text("Requires verification"),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

// ================= STAT CARD =================

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
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
