import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // authIndex/citizens se role aur profile status check krne k liye
import 'package:firebase_auth/firebase_auth.dart'; // current logged-in user check krne k liye
import 'welcomescreen.dart';
import 'main.dart';
import 'rescue_team_screens/pending_approval_screen.dart';
import 'citizen_screens/citizen_home_screen.dart';
import 'citizen_screens/profile_completion_screen.dart';
import 'rescue_team_screens/rescue_home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}
class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();
    // Splash guaranteed 3 second dikhegi, phir AuthWrapper pe jayegi.
    // Auth / role / approval / email-verify ka saara routing ab sirf
    // AuthWrapper (main.dart) karta hai — yahan duplicate logic nahi h.
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AuthWrapper()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // LOGO
            Image.asset(
              'assets/images/logo.jpeg',
              width: 150,
              height: 150,
            ),
            const SizedBox(height: 20),
            // App name
            const Text(
              'Smart Disaster Management System',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 30),
            // Loading indicator
            const CircularProgressIndicator(
              color: Colors.green,
            ),
          ],
        ),
      ),
    );
  }
}












