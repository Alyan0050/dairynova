import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; //
import '../utils/app_theme.dart'; //

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
        // Authenticate with Firebase
        UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        if (mounted) {
          // Send user and role back to the AuthScreen "Gatekeeper"
          widget.onLoginSuccess(userCredential.user!, _selectedRole);
        }
      } on FirebaseAuthException catch (e) {
        // Show user-friendly error messages (e.g., "Wrong password")
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? "Login Failed"), 
            backgroundColor: AppColors.error
          ),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Role Selection - Matches the Signup Screen
          DropdownButtonFormField<String>(
            value: _selectedRole,
            decoration: InputDecoration(
              labelText: "Login as...",
              prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.primary),
            ),
            items: _loginRoles.map((role) {
              return DropdownMenuItem(value: role, child: Text(role));
            }).toList(),
            onChanged: (val) => setState(() => _selectedRole = val!),
          ),
          const SizedBox(height: 16),

          // Email Field
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

          // Password Field
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

          // Action Button
          _isLoading 
            ? const CircularProgressIndicator() 
            : ElevatedButton(
                onPressed: _handleLogin,
                child: const Text("LOGIN", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              ),
          
          const SizedBox(height: 16),
          
          // Toggle to Signup
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