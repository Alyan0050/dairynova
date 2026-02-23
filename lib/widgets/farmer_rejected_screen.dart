import 'package:flutter/material.dart';
import '../models/farm_model.dart';
import '../auth/register_farm_screen.dart';

class FarmerRejectedScreen extends StatelessWidget {
  final Map<String, dynamic> farmData;
  const FarmerRejectedScreen({super.key, required this.farmData});

  @override
  Widget build(BuildContext context) {
    String feedback = farmData['adminFeedback'] ?? "No feedback provided.";
    List<dynamic> flagged = farmData['flaggedImages'] ?? [];
    List<dynamic> photos = farmData['farmPhotos'] ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.cancel, size: 80, color: Colors.red),
          const SizedBox(height: 10),
          const Text("Application Rejected", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50, 
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Admin Feedback:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                const SizedBox(height: 8),
                Text(feedback, style: const TextStyle(color: Colors.black87)),
              ],
            ),
          ),

          if (flagged.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text("Flagged Images (Need Correction):", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: flagged.length,
                itemBuilder: (ctx, i) {
                  int photoIndex = flagged[i];
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.red, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                      child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: (photos[photoIndex] != null && photos[photoIndex].toString().isNotEmpty)
                          ? Image.network(photos[photoIndex], width: 100, fit: BoxFit.cover)
                          : Container(width: 100, height: 100, color: Colors.grey[200], child: const Icon(Icons.broken_image)),
                    ),
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: 40),
          ElevatedButton.icon(
            onPressed: () {
              final currentFarm = Farm.fromFirestore(farmData, farmData['id'] ?? ""); 
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (context) => RegisterFarmScreen(existingFarm: currentFarm)),
              );
            },
            icon: const Icon(Icons.edit_note),
            label: const Text("Edit & Re-submit Application"),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}