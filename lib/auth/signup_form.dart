import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignupForm extends StatefulWidget {
  final VoidCallback onToggle;
  // This fix removes the red line in AuthScreen
  final Function(User, String) onSignupSuccess; 

  const SignupForm({
    super.key, 
    required this.onToggle, 
    required this.onSignupSuccess,
  });

  @override
  State<SignupForm> createState() => _SignupFormState();
}

class _SignupFormState extends State<SignupForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  String _selectedRole = 'Customer'; 
  final List<String> _signupRoles = ['Customer', 'Farm Owner', 'Delivery Rider'];

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  // --- THE FIXED FIREBASE LOGIC ---
  Future<void> _handleSignup() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        // 1. Create the user account in Firebase Auth
        UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        // 2. Save details to Firestore
        // CRITICAL FIX: Changed 'fullName' to 'name' to sync with CartProvider
        await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
          'name': _nameController.text.trim(), 
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
          'role': _selectedRole,
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          // 3. Trigger the success handler to redirect the user
          widget.onSignupSuccess(userCredential.user!, _selectedRole);
        }
      } on FirebaseAuthException catch (e) {
        String errorMsg = e.message ?? "Signup Failed";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
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
          _buildTextField(_nameController, "Full Name", Icons.person_outline),
          const SizedBox(height: 16),
          _buildTextField(_emailController, "Email Address", Icons.email_outlined, keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 16),
          _buildTextField(_phoneController, "Phone Number", Icons.phone_outlined, keyboardType: TextInputType.phone),
          const SizedBox(height: 16),
          
          // Role Selection
          DropdownButtonFormField<String>(
            value: _selectedRole,
            decoration: InputDecoration(
              labelText: "I am a...",
              prefixIcon: const Icon(Icons.badge_outlined, color: Color(0xFF2E7D32)),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            items: _signupRoles.map((role) => DropdownMenuItem(value: role, child: Text(role))).toList(),
            onChanged: (val) => setState(() => _selectedRole = val!),
          ),
          
          const SizedBox(height: 16),
          _buildPasswordField(_passwordController, "Password", _isPasswordVisible, () {
            setState(() => _isPasswordVisible = !_isPasswordVisible);
          }),
          const SizedBox(height: 16),
          _buildPasswordField(_confirmPasswordController, "Confirm Password", _isConfirmPasswordVisible, () {
            setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible);
          }, isConfirm: true),

          const SizedBox(height: 24),
          _isLoading 
            ? const CircularProgressIndicator() 
            : ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _handleSignup,
                child: const Text("CREATE ACCOUNT", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: widget.onToggle,
            child: const Text("Already have an account? Login", style: TextStyle(color: Color(0xFF2E7D32))),
          ),
        ],
      ),
    );
  }

  // UI Helpers
  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, {TextInputType? keyboardType}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label, 
        prefixIcon: Icon(icon, color: const Color(0xFF2E7D32)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
      validator: (v) => v!.isEmpty ? "Required" : null,
    );
  }

  Widget _buildPasswordField(TextEditingController ctrl, String label, bool visible, VoidCallback toggle, {bool isConfirm = false}) {
    return TextFormField(
      controller: ctrl,
      obscureText: !visible,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF2E7D32)),
        suffixIcon: IconButton(icon: Icon(visible ? Icons.visibility : Icons.visibility_off), onPressed: toggle),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
      validator: (v) {
        if (v!.length < 6) return "Min 6 characters";
        if (isConfirm && v != _passwordController.text) return "Passwords do not match";
        return null;
      },
    );
  }
}