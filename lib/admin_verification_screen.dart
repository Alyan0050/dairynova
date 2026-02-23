import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/farm_model.dart';

class AdminVerificationScreen extends StatelessWidget {
  const AdminVerificationScreen({super.key});

  // HELPER: Full Screen Image Viewer
  void _openFullScreenImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(child: Image.network(imageUrl)),
            ),
            Positioned(
              top: 40, right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Verify Pending Farms"),
        backgroundColor: const Color(0xFF2E7D32),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Only fetch farms with 'pending' status
        stream: FirebaseFirestore.instance
            .collection('farms')
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No pending farms for review."));
          }

          final farms = snapshot.data!.docs.map((doc) {
            return Farm.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
          }).toList();

          return ListView.builder(
            itemCount: farms.length,
            itemBuilder: (context, index) => Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.pending, color: Colors.white)),
                title: Text(farms[index].name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("Owner: ${farms[index].owner}"),
                trailing: const Icon(Icons.rate_review, color: Color(0xFF2E7D32)),
                onTap: () => _showReviewSheet(context, farms[index]),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showReviewSheet(BuildContext context, Farm farm) {
    final TextEditingController feedbackController = TextEditingController();
    List<int> badImageIndices = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => DraggableScrollableSheet(
          initialChildSize: 0.9,
          expand: false,
          builder: (_, controller) => Container(
            padding: const EdgeInsets.all(16),
            child: ListView(
              controller: controller,
              children: [
                Text("Review: ${farm.name}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Divider(),
                const SizedBox(height: 10),
                
                const Text("CNIC (Click to zoom)", style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => _openFullScreenImage(context, farm.cnicUrl),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(farm.cnicUrl, height: 180, fit: BoxFit.cover),
                  ),
                ),
                
                const SizedBox(height: 20),
                const Text("Farm Photos (Tap to flag 'Bad' ones)", style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
                  itemCount: farm.farmPhotos.length,
                  itemBuilder: (ctx, i) => Stack(
                    children: [
                      InkWell(
                        onTap: () => _openFullScreenImage(context, farm.farmPhotos[i]),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(farm.farmPhotos[i], fit: BoxFit.cover, width: double.infinity, height: 100),
                        ),
                      ),
                      Positioned(
                        top: 0, right: 0,
                        child: Checkbox(
                          activeColor: Colors.red,
                          value: badImageIndices.contains(i),
                          onChanged: (val) => setSheetState(() {
                            val! ? badImageIndices.add(i) : badImageIndices.remove(i);
                          }),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                TextField(
                  controller: feedbackController,
                  decoration: const InputDecoration(
                    labelText: "Feedback / Rejection Reason", 
                    border: OutlineInputBorder(),
                    hintText: "Enter reason if rejecting...",
                  ),
                  maxLines: 2,
                ),

                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: ElevatedButton(
                      onPressed: () => _submitReview(context, farm, 'new', feedbackController.text, badImageIndices),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 15)),
                      child: const Text("REJECT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: ElevatedButton(
                      onPressed: () => _submitReview(context, farm, 'verified', 'Approved by Admin', []),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 15)),
                      child: const Text("APPROVE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    )),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submitReview(BuildContext context, Farm farm, String newStatus, String reason, List<int> badIndices) async {
    final batch = FirebaseFirestore.instance.batch();

    // 1. Update Farm Document Status
    DocumentReference farmRef = FirebaseFirestore.instance.collection('farms').doc(farm.id);
    batch.update(farmRef, {
      'status': newStatus,
      'adminFeedback': reason,
      'flaggedImages': badIndices,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 2. Update Owner User Status to synchronize AuthScreen logic
    DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(farm.ownerId);
    batch.update(userRef, {
      'status': newStatus, 
    });

    try {
      await batch.commit();
      if (context.mounted) {
        Navigator.pop(context); // Close sheet
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus == 'verified' ? "Farm Verified Successfully!" : "Farm Returned for Correction"),
            backgroundColor: newStatus == 'verified' ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }
}