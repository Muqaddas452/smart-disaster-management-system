import 'package:flutter/material.dart';
import 'package:smart_disaster_management_system/profile%20_screen.dart';
import 'package:smart_disaster_management_system/splashscreen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'welcomescreen.dart';
import 'signupscreen.dart';
import 'login_screen.dart';
import 'forgotpassword.dart';
import 'home_screen.dart';
import 'report_screen.dart';
import 'alert_screen.dart';
import 'alert_details_screen.dart';
import 'gps_access_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(const SmartDisasterApp());
}

class SmartDisasterApp extends StatelessWidget {
  const SmartDisasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Disaster Management System',
      debugShowCheckedModeBanner: false,
          theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B5E20)),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
      routes: {
        '/splash': (context) => const SplashScreen(),         // Jo bhi aap ka asli class name hai
        '/login': (context) => const LoginScreen(),               // Agar aap ne class ka naam LoginView rakha hai
        '/register': (context) => const SignUpScreen(),         // Agar class ka naam SignUpScreen hai
        '/profileCompletion': (context) => const ProfileCompletionScreen(), // Asli class name
        '/citizenHome': (context) => const HomeScreen(),  // Agar class ka naam CitizenDashboard hai
      },
    );
  }
}