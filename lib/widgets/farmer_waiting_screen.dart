import 'package:flutter/material.dart';

class FarmerWaitingScreen extends StatelessWidget {
  final String farmName;
  const FarmerWaitingScreen({super.key, required this.farmName});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.hourglass_top_rounded, size: 100, color: Colors.orange),
          const SizedBox(height: 24),
          Text(
            "Welcome, $farmName!",
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
          ),
          const SizedBox(height: 16),
          const Text(
            "Your registration is currently being verified by our Admin. Please check back later.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}