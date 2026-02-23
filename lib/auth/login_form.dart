import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import '../utils/app_theme.dart';

class LoginForm extends StatefulWidget {
  final VoidCallback onToggle;
  final Function(User, String) onLoginSuccess;

  const LoginForm({
    super.key, 
    required this.onToggle, 
    required this.onLoginSuccess
  });

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  String _selectedRole = 'Customer';
  final List<String> _loginRoles = [
    'Customer', 
    'Farm Owner', 
    'Delivery Rider', 
    'Super Admin'
  ];

  bool _isLoading = false;
  bool _isPasswordVisible = false;

  // --- THE FIREBASE LOGIN LOGIC ---
  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        // 1. Authenticate with Firebase Auth
        UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        // 2. Fetch User Data from Firestore to verify the real identity
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .get();

        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>;
          
          // Get the actual role from DB. If missing (old data), default to Customer.
          String dbRole = data.containsKey('role') ? data['role'] : 'Customer';

          // 3. Admin & Role Verification
          // We prioritize the Database Role. If it says "Super Admin", they get Admin access
          // regardless of what they picked in the dropdown.
          if (mounted) {
            if (dbRole == 'Super Admin') {
               ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Welcome back, Administrator"), backgroundColor: Colors.black87),
              );
            } else if (dbRole != _selectedRole) {
               ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Logging in as $dbRole")),
              );
            }
            
            // Send the REAL database role back to the AuthScreen/Gatekeeper
            widget.onLoginSuccess(userCredential.user!, dbRole);
          }
        } else {
          // If user exists in Auth but not Firestore, fallback to dropdown choice
          widget.onLoginSuccess(userCredential.user!, _selectedRole);
        }

      } on FirebaseAuthException catch (e) {
        _showError(e.message ?? "Login Failed");
      } catch (e) {
        _showError("An unexpected error occurred. Please try again.");
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message), 
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: _selectedRole,
            decoration: const InputDecoration(
              labelText: "Login as...",
              prefixIcon: Icon(Icons.badge_outlined, color: AppColors.primary),
            ),
            items: _loginRoles.map((role) {
              return DropdownMenuItem(value: role, child: Text(role));
            }).toList(),
            onChanged: (val) => setState(() => _selectedRole = val!),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: "Email Address",
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (value) => value!.isEmpty ? "Email is required" : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: !_isPasswordVisible,
            decoration: InputDecoration(
              labelText: "Password",
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
              ),
            ),
            validator: (value) => value!.isEmpty ? "Password is required" : null,
          ),
          const SizedBox(height: 24),
          _isLoading 
            ? const CircularProgressIndicator() 
            : ElevatedButton(
                onPressed: _handleLogin,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text("LOGIN", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: widget.onToggle,
            child: const Text.rich(
              TextSpan(
                text: "Don't have an account? ",
                style: TextStyle(color: AppColors.grey),
                children: [
                  TextSpan(
                    text: "Sign Up",
                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}