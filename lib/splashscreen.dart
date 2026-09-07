import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'welcomescreen.dart';
import 'home_screen.dart';
import 'profile_completion_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      _checkAuthAndNavigate();
    });
  }

  Future<void> _checkAuthAndNavigate() async {
    if (!mounted) return;

    final currentUser = FirebaseAuth.instance.currentUser;

    // Step 1: Agar koi logged-in nahi hai, WelcomeScreen par bhejein
    if (currentUser == null) {
      _goTo(const WelcomeScreen());
      return;
    }

    try {
      // Step 2: Firestore se check karein ke user ka document maujood hai ya nahi
      final citizenDoc = await FirebaseFirestore.instance
          .collection('citizens')
          .doc(currentUser.uid)
          .get();

      // Agar citizens collection mein record nahi mila, toh safety ke liye WelcomeScreen
      if (!citizenDoc.exists) {
        await FirebaseAuth.instance.signOut();
        _goTo(const WelcomeScreen());
        return;
      }

      // Step 3: Check karein ke profile complete hai ya nahi
      final bool isComplete =
          (citizenDoc.data() as Map<String, dynamic>?)?['isProfileComplete'] ??
              false;

      if (isComplete) {
        _goTo(const HomeScreen()); // Seedha Citizen Home Screen
      } else {
        _goTo(const ProfileCompletionScreen()); // Profile adhoori hai toh wahan bhejein
      }
    } catch (e) {
      // Kisi bhi error ki surat mein user ko stuck hone se bachane ke liye WelcomeScreen
      _goTo(const WelcomeScreen());
    }
  }

  void _goTo(Widget screen) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // LOGO (Apne asset path ke mutabiq check kar lein)
            Image.asset(
              'assets/images/logo.jpeg',
              width: 150,
              height: 150,
            ),
            const SizedBox(height: 20),
            const Text(
              'Smart Disaster Management System',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 30),
            const CircularProgressIndicator(
              color: Colors.green,
            ),
          ],
        ),
      ),
    );
  }
}

















