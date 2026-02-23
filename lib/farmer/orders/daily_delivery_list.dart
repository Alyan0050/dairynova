import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart'; 
import '../../../utils/app_theme.dart';

class DailyDeliveryList extends StatelessWidget {
  final String farmId;
  const DailyDeliveryList({super.key, required this.farmId});

  // --- LOGIC: Standardize date to Midnight for accurate comparison ---
  DateTime _normalize(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  // Check if user has paused their subscription for today
  bool _isCurrentlyPaused(Map<String, dynamic> data) {
    if (data['pauseStartDate'] == null || data['pauseEndDate'] == null) return false;
    
    DateTime today = _normalize(DateTime.now());
    DateTime start = _normalize((data['pauseStartDate'] as Timestamp).toDate());
    DateTime end = _normalize((data['pauseEndDate'] as Timestamp).toDate());

    return (today.isAtSameMomentAs(start) || today.isAfter(start)) &&
           (today.isAtSameMomentAs(end) || today.isBefore(end));
  }

  // Handle status updates and calendar history tracking
  Future<void> _updateDeliveryStatus(String orderId, Map<String, dynamic> data, String newStatus) async {
    if (_isCurrentlyPaused(data)) return;

    final firestore = FirebaseFirestore.instance;
    final docRef = firestore.collection('orders').doc(orderId);

    if (newStatus == 'Delivered') {
      String frequency = data['frequency'] ?? 'Daily';
      DateTime currentNextDate = (data['nextDeliveryDate'] as Timestamp).toDate();
      
      DateTime newNextDate = frequency == 'Weekly' 
          ? currentNextDate.add(const Duration(days: 7)) 
          : currentNextDate.add(const Duration(days: 1));

      await docRef.update({
        'status': 'Delivered', 
        'lastDeliveryDate': FieldValue.serverTimestamp(),
        'nextDeliveryDate': Timestamp.fromDate(newNextDate),
        'deliveryHistory': FieldValue.arrayUnion([Timestamp.fromDate(DateTime.now())]),
      });
    } else {
      await docRef.update({'status': newStatus});
    }
  }

  @override
  Widget build(BuildContext context) {
    DateTime now = DateTime.now();
    DateTime startOfToday = _normalize(now);
    DateTime endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59); 

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Morning Deliveries", style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('farmId', isEqualTo: farmId)
            .where('orderType', isEqualTo: 'subscription')
            .where('subscriptionStatus', isNotEqualTo: 'Cancelled')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));

          final allDocs = snapshot.data!.docs;
          
          final activeSubs = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            Timestamp? next = data['nextDeliveryDate'];
            Timestamp? last = data['lastDeliveryDate'];
            
            bool isDueToday = next != null && next.toDate().isBefore(endOfToday);
            bool wasDoneToday = last != null && _normalize(last.toDate()).isAtSameMomentAs(startOfToday);
            
            return isDueToday || wasDoneToday;
          }).toList();

          if (activeSubs.isEmpty) return const Center(child: Text("No deliveries for today."));

          return Column(
            children: [
              _buildSummaryHeader(activeSubs, context),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: activeSubs.length,
                  itemBuilder: (context, index) {
                    var data = activeSubs[index].data() as Map<String, dynamic>;
                    return _buildDeliveryTile(activeSubs[index].id, data, context);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryHeader(List<QueryDocumentSnapshot> docs, BuildContext context) {
    int remainingUnits = 0;
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      Timestamp? last = data['lastDeliveryDate'];
      bool isDoneToday = last != null && _normalize(last.toDate()).isAtSameMomentAs(_normalize(DateTime.now()));
      
      if (!_isCurrentlyPaused(data) && !isDoneToday) {
        List items = doc['items'] ?? [];
        for (var item in items) {
          remainingUnits += (item['quantity'] as num).toInt();
        }
      }
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("Units Left Today:", style: TextStyle(fontWeight: FontWeight.bold)),
          Text("$remainingUnits Units", style: const TextStyle(fontSize: 18, color: AppColors.primary, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildDeliveryTile(String id, Map<String, dynamic> data, BuildContext context) {
    List items = data['items'] ?? [];
    String status = data['status'] ?? 'Pending';
    bool isPaused = _isCurrentlyPaused(data);
    Timestamp? last = data['lastDeliveryDate'];
    bool isDoneToday = last != null && _normalize(last.toDate()).isAtSameMomentAs(_normalize(DateTime.now()));

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12), 
        side: isDoneToday ? const BorderSide(color: Colors.green, width: 2) : BorderSide.none
      ),
      color: isDoneToday ? Colors.green.shade50 : (isPaused ? Colors.grey.shade100 : Colors.white),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: isDoneToday ? Colors.green : (isPaused ? Colors.grey : _getStatusColor(status)),
              child: Icon(isDoneToday ? Icons.check : (isPaused ? Icons.pause : Icons.delivery_dining), color: Colors.white),
            ),
            title: Text(data['customerName'] ?? "Customer", style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['deliveryAddress'] ?? "No Address"),
                if (last != null)
                  Text(
                    "Last delivery: ${DateFormat('hh:mm a').format(last.toDate())}",
                    style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                  ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.calendar_month, color: AppColors.primary),
              onPressed: () => _showHistoryCalendar(context, data),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Order: ${items.map((i) => "${i['name']} x${i['quantity']}").join(', ')}", 
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                if (isDoneToday)
                  const Text("✅ COMPLETED", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
                else if (isPaused)
                  const Text("⏸ PAUSED", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))
                else
                  Row(
                    children: [
                      _statusButton(context, id, data, "Shipped", Colors.purple, false),
                      const SizedBox(width: 8),
                      _statusButton(context, id, data, "Delivered", Colors.green, false),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showHistoryCalendar(BuildContext context, Map<String, dynamic> data) {
    List<dynamic> history = data['deliveryHistory'] ?? [];
    Set<DateTime> deliveredDates = history.map((e) => _normalize((e as Timestamp).toDate())).toSet();

    DateTime? pauseStart = data['pauseStartDate'] != null ? _normalize(data['pauseStartDate'].toDate()) : null;
    DateTime? pauseEnd = data['pauseEndDate'] != null ? _normalize(data['pauseEndDate'].toDate()) : null;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("${data['customerName']}'s Schedule"),
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
                  eventLoader: (day) => deliveredDates.contains(_normalize(day)) ? ['Delivered'] : [],
                  
                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (context, day, focusedDay) {
                      DateTime normalizedDay = _normalize(day);
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
                  calendarStyle: const CalendarStyle(
                    markerDecoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                    todayDecoration: BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
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

  Widget _statusButton(BuildContext context, String id, Map<String, dynamic> data, String label, Color color, bool isPaused) {
    return ElevatedButton(
      onPressed: isPaused ? null : () => _updateDeliveryStatus(id, data, label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color, 
        foregroundColor: Colors.white, 
        padding: const EdgeInsets.symmetric(horizontal: 12),
        minimumSize: const Size(0, 32)
      ),
      child: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'shipped': return Colors.purple;
      case 'delivered': return Colors.green;
      default: return Colors.orange;
    }
  }
}