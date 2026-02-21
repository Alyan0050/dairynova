import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_theme.dart';

class SystemLogsScreen extends StatelessWidget {
  const SystemLogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("System Audit Logs", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black87,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('system_logs')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text("No system logs recorded yet.", 
                style: TextStyle(color: Colors.grey))
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var log = snapshot.data!.docs[index].data() as Map<String, dynamic>;
              return _buildLogCard(log);
            },
          );
        },
      ),
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log) {
    String action = log['action'] ?? "Unknown Action";
    String admin = log['adminName'] ?? "System";
    Timestamp time = log['timestamp'] ?? Timestamp.now();
    
    IconData logIcon = Icons.info_outline;
    Color iconColor = Colors.blue;

    // Logic to style logs based on the action performed
    if (action.contains("Approved")) {
      logIcon = Icons.verified_user;
      iconColor = Colors.green;
    } else if (action.contains("Login")) {
      logIcon = Icons.login;
      iconColor = Colors.orange;
    } else if (action.contains("Deleted")) {
      logIcon = Icons.delete_forever;
      iconColor = Colors.red;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12), // Fixed the EdgeInsets error
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.1),
          child: Icon(logIcon, color: iconColor),
        ),
        title: Text(action, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("Performed by: $admin"),
        trailing: Text(
          "${time.toDate().hour}:${time.toDate().minute.toString().padLeft(2, '0')}",
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ),
    );
  }
}