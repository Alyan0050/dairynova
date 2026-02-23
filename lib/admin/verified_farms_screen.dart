import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class VerifiedFarmsScreen extends StatelessWidget {
  const VerifiedFarmsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color kPrimaryColor = Color(0xFF2E7D32); // Sync with your Dashboard theme

    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9), 
      appBar: AppBar(
        title: const Text("Verified Partners", 
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: kPrimaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // FIXED LOGIC: Query matches the 'status' string in your Firestore
        stream: FirebaseFirestore.instance
            .collection('farms')
            .where('status', isEqualTo: 'verified') 
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kPrimaryColor));
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error fetching data: ${snapshot.error}"));
          }

          // SAFE DATA ACCESS: Prevents 'Unexpected null value' error
          final farmDocs = snapshot.data?.docs ?? [];
          final totalActiveFarms = farmDocs.length;

          return Column(
            children: [
              // --- STATS SECTION ---
              _buildStatsHeader(totalActiveFarms, kPrimaryColor),
              
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Verified Farm Profiles",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kPrimaryColor),
                  ),
                ),
              ),

              // --- FARM LIST SECTION ---
              Expanded(
                child: farmDocs.isEmpty 
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: farmDocs.length,
                      itemBuilder: (context, index) {
                        final farmData = farmDocs[index].data() as Map<String, dynamic>? ?? {};
                        final farmId = farmDocs[index].id;

                        return Card(
                          elevation: 3,
                          shadowColor: Colors.black26,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(12),
                            leading: CircleAvatar(
                              radius: 25,
                              backgroundColor: kPrimaryColor.withOpacity(0.1),
                              child: const Icon(Icons.agriculture, color: kPrimaryColor, size: 30),
                            ),
                            title: Text(
                              farmData['farmName'] ?? "Unnamed Farm",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            subtitle: Text("Owner: ${farmData['ownerName'] ?? 'Unknown'}"),
                            trailing: const Icon(Icons.verified, color: Colors.blue, size: 28),
                            onTap: () => _showFarmDetails(context, farmData, farmId, kPrimaryColor),
                          ),
                        );
                      },
                    ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.storefront_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text("No verified farms in database.", 
            style: TextStyle(color: Colors.grey[600], fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildStatsHeader(int count, Color color) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 25),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          const Text(
            "TOTAL ACTIVE FARMS",
            style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          const SizedBox(height: 8),
          Text(
            "$count",
            style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _showFarmDetails(BuildContext context, Map<String, dynamic> farm, String id, Color primaryColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    farm['farmName'] ?? "Farm Details",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryColor),
                  ),
                ),
                const Icon(Icons.verified, color: Colors.blue, size: 30),
              ],
            ),
            const Divider(height: 40),
            _detailRow(Icons.person_pin, "Owner Name", farm['ownerName'] ?? "N/A"),
            _detailRow(Icons.location_on, "Location", farm['location'] ?? "Not specified"),
            _detailRow(Icons.fingerprint, "Verification ID", id),
            // UpdatedAt display logic
            if (farm['updatedAt'] != null)
              _detailRow(Icons.calendar_today, "Verified On", 
                DateFormat('dd MMM yyyy').format((farm['updatedAt'] as Timestamp).toDate())),
            
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text("CLOSE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: Colors.grey[600]),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}