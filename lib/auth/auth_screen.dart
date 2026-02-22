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

  void toggleView() => setState(() => isLogin = !isLogin);

  /// Handles Navigation after Login or Signup
  /// This logic ensures users go to the right place based on their role
  Future<void> handleAuthSuccess(User user, String selectedRole) async {
    if (!mounted) return;

    // 1. Super Admin Redirect (Strict Email Check)
    if (selectedRole == 'Super Admin' && user.email == "admin@dairynova.com") {
      Navigator.pushReplacement(
        context, 
        MaterialPageRoute(builder: (context) => const AdminDashboard())
      );
      return;
    }

    // 2. Farm Owner Redirect
    if (selectedRole == 'Farm Owner') {
      final farmQuery = await FirebaseFirestore.instance
          .collection('farms')
          .where('ownerId', isEqualTo: user.uid)
          .get();

      if (mounted) {
        if (farmQuery.docs.isEmpty) {
          // Send to registration if they haven't set up their farm yet
          Navigator.pushReplacement(
            context, 
            MaterialPageRoute(builder: (context) => const RegisterFarmScreen())
          );
        } else {
          Navigator.pushReplacement(
            context, 
            MaterialPageRoute(builder: (context) => const FarmerDashboard())
          );
        }
      }
      return;
    } 

    // 3. Customer Redirect
    if (selectedRole == 'Customer') {
      if (mounted) {
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (context) => const CustomerHome())
        );
      }
      return;
    }

    // Fallback for unexpected roles
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Access restricted for role: $selectedRole"))
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const Icon(Icons.agriculture, size: 80, color: Color(0xFF2E7D32)),
                const SizedBox(height: 16),
                const Text(
                  "Dairy Nova", 
                  style: TextStyle(
                    fontSize: 28, 
                    fontWeight: FontWeight.bold, 
                    color: Color(0xFF2E7D32)
                  )
                ),
                const SizedBox(height: 32),
                
                // FIXED: Now providing the required onSignupSuccess parameter
                isLogin 
                  ? LoginForm(
                      onToggle: toggleView, 
                      onLoginSuccess: handleAuthSuccess
                    ) 
                  : SignupForm(
                      onToggle: toggleView,
                      onSignupSuccess: handleAuthSuccess // RED LINE FIXED
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}