import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Login
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
  }

  /// Logout
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Current User
  User? get currentUser => _auth.currentUser;

  /// Check if current user is an active admin
  Future<bool> isAdminActive() async {
    final user = _auth.currentUser;

    if (user == null) return false;

    final doc = await _firestore
        .collection('admins')
        .doc(user.uid)
        .get();

    if (!doc.exists) {
      return false;
    }

    final data = doc.data()!;

    return data['active'] == true;
  }

  /// Get current admin document
  Future<DocumentSnapshot<Map<String, dynamic>>> getAdminData() async {
    final user = _auth.currentUser;

    return await _firestore
        .collection('admins')
        .doc(user!.uid)
        .get();
  }

  /// Reset Password
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(
      email: email.trim(),
    );
  }
}