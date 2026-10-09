import 'package:cloud_firestore/cloud_firestore.dart';

import '../model/feedback_model.dart';

class FeedbackService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  //-----------------------------------------
  // Get All Feedback
  //-----------------------------------------

  Stream<List<FeedbackModel>> getFeedback() {
    return _firestore
        .collection("feedbacks")
        .orderBy("timestamp", descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
          .map((doc) => FeedbackModel.fromFirestore(doc))
          .toList(),
    );
  }

  //-----------------------------------------
  // Statistics
  //-----------------------------------------

  Stream<int> totalFeedback() {
    return _firestore
        .collection("feedbacks")
        .snapshots()
        .map((event) => event.docs.length);
  }

  Stream<int> newFeedback() {
    return _firestore
        .collection("feedbacks")
        .where("status", isEqualTo: "New")
        .snapshots()
        .map((event) => event.docs.length);
  }

  Stream<int> readFeedback() {
    return _firestore
        .collection("feedbacks")
        .where("status", isEqualTo: "Read")
        .snapshots()
        .map((event) => event.docs.length);
  }

  Stream<double> averageRating() {
    return _firestore
        .collection("feedbacks")
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return 0.0;
      }

      double total = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();

        total += (data["rating"] ?? 0).toDouble();
      }

      return total / snapshot.docs.length;
    });
  }

  //-----------------------------------------
  // Mark Feedback as Read
  //-----------------------------------------

  Future<void> markAsRead(String id) async {
    await _firestore.collection("feedbacks").doc(id).update({
      "status": "Read",
    });
  }

  //-----------------------------------------
  // Delete Feedback
  //-----------------------------------------

  Future<void> deleteFeedback(String id) async {
    await _firestore.collection("feedbacks").doc(id).delete();
  }
}