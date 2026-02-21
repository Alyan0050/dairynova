import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart'; // Add this for calling
import '../../../utils/app_theme.dart';

class FarmerOrdersScreen extends StatelessWidget {
  final String farmId;
  const FarmerOrdersScreen({super.key, required this.farmId});

  // Function to call customer (Operational for Rajanpur/Jampur deliveries)
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
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('farmId', isEqualTo: farmId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No orders found."));
          }

          final docs = snapshot.data!.docs;

          // Safe sorting for orderDate vs date
          docs.sort((a, b) {
            var aData = a.data() as Map<String, dynamic>;
            var bData = b.data() as Map<String, dynamic>;
            var aDate = (aData['orderDate'] ?? aData['date']) as Timestamp?;
            var bDate = (bData['orderDate'] ?? bData['date']) as Timestamp?;
            if (aDate == null || bDate == null) return 0;
            return bDate.compareTo(aDate);
          });

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
    );
  }

  Widget _buildManagementCard(BuildContext context, String id, Map<String, dynamic> data) {
    String status = data['status'] ?? 'Pending';
    var total = data['totalAmount'] ?? data['total'] ?? 0.0;
    List items = data['items'] ?? [];
    String address = data['deliveryAddress'] ?? data['address'] ?? 'No address';
    
    // UPDATED: Get customer name and phone
    String customerName = data['customerName'] ?? "New Customer";
    String? customerPhone = data['customerPhone']; // Ensure this is saved during checkout

    bool isSubscription = data['orderType'] == 'subscription';
    String frequency = data['frequency'] ?? '';

    return Card(
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ExpansionTile(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // DISPLAY CUSTOMER NAME PROMINENTLY
            Text(customerName, 
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary)),
            Row(
              children: [
                Text("Order #${id.substring(0, 5).toUpperCase()}", 
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                if (isSubscription) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text("SUB", style: TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ),
          ],
        ),
        subtitle: Text("Status: $status | Rs. $total", 
            style: TextStyle(color: _getStatusColor(status), fontWeight: FontWeight.w600)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                if (customerPhone != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ElevatedButton.icon(
                      onPressed: () => _callCustomer(customerPhone),
                      icon: const Icon(Icons.phone, size: 18),
                      label: const Text("Call Customer"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 40),
                      ),
                    ),
                  ),
                if (isSubscription)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text("🔁 Recurring: $frequency", 
                        style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                  ),
                Text("📍 Address: $address", style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 10),
                const Text("Items:", style: TextStyle(fontWeight: FontWeight.bold)),
                ...items.map((item) => Text("• ${item['name']} x${item['quantity']}")),
                const SizedBox(height: 20),
                
                const Text("Update Order Status:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 10),
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