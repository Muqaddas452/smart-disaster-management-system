import 'package:cloud_firestore/cloud_firestore.dart'; // to read/write Firestore database
import 'package:firebase_auth/firebase_auth.dart'; // to create/sign in Firebase Auth accounts
import 'package:flutter/material.dart'; // needed for BuildContext and SnackBar

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance; // shortcut to Firebase Auth
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // shortcut to Firestore

  // ========================================================
  // 1. CITIZEN REGISTRATION (SIGN UP)
  // ========================================================
  Future<bool> registerCitizen({
    required String email,
    required String password,
    required String name,
    required String dob,
    required String gender,
    required BuildContext context,
  }) async {
    try {
      // Step A: create the account in Firebase Authentication
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      String uid = userCredential.user!.uid; // Firebase's unique ID for this user

      // Step B: save this citizen's full initial data in "citizens" collection
      await _firestore.collection('citizens').doc(uid).set({
        'email': email,
        'name': name,
        'dob': dob,
        'gender': gender,
        'isProfileComplete': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Step C: create an entry in "authIndex"
      await _firestore.collection('authIndex').doc(uid).set({
        'uid': uid,
        'role': 'citizen',
        'collection': 'citizens',
      });

      return true; // Indicate success so calling UI handles FCM & navigation smoothly
    } on FirebaseAuthException catch (e) {
      _showSnackBar(context, e.message ?? "Registration failed", Colors.red);
      return false;
    } catch (e) {
      _showSnackBar(context, "An unexpected error occurred", Colors.red);
      return false;
    }
  }

  // ========================================================
  // 2. LOGIN & ROLE-BASED VERIFICATION
  // ========================================================
  Future<void> loginUser({
    required String email,
    required String password,
    required BuildContext context,
  }) async {
    try {
      // Step A: sign in with Firebase Authentication
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      String uid = userCredential.user!.uid;

      // Step B: check "authIndex" first to find out this user's role
      DocumentSnapshot authIndexDoc =
      await _firestore.collection('authIndex').doc(uid).get();

      if (!authIndexDoc.exists) {
        _showSnackBar(context, "User role details not found in database.", Colors.red);
        await _auth.signOut();
        return;
      }

      final String role = authIndexDoc.get('role'); // 'citizen', 'rescue_team'/'rescue_leader'/'rescue_member', or 'admin'

      // Step C: handle each role differently
      // FIXED: this used to only check role == 'rescue_team', so a
      // 'rescue_leader' or 'rescue_member' account (the actual roles saved
      // during rescue registration) matched NONE of these branches — the
      // function silently returned with no redirect and no error message.
      if (role == 'rescue_team' || role == 'rescue_leader' || role == 'rescue_member') {
        _showSnackBar(
          context,
          "This is a rescue team account. Please use the Rescue Team login.",
          Colors.orange,
        );
        await _auth.signOut();
      } else if (role == 'admin') {
        _showSnackBar(
          context,
          "Verification Successful: Welcome Admin! (Dashboard is under development)",
          Colors.blueGrey,
        );
        await _auth.signOut();
      } else if (role == 'citizen') {
        DocumentSnapshot citizenDoc =
        await _firestore.collection('citizens').doc(uid).get();

        bool isComplete = (citizenDoc.data() as Map<String, dynamic>?)?['isProfileComplete'] ?? false;

        if (context.mounted) {
          if (isComplete) {
            Navigator.pushReplacementNamed(context, '/citizenHome');
          } else {
            _showSnackBar(context, "Please complete your profile first.", Colors.orange);
            Navigator.pushReplacementNamed(context, '/profileCompletion');
          }
        }
      } else {
        // Safety net: unknown/unhandled role — previously this silently did
        // nothing, leaving the user signed in with no screen change.
        _showSnackBar(context, "Account role not recognized. Please contact support.", Colors.red);
        await _auth.signOut();
      }
    } on FirebaseAuthException catch (e) {
      _showSnackBar(context, e.message ?? "Login failed", Colors.red);
    } catch (e) {
      _showSnackBar(context, "An error occurred: $e", Colors.red);
    }
  }

  // ========================================================
  // 3. CITIZEN PROFILE COMPLETION
  // ========================================================
  Future<void> completeCitizenProfile({
    required String name,
    required String phone,
    required String address,
    required BuildContext context,
  }) async {
    try {
      String uid = _auth.currentUser!.uid;

      await _firestore.collection('citizens').doc(uid).update({
        'name': name,
        'phone': phone,
        'address': address,
        'isProfileComplete': true,
      });

      _showSnackBar(context, "Profile verified and completed successfully!", Colors.green);

      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/citizenHome');
      }
    } catch (e) {
      _showSnackBar(context, "Failed to update profile: $e", Colors.red);
    }
  }

  // helper function to show a small colored popup message
  void _showSnackBar(BuildContext context, String message, Color color) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 15)),
        backgroundColor: color,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}