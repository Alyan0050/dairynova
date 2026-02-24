import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Dashboards
import '../admin_dashboard.dart';
import '../farmer/farmer_dashboard.dart';
import '../customer/customer_home.dart'; 

// Auth Screens
import './register_farm_screen.dart';
import './login_form.dart';
import './signup_form.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  bool isLoading = false; // Track loading state for the gatekeeper

  void toggleView() => setState(() => isLogin = !isLogin);

  /// --- THE ENFORCED ROLE & STATUS GATEKEEPER ---
  Future<void> handleAuthSuccess(User user, String selectedUiRole) async {
    if (!mounted) return;

    setState(() => isLoading = true); // Start loading

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        String dbRole = data['role'] ?? '';

        // Role Mismatch Check
        if (dbRole != selectedUiRole) {
          await FirebaseAuth.instance.signOut();
          if (mounted) {
            setState(() => isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Access Denied: You are registered as $dbRole."),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }

        // Routing Logic
        if (mounted) {
          if (dbRole == 'Super Admin') {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AdminDashboard()));
          } else if (dbRole == 'Farm Owner') {
            String status = data['status'] ?? 'new'; 
            if (status == 'new') {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const RegisterFarmScreen()));
            } else if (status == 'pending') {
              setState(() => isLoading = false);
              _showWaitingDialog(context);
            } else if (status == 'verified') {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const FarmerDashboard()));
            }
          } else if (dbRole == 'Customer') {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const CustomerHome()));
          } else if (dbRole == 'Delivery Rider') {
            setState(() => isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Rider Dashboard coming soon!")));
          }
        }
      }
    } catch (e) {
      debugPrint("Auth Error: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showWaitingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Column(
          children: [
            Icon(Icons.hourglass_top_rounded, size: 50, color: Colors.orange),
            SizedBox(height: 10),
            Text("Review in Progress", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          "Your farm registration is under review. Please check back later.",
          textAlign: TextAlign.center,
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text("OK", style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9), // Matches your logo's light green theme
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // LOGO: Using the asset 
                    Image.asset(
                      'assets/images/logo.png',
                      height: 180, 
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 30),
                    
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: isLogin 
                        ? LoginForm(
                            key: const ValueKey("LoginForm"),
                            onToggle: toggleView, 
                            onLoginSuccess: handleAuthSuccess
                          ) 
                        : SignupForm(
                            key: const ValueKey("SignupForm"),
                            onToggle: toggleView,
                            onSignupSuccess: handleAuthSuccess
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Loading Overlay
          if (isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF2E7D32),
                ),
              ),
            ),
        ],
      ),
    );
  }
}