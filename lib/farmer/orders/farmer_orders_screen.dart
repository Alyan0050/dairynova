import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart'; 
import '../../../utils/app_theme.dart';

class FarmerOrdersScreen extends StatefulWidget {
  final String farmId;
  const FarmerOrdersScreen({super.key, required this.farmId});

  @override
  State<FarmerOrdersScreen> createState() => _FarmerOrdersScreenState();
}

class _FarmerOrdersScreenState extends State<FarmerOrdersScreen> {
  String _selectedFilter = 'All';

  Future<void> _callCustomer(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final Uri launchUri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Manage Orders", style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          _buildStatusFilter(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // Querying using the root-level farmId for direct access
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .where('farmId', isEqualTo: widget.farmId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No orders found."));
                }

                var docs = snapshot.data!.docs;

                // Apply status filter locally
                if (_selectedFilter != 'All') {
                  docs = docs.where((doc) => doc['status'] == _selectedFilter).toList();
                }

                // Sorting: Newest first
                docs.sort((a, b) {
                  var aDate = (a['orderDate'] ?? a['date']) as Timestamp?;
                  var bDate = (b['orderDate'] ?? b['date']) as Timestamp?;
                  if (aDate == null || bDate == null) return 0;
                  return bDate.compareTo(aDate);
                });

                if (docs.isEmpty) {
                  return const Center(child: Text("No orders with this status."));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var orderData = docs[index].data() as Map<String, dynamic>;
                    String orderId = docs[index].id;
                    return _buildManagementCard(context, orderId, orderData);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilter() {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: ['All', 'Pending', 'Accepted', 'Shipped', 'Delivered', 'Cancelled'].map((status) {
          bool isSelected = _selectedFilter == status;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(status, style: TextStyle(color: isSelected ? Colors.white : Colors.black)),
              selected: isSelected,
              selectedColor: AppColors.primary,
              onSelected: (val) => setState(() => _selectedFilter = status),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildManagementCard(BuildContext context, String id, Map<String, dynamic> data) {
    String status = data['status'] ?? 'Pending';
    var total = data['totalAmount'] ?? data['total'] ?? 0.0;
    List items = data['items'] ?? [];
    String address = data['deliveryAddress'] ?? data['address'] ?? 'No address';
    String customerName = data['customerName'] ?? "New Customer";
    String? customerPhone = data['customerPhone']; 

    bool isSubscription = data['orderType'] == 'subscription';
    String frequency = data['frequency'] ?? '';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ExpansionTile(
        title: Text(customerName, 
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppColors.primary)),
        subtitle: Text("Status: $status | Rs. $total", 
            style: TextStyle(color: _getStatusColor(status), fontWeight: FontWeight.bold, fontSize: 13)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                if (customerPhone != null)
                  ElevatedButton.icon(
                    onPressed: () => _callCustomer(customerPhone),
                    icon: const Icon(Icons.phone),
                    label: const Text("Call Customer"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green, foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 40),
                    ),
                  ),
                const SizedBox(height: 10),
                if (isSubscription)
                  Text("🔁 Recurring: $frequency", 
                      style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                Text("📍 Address: $address", style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 12),
                const Text("Items:", style: TextStyle(fontWeight: FontWeight.bold)),
                ...items.map((item) => Text("• ${item['name']} x${item['quantity']}")),
                const SizedBox(height: 20),
                const Text("Update Status:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _actionChip(context, id, "Accepted", Colors.blue),
                    _actionChip(context, id, "Shipped", Colors.purple),
                    _actionChip(context, id, "Delivered", Colors.green),
                    _actionChip(context, id, "Cancelled", Colors.red),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionChip(BuildContext context, String orderId, String label, Color color) {
    return ActionChip(
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
      backgroundColor: color,
      onPressed: () async {
        await FirebaseFirestore.instance.collection('orders').doc(orderId).update({'status': label});
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Order is now $label")));
        }
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted': return Colors.blue;
      case 'shipped': return Colors.purple;
      case 'delivered': return Colors.green;
      case 'cancelled': return Colors.red;
      default: return Colors.orange;
    }
  }
}