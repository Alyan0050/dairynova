import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import './auth_screen.dart';

class FarmStatusScreen extends StatelessWidget {
  final String farmName;

  const FarmStatusScreen({super.key, required this.farmName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // The "Cloud Avatar" Placeholder
              // You can replace this Icon with an Image.asset if you have a custom illustration
              Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.cloud_queue, size: 150, color: AppColors.secondary),
                  Positioned(
                    bottom: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        "VERIFICATION IN PROGRESS",
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              Text(
                "Be Calm, $farmName!",
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              const Text(
                "Your verification is currently in progress. This typically takes between 1 hour to 24 hours. You will gain access to your dashboard once approved.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: AppColors.grey, height: 1.5),
              ),
              
              const SizedBox(height: 48),

              // Go to Login Button
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const AuthScreen()),
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text("Go to Login"),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}