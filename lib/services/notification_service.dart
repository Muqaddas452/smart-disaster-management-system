import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/notification_model.dart';

class NotificationService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  Stream<List<NotificationModel>> getNotifications() {
    return _firestore
        .collection("Notifications")
        .orderBy("createdAt", descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
          .map(
            (doc) =>
            NotificationModel.fromFirestore(doc),
      )
          .toList(),
    );
  }

  Future<void> markAsRead(String notificationId) async {
    await _firestore
        .collection("Notifications")
        .doc(notificationId)
        .update({
      "read": true,
    });
  }
}