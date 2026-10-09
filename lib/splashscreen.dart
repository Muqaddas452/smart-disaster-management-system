import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // authIndex/citizens se role aur profile status check krne k liye
import 'package:firebase_auth/firebase_auth.dart'; // current logged-in user check krne k liye
import 'welcomescreen.dart';
import 'citizen_screens/citizen_home_screen.dart';
import 'citizen_screens/profile_completion_screen.dart';
import 'rescue_team/rescue_home_screen.dart';

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

  // ========================================================
  // Auth check logic — authIndex se role check karna
  // ========================================================
  Future<void> _checkAuthAndNavigate() async {
    if (!mounted) return;

    final currentUser = FirebaseAuth.instance.currentUser;

    // Step 1: agar koi bhi logged-in nahi h, seedha WelcomeScreen pe jana
    if (currentUser == null) {
      _goTo(const WelcomeScreen());
      return;
    }

    try {
      // Step 2: authIndex se is user ka role check karna
      final authIndexDoc = await FirebaseFirestore.instance
          .collection('authIndex')
          .doc(currentUser.uid)
          .get();

      if (!authIndexDoc.exists) {
        await FirebaseAuth.instance.signOut();
        _goTo(const WelcomeScreen());
        return;
      }

      final String role = authIndexDoc.get('role');

      if (role == 'citizen') {
        // Step 3a: citizen h — check karna profile complete h ya nahi
        final citizenDoc = await FirebaseFirestore.instance
            .collection('citizens')
            .doc(currentUser.uid)
            .get();

        final bool isComplete =
            (citizenDoc.data() as Map<String, dynamic>?)?['isProfileComplete'] ??
                false;

        if (isComplete) {
          _goTo(const HomeScreen()); // seedha citizen dashboard
        } else {
          _goTo(const ProfileCompletionScreen()); // profile adhoori h
        }
      } else if (role == 'rescue_team') {
        // Step 3b: rescue team member/leader h — fetch team data & navigate
        final userDoc = await FirebaseFirestore.instance
            .collection('rescueTeamUsers')
            .doc(currentUser.uid)
            .get();

        final userData = userDoc.data();
        final bool isLeader = userData?['isLeader'] ?? (userData?['role'] == 'leader');
        final String teamId = userData?['teamId'] ?? '';
        final String teamName = userData?['teamName'] ?? 'Rescue Team';

        _goTo(
          RescueTeamHomeScreen(
            isLeader: isLeader,
            teamId: teamId,
            teamName: teamName,
          ),
        );
      } else {
        // Step 3c: admin ya koi aur role, WelcomeScreen pe bhej dena
        _goTo(const WelcomeScreen());
      }
    } catch (e) {
      // error fallback
      _goTo(const WelcomeScreen());
    }
  }

  // helper — navigation
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