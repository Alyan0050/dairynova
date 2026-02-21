import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import './auth/auth_screen.dart';
import './system_logs_screen.dart'; // Import your new logs file
import '../utils/app_theme.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  bool _notif = true;
  bool _darkMode = false; 
  bool _isUploading = false;
  final String _imgBBKey = "YOUR_IMGBB_API_KEY";

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
    // Dynamic Theme Mapping
    Color bgColor = _darkMode ? Colors.grey[900]! : AppColors.background;
    Color textColor = _darkMode ? Colors.white : Colors.black87;
    Color cardColor = _darkMode ? Colors.grey[850]! : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          var userData = snapshot.data?.data() as Map<String, dynamic>?;
          String name = userData?['name'] ?? "Alyan Arif"; 
          String email = user?.email ?? "admin@dairynova.com";
          String? profilePic = userData?['profilePic'];
          String role = userData?['role'] ?? "Admin";

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text("Settings", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 20),
              
              // --- PROFILE CARD ---
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: _darkMode ? [] : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                ),
                child: Row(
                  children: [
                    _buildAvatar(profilePic, name),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                          Text(email, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
                            child: Text(role, style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 25),
              Text("PREFERENCES", style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 12)),
              const Divider(),

              SwitchListTile(
                activeColor: AppColors.primary,
                title: Text("System Notifications", style: TextStyle(color: textColor)),
                value: _notif,
                onChanged: (val) => setState(() => _notif = val),
              ),
              SwitchListTile(
                activeColor: AppColors.primary,
                title: Text("Dark Mode", style: TextStyle(color: textColor)),
                subtitle: Text("Change app appearance", style: TextStyle(color: Colors.grey[500])),
                value: _darkMode,
                onChanged: (val) => setState(() => _darkMode = val),
              ),

              // --- SUPER ADMIN SECTION ---
              if (role == 'Super Admin') ...[
                const SizedBox(height: 25),
                Text("ADMINISTRATIVE", style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 12)),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.security, color: Colors.blue),
                  title: Text("View System Logs", style: TextStyle(color: textColor)),
                  subtitle: const Text("Audit trail of all actions"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const SystemLogsScreen()));
                  },
                ),
              ],
              
              const SizedBox(height: 40),

              // --- LOGOUT ---
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _darkMode ? Colors.red[900]?.withOpacity(0.2) : Colors.red[50],
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: () => _showLogoutDialog(),
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text("Logout Admin Session", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              )
            ],
          );
        },
      ),
    );
  }

  Widget _buildAvatar(String? profilePic, String name) {
    return Stack(
      children: [
        CircleAvatar(
          radius: 35,
          backgroundColor: AppColors.primary,
          backgroundImage: profilePic != null ? NetworkImage(profilePic) : null,
          child: profilePic == null ? Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 24)) : null,
        ),
        Positioned(
          bottom: -5,
          right: -5,
          child: CircleAvatar(
            radius: 15,
            backgroundColor: _darkMode ? Colors.grey[800] : Colors.white,
            child: IconButton(
              icon: _isUploading 
                ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.camera_alt, size: 15, color: Colors.grey),
              onPressed: _isUploading ? null : _updateProfilePicture,
            ),
          ),
        ),
      ],
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const AuthScreen()), (route) => false);
              }
            },
            child: const Text("Logout", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}