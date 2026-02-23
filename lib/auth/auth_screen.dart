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

  /// --- THE GATEKEEPER LOGIC ---
  /// Navigates the user based on their verified database role
  Future<void> handleAuthSuccess(User user, String dbRole) async {
    if (!mounted) return;

    // 1. Super Admin Redirect
    // Logic: If Firestore confirms they are an Admin, let them in.
    if (dbRole == 'Super Admin') {
      Navigator.pushReplacement(
        context, 
        MaterialPageRoute(builder: (context) => const AdminDashboard())
      );
      return;
    }

    // 2. Farm Owner Redirect
    if (dbRole == 'Farm Owner') {
      try {
        // We check the 'users' document for the 'hasFarmRegistered' flag
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        bool hasFarm = false;
        if (userDoc.exists) {
          hasFarm = userDoc.data()?['hasFarmRegistered'] ?? false;
        }

        if (mounted) {
          if (!hasFarm) {
            // New owner who hasn't registered their farm profile yet
            Navigator.pushReplacement(
              context, 
              MaterialPageRoute(builder: (context) => const RegisterFarmScreen())
            );
          } else {
            // Established owner heading to their farm dashboard
            Navigator.pushReplacement(
              context, 
              MaterialPageRoute(builder: (context) => const FarmerDashboard())
            );
          }
        }
      } catch (e) {
        debugPrint("Error fetching farm status: $e");
      }
      return;
    } 

    // 3. Customer Redirect
    if (dbRole == 'Customer') {
      if (mounted) {
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (context) => const CustomerHome())
        );
      }
      return;
    }

    // 4. Delivery Rider Redirect
    if (dbRole == 'Delivery Rider') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Rider Dashboard coming soon!"))
        );
      }
      return;
    }

    // Final Fallback for unexpected data
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Access restricted for: $dbRole"))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9), // Light Green Background
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Branding Section
                const Icon(Icons.agriculture, size: 80, color: Color(0xFF2E7D32)),
                const SizedBox(height: 16),
                const Text(
                  "Dairy Nova", 
                  style: TextStyle(
                    fontSize: 28, 
                    fontWeight: FontWeight.bold, 
                    color: Color(0xFF2E7D32),
                    letterSpacing: 1.5,
                  )
                ),
                const Text(
                  "Freshness at your doorstep", 
                  style: TextStyle(fontSize: 14, color: Colors.grey)
                ),
                const SizedBox(height: 40),
                
                // Auth Form Section
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
    );
  }
}