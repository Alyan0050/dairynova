import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../utils/app_theme.dart';
import '../auth/auth_screen.dart';
import 'account_details_screen.dart';
import 'privacy_policy_screen.dart';

class CustomerSettingsScreen extends StatefulWidget {
  const CustomerSettingsScreen({super.key});

  @override
  State<CustomerSettingsScreen> createState() => _CustomerSettingsScreenState();
}

class _CustomerSettingsScreenState extends State<CustomerSettingsScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  bool _isUploading = false;
  final String _imgBBKey = "7dedc06d9f9ba46be0f57c22bada50b6";

  Future<void> _updateProfilePicture() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedImage = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (pickedImage == null) return;

    setState(() => _isUploading = true);
    try {
      final bytes = await pickedImage.readAsBytes();
      var request = http.MultipartRequest('POST', Uri.parse('https://api.imgbb.com/1/upload?key=$_imgBBKey'));
      request.files.add(http.MultipartFile.fromBytes('image', bytes, filename: pickedImage.name));

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var jsonResponse = jsonDecode(responseData);

      if (response.statusCode == 200) {
        String downloadUrl = jsonResponse['data']['url'];
        await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({'profilePic': downloadUrl});
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Settings", style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          var userData = snapshot.data?.data() as Map<String, dynamic>?;
          String name = userData?['name'] ?? "User";
          String? profilePic = userData?['profilePic'];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 20),
                _buildAvatar(profilePic),
                const SizedBox(height: 15),
                // Name Display under Profile
                Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Text(user?.email ?? "", style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 30),
                
                _buildSettingsTile(Icons.person_outline, "Account Details", () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const AccountDetailsScreen()));
                }),
                _buildSettingsTile(Icons.security, "Privacy Policy", () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen()));
                }),
                
                const Divider(height: 40),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.blue),
                  title: const Text("Logout", style: TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () async {
                    await FirebaseAuth.instance.signOut();
                    if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const AuthScreen()), (route) => false);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAvatar(String? profilePic) {
    return Stack(
      children: [
        CircleAvatar(
          radius: 60,
          backgroundColor: AppColors.primary.withOpacity(0.1),
          backgroundImage: profilePic != null ? NetworkImage(profilePic) : null,
          child: profilePic == null ? const Icon(Icons.person, size: 60, color: AppColors.primary) : null,
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: CircleAvatar(
            backgroundColor: AppColors.primary,
            radius: 18,
            child: IconButton(
              icon: _isUploading 
                ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.camera_alt, color: Colors.white, size: 18),
              onPressed: _isUploading ? null : _updateProfilePicture,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}