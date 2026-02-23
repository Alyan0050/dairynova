import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; 
import 'package:table_calendar/table_calendar.dart';
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
              var subDoc = snapshot.data!.docs[index];
              var subData = subDoc.data() as Map<String, dynamic>;
              String subId = subDoc.id;

              _checkAndAutoResume(subId, subData);

              String status = subData['subscriptionStatus'] ?? subData['status'] ?? 'Active';
              String frequency = subData['frequency'] ?? 'Weekly';
              List items = subData['items'] is List ? subData['items'] : [];
              
              String nextDate = "N/A";
              if (subData['nextDeliveryDate'] != null) {
                nextDate = DateFormat('dd MMM yyyy').format((subData['nextDeliveryDate'] as Timestamp).toDate());
              }

              double total = double.tryParse(subData['totalAmount'].toString()) ?? 0.0;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ExpansionTile(
                  key: PageStorageKey(subId),
                  leading: Icon(
                    status == 'Paused' ? Icons.pause_circle_filled : Icons.autorenew, 
                    color: _getStatusColor(status)
                  ),
                  title: Text("$frequency Delivery"),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Next: $nextDate | Rs. ${total.toStringAsFixed(0)}"),
                      if (subData['lastDeliveryDate'] != null)
                        Text(
                          "Last Delivery: ${DateFormat('dd MMM, hh:mm a').format((subData['lastDeliveryDate'] as Timestamp).toDate())}",
                          style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                        ),
                    ],
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Subscription Details", style: TextStyle(fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.calendar_month, color: AppColors.primary),
                                tooltip: "View Delivery Calendar",
                                onPressed: () => _showCustomerHistoryCalendar(context, subData),
                              ),
                            ],
                          ),
                          const Divider(),
                          ...items.map((item) {
                            String name = item['name']?.toString() ?? 'Item';
                            int qty = int.tryParse(item['quantity'].toString()) ?? 1;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text("• $name (x$qty)"),
                            );
                          }).toList(),
                          const SizedBox(height: 16),
                          
                          if (status != 'Cancelled')
                            Row(
                              children: [
                                if (status == 'Paused')
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _resumeSubscription(subId),
                                      icon: const Icon(Icons.play_arrow),
                                      label: const Text("Resume Now"),
                                    ),
                                  )
                                else
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _showPausePicker(context, subId),
                                      icon: const Icon(Icons.pause_circle_outline),
                                      label: const Text("Pause Dates"),
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _handleCancellation(context, subId, subData),
                                    icon: const Icon(Icons.cancel, size: 18),
                                    label: const Text("Cancel"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red.shade50, 
                                      foregroundColor: Colors.red,
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            
                          if (subData['pauseEndDate'] != null && status == 'Paused')
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                "⏸ Paused until ${DateFormat('dd MMM').format((subData['pauseEndDate'] as Timestamp).toDate())}", 
                                style: const TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.bold)
                              ),
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

  void _showCustomerHistoryCalendar(BuildContext context, Map<String, dynamic> data) {
    List<dynamic> history = data['deliveryHistory'] ?? [];
    Set<DateTime> deliveredDates = history.map((e) {
      DateTime d = (e as Timestamp).toDate();
      return DateTime(d.year, d.month, d.day);
    }).toSet();

    DateTime? pauseStart = data['pauseStartDate'] != null 
        ? DateTime(data['pauseStartDate'].toDate().year, data['pauseStartDate'].toDate().month, data['pauseStartDate'].toDate().day) 
        : null;
    DateTime? pauseEnd = data['pauseEndDate'] != null 
        ? DateTime(data['pauseEndDate'].toDate().year, data['pauseEndDate'].toDate().month, data['pauseEndDate'].toDate().day) 
        : null;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("My Delivery History"),
        content: SizedBox(
          width: 320,
          height: 390,
          child: Column(
            children: [
              Expanded(
                child: TableCalendar(
                  focusedDay: DateTime.now(),
                  firstDay: DateTime.utc(2025, 1, 1),
                  lastDay: DateTime.now().add(const Duration(days: 90)),
                  headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
                  calendarFormat: CalendarFormat.month,
                  eventLoader: (day) => deliveredDates.contains(DateTime(day.year, day.month, day.day)) ? ['Delivered'] : [],
                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (context, day, focusedDay) {
                      DateTime normalizedDay = DateTime(day.year, day.month, day.day);
                      if (pauseStart != null && pauseEnd != null) {
                        if ((normalizedDay.isAtSameMomentAs(pauseStart) || normalizedDay.isAfter(pauseStart)) &&
                            (normalizedDay.isAtSameMomentAs(pauseEnd) || normalizedDay.isBefore(pauseEnd))) {
                          return Container(
                            margin: const EdgeInsets.all(4.0),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.2), 
                              shape: BoxShape.circle, 
                              border: Border.all(color: Colors.orange, width: 1.5)
                            ),
                            child: Text(day.day.toString(), style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                          );
                        }
                      }
                      return null;
                    },
                  ),
                  calendarStyle: CalendarStyle(
                    markerDecoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                    todayDecoration: BoxDecoration(color: AppColors.primary.withOpacity(0.3), shape: BoxShape.circle),
                  ),
                ),
              ),
              const Divider(),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.circle, size: 10, color: Colors.green), Text(" Delivered   ", style: TextStyle(fontSize: 10)),
                  Icon(Icons.circle, size: 10, color: Colors.orange), Text(" Paused Dates", style: TextStyle(fontSize: 10)),
                ],
              )
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
      ),
    );
  }

  void _checkAndAutoResume(String subId, Map<String, dynamic> data) async {
    if (data['subscriptionStatus'] == 'Paused' && data['pauseEndDate'] != null) {
      DateTime pauseEnd = (data['pauseEndDate'] as Timestamp).toDate();
      if (DateTime.now().isAfter(pauseEnd)) {
        await FirebaseFirestore.instance.collection('orders').doc(subId).update({
          'subscriptionStatus': 'Active',
          'pauseStartDate': null,
          'pauseEndDate': null,
        });
      }
    }
  }

  Future<void> _resumeSubscription(String subId) async {
    await FirebaseFirestore.instance.collection('orders').doc(subId).update({
      'subscriptionStatus': 'Active',
      'pauseStartDate': null,
      'pauseEndDate': null,
    });
  }

  void _handleCancellation(BuildContext context, String subId, Map<String, dynamic> data) {
    final now = DateTime.now();
    if (now.hour >= 22) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Cut-off Time Reached"),
          content: const Text("Cancellations after 10 PM apply after tomorrow's delivery."),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))],
        ),
      );
    }
    _confirmCancel(context, subId, data);
  }

  void _confirmCancel(BuildContext context, String subId, Map<String, dynamic> subData) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cancel Subscription?"),
        content: const Text("Future recurring deliveries will stop."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Keep")),
          TextButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance.collection('orders').doc(subId).update({
                  'subscriptionStatus': 'Cancelled',
                  'status': 'Cancelled'
                });
                if (context.mounted) Navigator.pop(ctx);
              } catch (e) {
                debugPrint("Cancel Error: $e");
              }
            },
            child: const Text("Cancel Now", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showPausePicker(BuildContext context, String subId) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );

    if (picked != null) {
      await FirebaseFirestore.instance.collection('orders').doc(subId).update({
        'pauseStartDate': Timestamp.fromDate(picked.start),
        'pauseEndDate': Timestamp.fromDate(picked.end),
        'subscriptionStatus': 'Paused',
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