import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/app_theme.dart';
import '../widgets/rating_dialog.dart';

class CustomerOrdersScreen extends StatelessWidget {
  const CustomerOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("My Orders", style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('customerId', isEqualTo: user?.uid)
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
            padding: const EdgeInsets.all(10),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var orderData = docs[index].data() as Map<String, dynamic>;
              String orderId = docs[index].id;
              return _buildOrderCard(context, orderId, orderData);
            },
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, String id, Map<String, dynamic> data) {
    String status = data['status'] ?? 'Pending';
    var totalAmount = data['totalAmount'] ?? data['total'] ?? 0.0;
    List items = data['items'] ?? [];
    String customerName = data['customerName'] ?? "Customer"; // SYNCED: Your name in details

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: Text("Order #${id.substring(0, 5).toUpperCase()}", 
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("Total: Rs. $totalAmount | $status", 
            style: TextStyle(color: _getStatusColor(status))),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                // Display the name saved with the order for transparency
                Text("Order For: $customerName", 
                    style: const TextStyle(fontSize: 13, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text("Items Details:", style: TextStyle(fontWeight: FontWeight.bold)),
                if (items.isEmpty) const Text("No item details available."),
                ...items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("${item['name'] ?? 'Product'} (x${item['quantity'] ?? 1})"),
                      Text("Rs. ${(item['price'] ?? 0) * (item['quantity'] ?? 1)}"),
                    ],
                  ),
                )),
                const Divider(height: 20),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text("📍 Address: ${data['deliveryAddress'] ?? data['address'] ?? 'No address'}", 
                          style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ),
                    
                    // Cancellation Logic
                    if (status == 'Pending')
                      TextButton.icon(
                        onPressed: () => _confirmCancel(context, id),
                        icon: const Icon(Icons.cancel, color: Colors.red, size: 18),
                        label: const Text("Cancel", style: TextStyle(color: Colors.red)),
                      ),

                    // Rating Logic
                    if (status == 'Delivered')
                      data['rating'] != null 
                        ? Row(
                            children: [
                              Text("${data['rating']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                              const Icon(Icons.star, color: Colors.amber, size: 16),
                            ],
                          )
                        : TextButton.icon(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => RatingDialog(
                                  orderId: id,
                                  farmId: data['farmId'] ?? '',
                                ),
                              );
                            },
                            icon: const Icon(Icons.star_rate, color: Colors.amber, size: 18),
                            label: const Text("Rate Now", style: TextStyle(color: Colors.amber)),
                          ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmCancel(BuildContext context, String orderId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cancel Order?"),
        content: const Text("Are you sure you want to cancel this order? This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("No")),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
                'status': 'Cancelled',
              });
              if (context.mounted) Navigator.pop(ctx);
            },
            child: const Text("Yes, Cancel", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered': return Colors.green;
      case 'cancelled': return Colors.red;
      case 'shipped': return Colors.purple;
      default: return Colors.orange;
    }
  }
}