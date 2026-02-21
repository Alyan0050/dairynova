import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Privacy Policy", style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Your Privacy Matters", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(height: 15),
            Text("Dairy Nova is committed to protecting your personal data. Here is how we use your information:"),
            SizedBox(height: 20),
            Text("1. Personal Information", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text("We store your name and email to identify you and manage your dairy orders. Your name is shared with farmers to facilitate deliveries."),
            SizedBox(height: 15),
            Text("2. Image Storage", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text("Profile pictures are processed through ImgBB for hosting. We do not use these images for any purpose other than your profile display."),
            SizedBox(height: 15),
            Text("3. Account Deletion", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text("You can delete your account at any time. This will permanently remove your data from our servers."),
          ],
        ),
      ),
    );
  }
}