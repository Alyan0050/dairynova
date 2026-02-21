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
      appBar: AppBar(title: const Text("Verify Farms")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('farms')
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final farms = snapshot.data!.docs.map((doc) => Farm.fromFirestore(doc.data() as Map<String, dynamic>, doc.id)).toList();
          if (farms.isEmpty) return const Center(child: Text("No pending farms."));

          return ListView.builder(
            itemCount: farms.length,
            itemBuilder: (context, index) => Card(
              margin: const EdgeInsets.all(10),
              child: ListTile(
                title: Text(farms[index].name),
                subtitle: Text("Owner: ${farms[index].owner}"),
                trailing: const Icon(Icons.rate_review),
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
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => DraggableScrollableSheet(
          initialChildSize: 0.9,
          builder: (_, controller) => Container(
            padding: const EdgeInsets.all(16),
            child: ListView(
              controller: controller,
              children: [
                const Text("Review Documents", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                
                // CNIC Section
                const Text("CNIC (Click to zoom)"),
                InkWell(
                  onTap: () => _openFullScreenImage(context, farm.cnicUrl),
                  child: Image.network(farm.cnicUrl, height: 150, fit: BoxFit.cover),
                ),
                
                const SizedBox(height: 20),
                const Text("Farm Photos (Select 'Bad' ones)"),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 5, mainAxisSpacing: 5),
                  itemCount: farm.farmPhotos.length,
                  itemBuilder: (ctx, i) => Stack(
                    children: [
                      InkWell(
                        onTap: () => _openFullScreenImage(context, farm.farmPhotos[i]),
                        child: Image.network(farm.farmPhotos[i], fit: BoxFit.cover, width: double.infinity, height: 100),
                      ),
                      Positioned(
                        top: 0, right: 0,
                        child: Checkbox(
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
                  decoration: const InputDecoration(labelText: "Rejection Reason", border: OutlineInputBorder()),
                  maxLines: 2,
                ),

                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: ElevatedButton(
                      onPressed: () => _submitReview(context, farm.id, 'rejected', feedbackController.text, badImageIndices),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text("Reject"),
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: ElevatedButton(
                      onPressed: () => _submitReview(context, farm.id, 'verified', '', []),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      child: const Text("Approve"),
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

  void _submitReview(BuildContext context, String docId, String status, String reason, List<int> badIndices) {
  FirebaseFirestore.instance.collection('farms').doc(docId).update({
    'status': status,
    'adminFeedback': reason,
    'flaggedImages': badIndices,
  }).then((_) {
    if (context.mounted) {
      // Show Success Message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(status == 'verified' 
            ? "Farm Approved Successfully!" 
            : "Farm Rejected with Feedback"),
          backgroundColor: status == 'verified' ? Colors.green : Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  });
  
  Navigator.pop(context); // Close the review sheet
}
}