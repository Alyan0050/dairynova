import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/app_theme.dart';
import '../farmer/farmer_dashboard.dart';

class FarmApprovedScreen extends StatefulWidget {
  const FarmApprovedScreen({super.key});

  @override
  State<FarmApprovedScreen> createState() => _FarmApprovedScreenState();
}

class _FarmApprovedScreenState extends State<FarmApprovedScreen> {
  bool _isUpdating = false;

  // This function marks the farm as "seen" in the database
  Future<void> _handleGetStarted() async {
    setState(() => _isUpdating = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Query the specific farm document for this owner
        final farmQuery = await FirebaseFirestore.instance
            .collection('farms')
            .where('ownerId', isEqualTo: user.uid)
            .get();

        if (farmQuery.docs.isNotEmpty) {
          // Update the flag so the StreamBuilder skips this screen next time
          await farmQuery.docs.first.reference.update({
            'hasSeenApproval': true,
          });
        }
      }

      if (mounted) {
        // Move to the actual dashboard and clear navigation history
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const FarmerDashboard()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Celebration Icon
                const Icon(
                  Icons.verified_user_rounded,
                  size: 100,
                  color: Colors.green,
                ),
                const SizedBox(height: 24),
                
                const Text(
                  "Verification Successful!",
                  style: TextStyle(
                    fontSize: 28, 
                    fontWeight: FontWeight.bold, 
                    color: AppColors.primary
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                
                const Text(
                  "Great news! Your farm has been officially approved. You can now start managing your products and receiving orders.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16, 
                    color: AppColors.grey,
                    height: 1.5
                  ),
                ),
                const SizedBox(height: 48),

                // Action Button with Loading State
                _isUpdating 
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _handleGetStarted,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)
                      ),
                    ),
                    child: const Text(
                      "GO TO DASHBOARD",
                      style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}