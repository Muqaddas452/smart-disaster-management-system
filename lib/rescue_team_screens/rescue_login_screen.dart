import 'package:flutter/material.dart'; // Flutter's core UI toolkit
import 'package:firebase_auth/firebase_auth.dart'; // to log the user in with Firebase
import 'package:cloud_firestore/cloud_firestore.dart'; // to check the user's role in authIndex
import 'rescue_home_screen.dart'; // Rescue Team Dashboard, shown after successful login
import 'member_verification_screen.dart'; // used for "New member? Join here" link
import 'pending_approval_screen.dart';
import 'package:smartdisaster/services/fcm_token_service.dart';
import 'package:smartdisaster/services/email_verification.dart';
import 'package:smartdisaster/services/team_publish_service.dart'; // NEW — pending leaders/members get sent here instead of a dead-end error
import '/citizen_screens/forgotpassword.dart'; // shared Forgot Password screen, one folder up in lib/

class RescueLoginScreen extends StatefulWidget {
  const RescueLoginScreen({super.key});

  @override
  State<RescueLoginScreen> createState() => _RescueLoginScreenState();
}

class _RescueLoginScreenState extends State<RescueLoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _passwordVisible = false; // controls whether password dots are shown or hidden
  bool _isLoading = false; // true while Firebase is checking the login

  static const MaterialColor _primaryGreen = Colors.green; // main green used everywhere
  final Color _lightGreenBg = Colors.green.shade50; // very light green, behind the shield icon
  final Color _screenBg = Colors.grey.shade200; // light grey background for the whole screen

  @override
  void dispose() {
    // free up memory when this screen is closed
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ---- Email format check (same rule used across the whole app) ----
  bool _isValidEmail(String email) {
    return RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(email);
  }

  // ======================================================
  // LOGIC: Real Firebase login + role check
  // ======================================================
  Future<void> _handleLogin() async {
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();

    // basic empty-field check first
    if (email.isEmpty || password.isEmpty) {
      _showError('Please fill in all fields');
      return;
    }

    // check email format before even calling Firebase
    if (!_isValidEmail(email)) {
      _showError('Enter a valid email address');
      return;
    }

    setState(() => _isLoading = true); // show the spinner on the button

    try {
      // STEP 1: try to sign in with Firebase Authentication
      final UserCredential userCredential =
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final String uid = userCredential.user!.uid; // this user's unique Firebase ID

      // Email verify nahi hui => AuthWrapper verify screen dikhata hai.
      if (needsEmailVerification(userCredential.user)) {
        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
        return;
      }

      // Verify ho chuki: ruki hui team request admin ko bhejo.
      await publishPendingTeam(uid);

      // STEP 2: look up this uid in "authIndex" to confirm they are a rescue team user or member
      final authIndexDoc = await FirebaseFirestore.instance
          .collection('authIndex')
          .doc(uid)
          .get();

      final String? userRole = authIndexDoc.data()?['role'];

      // Allows rescue_member, rescue_leader, and rescue_team roles
      if (!authIndexDoc.exists ||
          (userRole != 'rescue_member' && userRole != 'rescue_leader' && userRole != 'rescue_team')) {
        // this account exists in Firebase Auth, but is NOT registered as rescue team
        await FirebaseAuth.instance.signOut(); // sign them back out immediately
        _showError('This account is not registered as a rescue team member.');
        return;
      }

      // STEP 3: double check their approval status & fetch details in "rescueTeamUsers"
      final userDoc = await FirebaseFirestore.instance
          .collection('rescueTeamUsers')
          .doc(uid)
          .get();

      // FIXED: distinguish "document genuinely missing" from "document exists
      // but status field says pending" — these used to be silently treated
      // the same way, which is exactly what made a past registration bug
      // show a misleading "awaiting approval" message.
      if (!userDoc.exists) {
        await FirebaseAuth.instance.signOut();
        _showError('Account data not found. Please contact support.');
        return;
      }

      final userData = userDoc.data();
      final String status = userData?['status'] ?? 'pending';

      if (status == 'pending') {
        // FIXED: instead of a dead-end error + forced sign-out, send them to
        // PendingApprovalScreen, which live-listens for admin approval and
        // will move them into the dashboard automatically once approved.
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const PendingApprovalScreen()),
          );
        }
        return;
      }

      if (status == 'rejected') {
        await FirebaseAuth.instance.signOut();
        _showError('Your registration was rejected. Please contact support.');
        return;
      }

      // Fetch dynamic fields required by RescueTeamHomeScreen
      // FIXED: fallback now checks 'rescue_leader' (the real stored value),
      // not 'leader' (a value that's never actually written anywhere)
      final bool isLeader = userData?['isLeader'] ?? (userData?['role'] == 'rescue_leader');
      final String teamId = userData?['teamId'] ?? '';
      final String teamName = userData?['teamName'] ?? 'Rescue Team';

      // Mark this user as online now that login is confirmed valid. Used by
      // the "Assign Team Members" screen to show Available/Busy/Offline.
      await FirebaseFirestore.instance.collection('rescueTeamUsers').doc(uid).update({
        'isOnline': true,
        'lastSeenAt': FieldValue.serverTimestamp(),
      });

      // Save this device's FCM token so leaders/members receive task
      // notifications (previously only citizens and brand-new members did).
      await FcmTokenService.saveFCMToken(uid, collection: 'rescueTeamUsers');
      FcmTokenService.listenForTokenRefresh(uid, collection: 'rescueTeamUsers');

      // STEP 4: navigate to Rescue Team Dashboard with dynamic params
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => RescueTeamHomeScreen(
              isLeader: isLeader,
              teamId: teamId,
              teamName: teamName,
            ),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      // Firebase gives specific error codes for login failures
      String message = 'Login failed. Please try again.';
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = 'Incorrect email or password.';
      } else if (e.code == 'invalid-email') {
        message = 'Enter a valid email address.';
      }
      _showError(message);
    } catch (e) {
      // catches any other unexpected error, e.g. no internet
      _showError('Something went wrong: $e');
    } finally {
      // runs whether login succeeded or failed
      if (mounted) setState(() => _isLoading = false); // stop the spinner
    }
  }

  // helper function to show a small red popup message at the bottom
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _screenBg, // light grey background, matches original design
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              const SizedBox(height: 16),

              // ── Top "Login" title ──
              const Text(
                'Login',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 36),

              // ── Shield Icon with green circle background ──
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: _lightGreenBg,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.shield,
                    size: 60,
                    color: _primaryGreen.shade600,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // ── Screen title ──
              const Text(
                'Rescue Team Login',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 8),

              // ── Subtitle ──
              Text(
                'Secure access for emergency responders',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 36),

              // ── Email Field ──
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'Enter your email',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
                    prefixIcon: Icon(Icons.email_outlined, color: Colors.grey[400]),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 18,
                      horizontal: 20,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Password Field ──
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: TextField(
                  controller: _passwordController,
                  obscureText: !_passwordVisible,
                  decoration: InputDecoration(
                    hintText: 'Enter your password',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
                    prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[400]),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _passwordVisible
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: Colors.grey[400],
                      ),
                      onPressed: () {
                        setState(() => _passwordVisible = !_passwordVisible);
                      },
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 18,
                      horizontal: 20,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ── Login Button ──
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryGreen.shade600,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                    elevation: 4,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                    'Login',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Forgot Password ──
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ForgotPasswordScreen(),
                    ),
                  );
                },
                child: Text(
                  'Forgot Password?',
                  style: TextStyle(
                    color: _primaryGreen.shade600,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // ── Bottom Text ──
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MemberVerificationScreen(),
                    ),
                  );
                },
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    text: 'New member? ',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    children: [
                      TextSpan(
                        text: 'Join your team here',
                        style: TextStyle(
                          color: _primaryGreen.shade600,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}