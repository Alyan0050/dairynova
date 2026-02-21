import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

// Configuration & Theme
import './firebase_options.dart';
import './utils/app_theme.dart';

// Auth & Dashboards
import './auth/auth_screen.dart';

// State Management Models
import './models/cart_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase with platform-specific options
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    // Wrapping the app in MultiProvider is required for the Cart System
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
      ],
      child: const DairyNovaApp(),
    ),
  );
}

class DairyNovaApp extends StatelessWidget {
  const DairyNovaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Dairy Nova',
      theme: AppTheme.lightTheme, 
      home: const AuthScreen(), 
    );
  }
}