import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/citizen_screens/login_screen.dart'; // only used for the rejected/exit path
import 'rescue_home_screen.dart'; // Rescue Team Dashboard, shown automatically once approved

class PendingApprovalScreen extends StatefulWidget {
  const PendingApprovalScreen({super.key});

  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen> {
  static const MaterialColor _primaryGreen = Colors.green;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _statusSubscription;
  String _status = 'pending'; // 'pending' | 'approved' | 'rejected'
  bool _isProcessing = false; // true once we start navigating away / signing out

  @override
  void initState() {
    super.initState();
    _listenForApproval();
  }

  @override
  void dispose() {
    _statusSubscription?.cancel(); // stop listening once this screen is gone
    super.dispose();
  }

  // ======================================================
  // LOGIC: Live-listen to this leader's rescueTeamUsers doc.
  // As soon as admin flips status to 'approved', jump straight
  // into the Rescue Dashboard automatically — no manual "Check
  // Status" tap, no re-login needed.
  // ======================================================
  void _listenForApproval() {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      _showMessage('No user found. Please try logging in again.');
      return;
    }

    _statusSubscription = FirebaseFirestore.instance
        .collection('rescueTeamUsers')
        .doc(currentUser.uid)
        .snapshots()
        .listen((docSnapshot) async {
      if (!docSnapshot.exists || _isProcessing) return;

      final data = docSnapshot.data();
      final String status = data?['status'] ?? 'pending';

      if (status == _status) return; // no real change, ignore duplicate events

      setState(() => _status = status);

      if (status == 'approved') {
        _isProcessing = true;
        await _goToDashboard(currentUser.uid, data!);
      } else if (status == 'rejected') {
        _showMessage('Your registration was rejected. Please contact support.');
      }
      // if still 'pending', nothing to do — UI already reflects the wait
    }, onError: (e) {
      _showMessage('Could not check approval status: $e');
    });
  }

  // ======================================================
  // LOGIC: Move into the Rescue Dashboard once approved.
  // ======================================================
  Future<void> _goToDashboard(String uid, Map<String, dynamic> userData) async {
    _statusSubscription?.cancel(); // stop listening, we're leaving this screen

    final bool isLeader = userData['isLeader'] ?? (userData['role'] == 'leader');
    final String teamId = userData['teamId'] ?? '';
    final String teamName = userData['teamName'] ?? 'Rescue Team';

    // mark this leader online now, same as a normal login would
    await FirebaseFirestore.instance.collection('rescueTeamUsers').doc(uid).update({
      'isOnline': true,
      'lastSeenAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => RescueTeamHomeScreen(
          isLeader: isLeader,
          teamId: teamId,
          teamName: teamName,
        ),
      ),
          (route) => false, // clears the whole stack — nothing left to "back" into
    );
  }

  // ======================================================
  // LOGIC: Only reachable when registration was rejected —
  // signs the user out and sends them to a clean Login screen.
  // ======================================================
  Future<void> _signOutAndExit() async {
    setState(() => _isProcessing = true);
    try {
      await FirebaseAuth.instance.signOut();
    } finally {
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen()),
              (route) => false,
        );
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final bool isRejected = _status == 'rejected';

    return PopScope(
      // While pending, there's nothing useful to go "back" to — block it
      // entirely instead of letting Flutter reveal whatever sits underneath
      // this screen in the navigation stack (e.g. a citizen dashboard).
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (isRejected) {
          _signOutAndExit();
        } else {
          _showMessage('Please wait until your team is approved.');
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isRejected ? Icons.cancel_outlined : Icons.hourglass_top_rounded,
                  size: 90,
                  color: isRejected ? Colors.red.shade700 : _primaryGreen.shade800,
                ),
                const SizedBox(height: 24),
                Text(
                  isRejected ? 'Registration Rejected' : 'Registration Under Review',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isRejected ? Colors.red.shade700 : _primaryGreen.shade800,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isRejected
                      ? 'Your rescue team registration was rejected. Please contact support for more details.'
                      : 'Your rescue team registration has been submitted successfully. '
                      'An admin will review your details and approve your team shortly. '
                      'You will be taken to your dashboard automatically once approved — '
                      'no need to log in again.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.black54,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 40),
                if (isRejected)
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _signOutAndExit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isProcessing
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Back to Login', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    ),
                  )
                else
                  const CircularProgressIndicator(), // shows we're actively watching for approval
              ],
            ),
          ),
        ),
      ),
    );
  }
}