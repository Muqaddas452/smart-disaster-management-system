import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AlertService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sirf logged-in citizen ke specific alerts stream karna
  Stream<QuerySnapshot> getCitizenAlerts() {
    String uid = _auth.currentUser?.uid ?? '';
    if (uid.isEmpty) return const Stream.empty();

    return _firestore
        .collection('citizens')
        .doc(uid)
        .collection('alerts')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}