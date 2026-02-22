import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/app_theme.dart';
import '../widgets/rating_dialog.dart';

class CustomerOrdersScreen extends StatefulWidget {
  const CustomerOrdersScreen({super.key});

  @override
  State<CustomerOrdersScreen> createState() => _CustomerOrdersScreenState();
}

class _CustomerOrdersScreenState extends State<CustomerOrdersScreen> {
  /// keeps expansion state
  final Set<String> expandedOrders = {};

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
      body: user == null
          ? const Center(child: Text("Please login to view orders."))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .where('customerId', isEqualTo: user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No orders found."));
                }

                final docs = snapshot.data!.docs;

                /// Sort newest first
                docs.sort((a, b) {
                  Timestamp? aDate = a.data().toString().contains('orderDate') ? a['orderDate'] : null;
                  Timestamp? bDate = b.data().toString().contains('orderDate') ? b['orderDate'] : null;
                  if (aDate == null || bDate == null) return 0;
                  return bDate.compareTo(aDate);
                });

                return ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    Map<String, dynamic> data = docs[index].data() as Map<String, dynamic>;
                    String orderId = docs[index].id;
                    return _buildOrderCard(context, orderId, data);
                  },
                );
              },
            ),
    );
  }

  Widget _buildOrderCard(BuildContext context, String id, Map<String, dynamic> data) {
    String shortId = id.length >= 5 ? id.substring(0, 5) : id;
    String status = data['status']?.toString() ?? "Pending";
    double totalAmount = 0;
    var amount = data['totalAmount'] ?? data['total'];

    if (amount is int) totalAmount = amount.toDouble();
    else if (amount is double) totalAmount = amount;
    else if (amount is String) totalAmount = double.tryParse(amount) ?? 0;

    List items = data['items'] is List ? data['items'] : [];
    String customerName = data['customerName']?.toString() ?? "Customer";
    String address = data['deliveryAddress']?.toString() ?? data['address']?.toString() ?? "No address";

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        key: ValueKey(id),
        initiallyExpanded: expandedOrders.contains(id),
        onExpansionChanged: (expanded) {
          setState(() {
            if (expanded) expandedOrders.add(id);
            else expandedOrders.remove(id);
          });
        },
        title: Text("Order #${shortId.toUpperCase()}", style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("Rs. ${totalAmount.toStringAsFixed(0)} | $status",
            style: TextStyle(color: _getStatusColor(status), fontWeight: FontWeight.bold)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                Text("Customer: $customerName"),
                const SizedBox(height: 10),
                const Text("Items:", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                ...items.map((item) {
                  String name = item['name']?.toString() ?? "Item";
                  int qty = item['quantity'] is int ? item['quantity'] : int.tryParse(item['quantity'].toString()) ?? 1;
                  double price = 0;
                  var p = item['price'];
                  if (p is int) price = p.toDouble();
                  else if (p is double) price = p;
                  else if (p is String) price = double.tryParse(p) ?? 0;

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text("$name x$qty")),
                      Text("Rs ${(price * qty).toStringAsFixed(0)}"),
                    ],
                  );
                }),
                const SizedBox(height: 10),
                Text("Address: $address"),
                const SizedBox(height: 10),
                _buildButtons(context, id, status, data),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtons(BuildContext context, String id, String status, Map<String, dynamic> data) {
    if (status == "Pending") {
      return TextButton(
        onPressed: () => _confirmCancel(context, id, data),
        child: const Text("Cancel Order", style: TextStyle(color: Colors.red)),
      );
    }

    if (status == "Delivered") {
      if (data['rating'] != null) {
        return Row(
          children: [
            Text("Rating ${data['rating']}"),
            const Icon(Icons.star, color: Colors.amber),
          ],
        );
      }
      return ElevatedButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => RatingDialog(
              orderId: id,
              farmId: data['farmId']?.toString() ?? "",
            ),
          );
        },
        child: const Text("Rate"),
      );
    }
    return const SizedBox();
  }

  // --- REFINED: CANCEL ORDER WITH STOCK REVERSAL ---
  void _confirmCancel(BuildContext context, String orderId, Map<String, dynamic> orderData) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cancel Order?"),
        content: const Text("Are you sure? Items will be returned to the farm's stock."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("No")),
          TextButton(
            onPressed: () async {
              final firestore = FirebaseFirestore.instance;
              try {
                // Perform Stock reversal in a transaction
                await firestore.runTransaction((transaction) async {
                  List items = orderData['items'] ?? [];

                  for (var item in items) {
                    String? productId = item['productId']; // Ensure you save productId in CartProvider
                    if (productId != null) {
                      DocumentReference productRef = firestore.collection('products').doc(productId);
                      DocumentSnapshot productSnap = await transaction.get(productRef);

                      if (productSnap.exists) {
                        int currentStock = productSnap.get('stock') ?? 0;
                        int orderQty = item['quantity'] ?? 0;
                        // Return stock to the product
                        transaction.update(productRef, {'stock': currentStock + orderQty});
                      }
                    }
                  }

                  // Update the order status to Cancelled
                  transaction.update(firestore.collection('orders').doc(orderId), {
                    'status': 'Cancelled'
                  });
                });

                if (mounted) Navigator.pop(ctx);
              } catch (e) {
                debugPrint("Cancel Error: $e");
              }
            },
            child: const Text("Yes, Cancel", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case "delivered": return Colors.green;
      case "cancelled": return Colors.red;
      case "accepted": return Colors.blue;
      case "shipped": return Colors.purple;
      default: return Colors.orange;
    }
  }
}