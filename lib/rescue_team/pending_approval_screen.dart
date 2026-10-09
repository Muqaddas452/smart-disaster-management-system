import 'package:flutter/material.dart'; // Flutter's core UI toolkit
import 'package:firebase_auth/firebase_auth.dart'; // to get the currently logged-in user
import 'package:cloud_firestore/cloud_firestore.dart'; // to read the team's status from Firestore
import '../citizen_screens/login_screen.dart'; // Login screen lives in lib/ (one folder up from rescue_team/)

class PendingApprovalScreen extends StatefulWidget {
  // Stateful because we need to show a loading spinner while checking status
  const PendingApprovalScreen({super.key}); // constructor, key used internally by Flutter

  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen> {
  // ---- Colors, same dark green + white theme as rest of the app ----
  static const MaterialColor _primaryGreen = Colors.green;

  bool _isChecking = false; // true while we're checking Firestore for status update

  // ======================================================
  // LOGIC: Check if admin has approved this leader's team yet
  // ======================================================
  Future<void> _checkApprovalStatus() async {
    setState(() => _isChecking = true); // show loading spinner on the button

    try {
      final User? currentUser =
          FirebaseAuth.instance.currentUser; // get the currently logged-in leader

      if (currentUser == null) {
        // if somehow no user is logged in, we can't check anything
        _showMessage('No user found. Please try logging in again.');
        return;
      }

      // look up this leader's document in "rescueTeamUsers" using their uid
      final docSnapshot = await FirebaseFirestore.instance
          .collection('rescueTeamUsers')
          .doc(currentUser.uid)
          .get();

      if (!docSnapshot.exists) {
        // safety check, in case the document was somehow deleted
        _showMessage('Could not find your registration record.');
        return;
      }

      final String status = docSnapshot.data()?['status'] ?? 'pending';
      // read the "status" field, default to 'pending' if it's missing for some reason

      if (status == 'approved') {
        // admin has approved! send the leader to Login so they can sign in properly
        _showMessage('Your team has been approved! Please log in.');

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            // pushAndRemoveUntil clears all previous screens, so back button won't return here
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false, // false means remove ALL previous routes
          );
        }
      } else if (status == 'rejected') {
        // admin rejected the request
        _showMessage('Your registration was rejected. Please contact support.');
      } else {
        // still pending, nothing to do yet
        _showMessage('Still waiting for admin approval. Please check back later.');
      }
    } catch (e) {
      // catches any unexpected error, e.g. no internet connection
      _showMessage('Something went wrong: $e');
    } finally {
      // finally runs whether it succeeded or failed
      if (mounted) setState(() => _isChecking = false); // turn off the spinner
    }
  }

  // helper function: shows a small popup message at the bottom of the screen
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // build() draws this screen every time Flutter needs to refresh it
    return Scaffold(
      backgroundColor: Colors.white, // plain white background, matches app theme
      body: SafeArea(
        // SafeArea keeps content away from notches/status bar
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0), // side spacing
          child: Column(
            mainAxisAlignment:
            MainAxisAlignment.center, // vertically centers everything on screen
            children: [
              // Big icon showing "waiting" status
              Icon(
                Icons.hourglass_top_rounded, // hourglass icon = waiting/pending
                size: 90, // large icon size
                color: _primaryGreen.shade800, // dark green color, matches theme
              ),
              const SizedBox(height: 24), // gap below icon

              // Main heading text
              Text(
                'Registration Under Review',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24, // large text for the heading
                  fontWeight: FontWeight.bold, // bold heading
                  color: _primaryGreen.shade800, // dark green, matches theme
                ),
              ),
              const SizedBox(height: 16), // gap below heading

              // Explanation text for the user
              const Text(
                'Your rescue team registration has been submitted successfully. '
                    'An admin will review your details and approve your team shortly. '
                    'You will be able to log in once approved.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15, // normal readable text size
                  color: Colors.black54, // grey text, less prominent than heading
                  height: 1.5, // line spacing for readability
                ),
              ),
              const SizedBox(height: 40), // gap before the button

              // Button to manually check if status has changed
              SizedBox(
                width: double.infinity, // full width button
                height: 56, // fixed height, same as other buttons in the app
                child: ElevatedButton(
                  onPressed: _isChecking
                      ? null // disable button while already checking
                      : _checkApprovalStatus, // otherwise run the check function
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryGreen.shade800, // dark green fill
                    foregroundColor: Colors.white, // white text/icon
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16), // rounded corners
                    ),
                  ),
                  child: _isChecking
                      ? const CircularProgressIndicator(
                      color: Colors.white) // spinner while checking
                      : const Text(
                    'Check Status',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}