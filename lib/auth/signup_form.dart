import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignupForm extends StatefulWidget {
  final VoidCallback onToggle;
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

  // --- THE IMPROVED ROLE-BASED SIGNUP LOGIC ---
  Future<void> _handleSignup() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        // 1. Create the user account in Firebase Auth
        UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        // 2. Prepare user-specific data map
        Map<String, dynamic> userData = {
          'uid': userCredential.user!.uid,
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
          'role': _selectedRole, // 'Customer', 'Farm Owner', etc.
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'Active',
        };

        // --- ROLE ISOLATION: Initialize specific data structures ---
        if (_selectedRole == 'Farm Owner') {
          userData['hasFarmRegistered'] = false;
          userData['farmId'] = ""; // Link to their farm document later
          userData['isApproved'] = false; // For Super Admin verification
        } else if (_selectedRole == 'Customer') {
          userData['deliveryAddress'] = "";
          userData['totalOrders'] = 0;
          userData['cart'] = []; // Initialize empty cart structure
        } else if (_selectedRole == 'Delivery Rider') {
          userData['isAvailable'] = false;
          userData['currentLocation'] = null;
        }

        // 3. Save details to Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set(userData);

        if (mounted) {
          // 4. Signal success to the parent AuthScreen
          widget.onSignupSuccess(userCredential.user!, _selectedRole);
        }
      } on FirebaseAuthException catch (e) {
        _showError(e.message ?? "Signup Failed");
      } catch (e) {
        _showError("An unexpected error occurred. Please try again.");
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
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
          
          // Role Selection Dropdown
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

  // --- UI Helpers with Added Validation ---
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
      validator: (v) {
        if (v == null || v.isEmpty) return "Required";
        if (label == "Phone Number") {
          // Validates PK numbers starting with 03 or +92
          if (!RegExp(r'^((\+92)|(03))[0-9]{9,10}$').hasMatch(v.replaceAll(" ", ""))) {
            return "Invalid PK Phone Number";
          }
        }
        if (label == "Email Address" && !v.contains("@")) return "Invalid Email";
        return null;
      },
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
        if (v == null || v.isEmpty) return "Required";
        if (v.length < 6) return "Min 6 characters";
        if (isConfirm && v != _passwordController.text) return "Passwords do not match";
        return null;
      },
    );
  }
}