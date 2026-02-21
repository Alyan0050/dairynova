import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/app_theme.dart';
import '../widgets/billing_summary_screen.dart'; // Import for FR-13

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
          // FR-13: Link to Billing & Analytics
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

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.autorenew, color: AppColors.primary),
                      title: Text("${subData['frequency']} Delivery"),
                      subtitle: Text("Status: $status"),
                      trailing: IconButton(
                        icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                        onPressed: () => _handleCancellation(context, subId),
                      ),
                    ),
                    if (status != 'Cancelled')
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Show pause dates if they exist
                            if (subData['pauseStartDate'] != null)
                              const Text("Paused", style: TextStyle(color: Colors.orange, fontSize: 12)),
                            TextButton.icon(
                              onPressed: () => _showPausePicker(context, subId),
                              icon: const Icon(Icons.pause_circle_outline, size: 20),
                              label: const Text("Pause Dates"),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showPausePicker(BuildContext context, String subId) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: AppColors.primary)),
          child: child!,
        );
      },
    );

    if (picked != null) {
      await FirebaseFirestore.instance.collection('orders').doc(subId).update({
        'pauseStartDate': Timestamp.fromDate(picked.start),
        'pauseEndDate': Timestamp.fromDate(picked.end),
        'status': 'Paused',
      });
    }
  }

  void _handleCancellation(BuildContext context, String subId) {
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
      _confirmCancel(context, subId);
    }
  }

  void _confirmCancel(BuildContext context, String subId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cancel Subscription?"),
        content: const Text("This will stop all future recurring deliveries."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("No")),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('orders').doc(subId).update({'status': 'Cancelled'});
              if (context.mounted) Navigator.pop(ctx);
            },
            child: const Text("Yes, Cancel", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}