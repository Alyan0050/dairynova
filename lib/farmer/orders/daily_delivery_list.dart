import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../utils/app_theme.dart';

class DailyDeliveryList extends StatelessWidget {
  final String farmId;
  const DailyDeliveryList({super.key, required this.farmId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Morning Deliveries", style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Filters for active subscriptions for this farm
        stream: FirebaseFirestore.instance
    .collection('orders')
    .where('farmId', isEqualTo: farmId)
    .where('orderType', isEqualTo: 'subscription')
    .where('status', isEqualTo: 'Pending') // Only show active ones
    .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text("No subscriptions for today."),
            );
          }

          final subs = snapshot.data!.docs;

          return Column(
            children: [
              _buildSummaryHeader(subs),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: subs.length,
                  itemBuilder: (context, index) {
                    var data = subs[index].data() as Map<String, dynamic>;
                    return _buildDeliveryTile(subs[index].id, data);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryHeader(List<QueryDocumentSnapshot> docs) {
    int totalItems = 0;
    for (var doc in docs) {
      List items = doc['items'] ?? [];
      for (var item in items) {
        totalItems += (item['quantity'] as num).toInt();
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      color: AppColors.primary.withValues(alpha: 0.1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("Total Units Needed:", style: TextStyle(fontWeight: FontWeight.bold)),
          Text("$totalItems Liters/Units", style: const TextStyle(fontSize: 18, color: AppColors.primary, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildDeliveryTile(String id, Map<String, dynamic> data) {
    List items = data['items'] ?? [];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.directions_bike)),
        title: Text(data['deliveryAddress'] ?? "No Address"),
        subtitle: Text("Items: ${items.map((i) => "${i['name']} x${i['quantity']}").join(', ')}"),
        trailing: Text(data['frequency'] ?? "", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
      ),
    );
  }
}