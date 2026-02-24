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

  /// --- THE ENFORCED ROLE & STATUS GATEKEEPER ---
  /// Compares the selected login role with the real role in Firestore
  Future<void> handleAuthSuccess(User user, String selectedUiRole) async {
    if (!mounted) return;

    try {
      // 1. Fetch the actual profile from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        String dbRole = data['role'] ?? ''; // Actual role from database

        // --- NEW: ROLE MISMATCH CHECK ---
        // Prevents Farm Owners from logging in as Customers and vice versa
        if (dbRole != selectedUiRole) {
          await FirebaseAuth.instance.signOut(); // Immediately invalidate the session
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Access Denied: You are registered as a $dbRole, not a $selectedUiRole."),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return; // Stop the routing process
        }

        // 2. Proceed with routing if roles match correctly
        
        // --- SUPER ADMIN ROUTE ---
        if (dbRole == 'Super Admin') {
          Navigator.pushReplacement(
            context, 
            MaterialPageRoute(builder: (context) => const AdminDashboard())
          );
          return;
        }

        // --- FARM OWNER ROUTE ---
        if (dbRole == 'Farm Owner') {
          String status = data['status'] ?? 'new'; 

          if (mounted) {
            if (status == 'new') {
              Navigator.pushReplacement(
                context, 
                MaterialPageRoute(builder: (context) => const RegisterFarmScreen())
              );
            } else if (status == 'pending') {
              _showWaitingDialog(context);
            } else if (status == 'verified') {
              Navigator.pushReplacement(
                context, 
                MaterialPageRoute(builder: (context) => const FarmerDashboard())
              );
            }
          }
          return;
        }

        // --- CUSTOMER ROUTE ---
        if (dbRole == 'Customer') {
          Navigator.pushReplacement(
            context, 
            MaterialPageRoute(builder: (context) => const CustomerHome())
          );
          return;
        }

        // --- DELIVERY RIDER ROUTE ---
        if (dbRole == 'Delivery Rider') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Rider Dashboard coming soon!"))
          );
          return;
        }
      }
    } catch (e) {
      debugPrint("Auth Error: $e");
    }
  }

  // Dialog to inform unverified farmers of their status
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
          "Your farm registration is currently under review by our Admin team. Please check back later.",
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
      backgroundColor: const Color(0xFFF1F8E9),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
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