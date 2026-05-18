import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ========================================================
  // 1. CITIZEN REGISTRATION (SIGN UP)
  // ========================================================
  Future<void> registerCitizen({
    required String email,
    required String password,
    required BuildContext context,
  }) async {
    try {
      // Step A: Firebase Auth mien naya account create krna
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      String uid = userCredential.user!.uid;

      // Step B: Firestore mien 'Users' collection mien same UID se doc banana
      // NOTE: Agar console mien collection ka naam 'users' (small u) hai to yahan 'users' kr dein
      await _firestore.collection('Users').doc(uid).set({
        'email': email,
        'role': 'citizen',
        'isProfileComplete': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Step C: Naye citizen ko direct Profile Completion Screen pr bhejna
      Navigator.pushReplacementNamed(context, '/profileCompletion');

    } on FirebaseAuthException catch (e) {
      _showSnackBar(context, e.message ?? "Registration failed", Colors.red);
    } catch (e) {
      _showSnackBar(context, "An unexpected error occurred", Colors.red);
    }
  }

  // ========================================================
  // 2. LOGIN & ROLE-BASED VERIFICATION WITH ERROR MESSAGES
  // ========================================================
  Future<void> loginUser({
    required String email,
    required String password,
    required BuildContext context,
  }) async {
    try {
      // Step A: Firebase Auth mien sign in krna
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      String uid = userCredential.user!.uid;

      // Step B: Firestore se logged-in user ka document fetch krna
      DocumentSnapshot userDoc = await _firestore.collection('Users').doc(uid).get();

      if (userDoc.exists) {
        String role = userDoc.get('role');

        // Step C: Role check krna aur screens k mutabiq handle krna
        if (role == 'admin') {
          // Admin ki screen nahi hai, is liye error/info message show krwa rahe hien
          _showSnackBar(
              context,
              "Verification Successful: Welcome Admin! (Dashboard is under development)",
              Colors.blueGrey
          );
          // Chunkay screen nahi hai, hum user ko auth se signout kr dete hien takay state clear rahe
          await _auth.signOut();
        }
        else if (role == 'rescue_team') {
          // Rescue Team ki screen nahi hai, is liye error/info message show krwa rahe hien
          _showSnackBar(
              context,
              "Verification Successful: Welcome Rescue Member! (Module coming soon)",
              Colors.teal
          );
          await _auth.signOut();
        }
        else if (role == 'citizen') {
          // Citizen ki verification (Profile complete hai ya nahi)
          bool isComplete = userDoc.get('isProfileComplete') ?? false;

          if (isComplete) {
            // Agar complete hai to Home Screen pr bhejien
            Navigator.pushReplacementNamed(context, '/citizenHome');
          } else {
            // Agar complete nahi hai to Completion Screen pr bhejien
            _showSnackBar(context, "Please complete your profile first.", Colors.orange);
            Navigator.pushReplacementNamed(context, '/profileCompletion');
          }
        }
      } else {
        _showSnackBar(context, "User role details not found in database.", Colors.red);
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

      // Firestore mien basic data update krna aur isProfileComplete ko true krna
      await _firestore.collection('Users').doc(uid).update({
        'name': name,
        'phone': phone,
        'address': address,
        'isProfileComplete': true,
      });

      _showSnackBar(context, "Profile verified and completed successfully!", Colors.green);

      // Direct Citizen ki main Home Screen pr navigate krna
      Navigator.pushReplacementNamed(context, '/citizenHome');

    } catch (e) {
      _showSnackBar(context, "Failed to update profile: $e", Colors.red);
    }
  }

  // Custom Snackbar Helper function
  void _showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 15)),
        backgroundColor: color,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}