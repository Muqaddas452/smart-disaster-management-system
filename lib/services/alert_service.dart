import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../model/alert_model.dart';

class AlertService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final String _collection = "broadcast_alerts";

  /// READ
  Stream<List<AlertModel>> getAlerts() {
    return _firestore
        .collection(_collection)
        .orderBy("createdAt", descending: true)
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((e) => AlertModel.fromFirestore(e)).toList());
  }

  /// CREATE
  Future<void> addAlert(AlertModel alert) async {
    await _firestore.collection(_collection).add(alert.toFirestore());
  }

  /// UPDATE
  Future<void> updateAlert(AlertModel alert) async {
    await _firestore
        .collection(_collection)
        .doc(alert.id)
        .update(alert.toFirestore());
  }

  /// DELETE
  Future<void> deleteAlert(String alertId) async {
    await _firestore.collection(_collection).doc(alertId).delete();
  }

  /// GET SINGLE ALERT
  Future<AlertModel?> getAlertById(String alertId) async {
    final doc =
    await _firestore.collection(_collection).doc(alertId).get();

    if (!doc.exists) return null;

    return AlertModel.fromFirestore(doc);
  }
  /// SEND ALERT USING FLASK
  Future<bool> sendAlertToAffectedUsers() async {
    try {
      final response = await http.post(
          Uri.parse("http://192.168.43.103:5000/sendAlert")      );

      return response.statusCode == 200;
    } catch (e) {
      print("Send Alert Error: $e");
      return false;
    }
  }
}