import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/app_theme.dart';
import '../widgets/billing_summary_screen.dart';

class SubscriptionManagementScreen extends StatelessWidget {
  const SubscriptionManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("My Subscriptions", style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined, color: Colors.white),
            tooltip: "Billing & Analytics",
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const BillingSummaryScreen()),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('customerId', isEqualTo: user?.uid)
            .where('orderType', isEqualTo: 'subscription')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No active subscriptions found."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var subData = snapshot.data!.docs[index].data() as Map<String, dynamic>;
              String subId = snapshot.data!.docs[index].id;
              String status = subData['status'] ?? 'Active';
              List items = subData['items'] ?? [];

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ExpansionTile(
                  key: PageStorageKey(subId), // Persist expansion state
                  leading: const Icon(Icons.autorenew, color: AppColors.primary),
                  title: Text("${subData['frequency'] ?? 'Weekly'} Delivery"),
                  subtitle: Text("Status: $status", style: TextStyle(color: _getStatusColor(status), fontWeight: FontWeight.bold)),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Subscription Details:", style: TextStyle(fontWeight: FontWeight.bold)),
                          const Divider(),
                          
                          // FIX: infinite width layout
                          ...items.map((item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(child: Text("${item['name']} (x${item['quantity']})")),
                                Text("Rs. ${((item['price'] ?? 0) * (item['quantity'] ?? 1)).toStringAsFixed(0)}"),
                              ],
                            ),
                          )),
                          
                          const SizedBox(height: 12),
                          if (status != 'Cancelled')
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton.icon(
                                  onPressed: () => _showPausePicker(context, subId),
                                  icon: const Icon(Icons.pause_circle_outline),
                                  label: const Text("Pause Dates"),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () => _handleCancellation(context, subId, subData),
                                  icon: const Icon(Icons.cancel, size: 18),
                                  label: const Text("Cancel"),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                ),
                              ],
                            ),
                          if (subData['pauseStartDate'] != null && status == 'Paused')
                            const Padding(
                              padding: EdgeInsets.only(top: 8.0),
                              child: Text("⏸ Current Pause Active", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Logic: Revert stock on cancellation
  void _handleCancellation(BuildContext context, String subId, Map<String, dynamic> data) {
    final now = DateTime.now();
    if (now.hour >= 22) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Next Delivery Processing"),
          content: const Text("It's past 10 PM. Cancellation will apply after tomorrow's delivery."),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))],
        ),
      );
    } else {
      _confirmCancel(context, subId, data);
    }
  }

  void _confirmCancel(BuildContext context, String subId, Map<String, dynamic> subData) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cancel Subscription?"),
        content: const Text("This stops recurring deliveries and returns stock to the farm."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("No")),
          TextButton(
            onPressed: () async {
              final firestore = FirebaseFirestore.instance;
              try {
                // Transactional Stock Reversal
                await firestore.runTransaction((transaction) async {
                  List items = subData['items'] ?? [];
                  for (var item in items) {
                    DocumentReference productRef = firestore.collection('products').doc(item['productId']);
                    DocumentSnapshot productSnap = await transaction.get(productRef);
                    if (productSnap.exists) {
                      int currentStock = productSnap.get('stock') ?? 0;
                      transaction.update(productRef, {'stock': currentStock + (item['quantity'] ?? 0)});
                    }
                  }
                  transaction.update(firestore.collection('orders').doc(subId), {'status': 'Cancelled'});
                });
                if (context.mounted) Navigator.pop(ctx);
              } catch (e) {
                debugPrint("Sub Cancel Error: $e");
              }
            },
            child: const Text("Yes, Cancel", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showPausePicker(BuildContext context, String subId) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (picked != null) {
      await FirebaseFirestore.instance.collection('orders').doc(subId).update({
        'pauseStartDate': Timestamp.fromDate(picked.start),
        'pauseEndDate': Timestamp.fromDate(picked.end),
        'status': 'Paused',
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active': return Colors.green;
      case 'paused': return Colors.orange;
      case 'cancelled': return Colors.red;
      default: return Colors.blue;
    }
  }
}