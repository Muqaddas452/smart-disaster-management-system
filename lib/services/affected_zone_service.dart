import 'package:cloud_firestore/cloud_firestore.dart';

import '../model/affected_zone_model.dart';

class AffectedZoneService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final String _collection = "affected_zones";

  /// ==========================
  /// READ - REALTIME STREAM
  /// ==========================
  Stream<List<AffectedZone>> getAffectedZones() {
    return _firestore
        .collection(_collection)
        .orderBy("createdAt", descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
          .map(
            (doc) => AffectedZone.fromFirestore(doc),
      )
          .toList(),
    );
  }

  /// ==========================
  /// CREATE
  /// ==========================
  Future<void> addAffectedZone(
      AffectedZone zone) async {
    await _firestore
        .collection(_collection)
        .add(zone.toMap());
  }

  /// ==========================
  /// UPDATE
  /// ==========================
  Future<void> updateAffectedZone(
      AffectedZone zone) async {
    if (zone.id.isEmpty) {
      throw Exception("Affected zone ID is empty.");
    }

    await _firestore
        .collection(_collection)
        .doc(zone.id)
        .update({
      "zoneName": zone.zoneName,
      "city": zone.city,
      "disasterType": zone.disasterType,
      "riskLevel": zone.riskLevel,
      "population": zone.population,
      "status": zone.status,
      "latitude": zone.latitude,
      "longitude": zone.longitude,
    });
  }

  /// ==========================
  /// DELETE
  /// ==========================
  Future<void> deleteAffectedZone(
      String zoneId) async {
    if (zoneId.isEmpty) {
      throw Exception(
        "Cannot delete zone because ID is empty.",
      );
    }

    try {
      final zoneRef = _firestore
          .collection(_collection)
          .doc(zoneId);

      // Check that the document exists
      final document = await zoneRef.get();

      if (!document.exists) {
        throw Exception(
          "Affected zone does not exist.",
        );
      }

      // Delete the actual affected zone
      await zoneRef.delete();

      print(
        "Affected zone deleted successfully: $zoneId",
      );
    } catch (e) {
      print(
        "DELETE ERROR: $e",
      );

      rethrow;
    }
  }

  /// ==========================
  /// GET SINGLE ZONE
  /// ==========================
  Future<AffectedZone?> getZoneById(
      String zoneId) async {
    final doc = await _firestore
        .collection(_collection)
        .doc(zoneId)
        .get();

    if (!doc.exists) {
      return null;
    }

    return AffectedZone.fromFirestore(doc);
  }

  /// ==========================
  /// TOTAL ZONES
  /// ==========================
  Future<int> totalZones() async {
    final snapshot = await _firestore
        .collection(_collection)
        .get();

    return snapshot.docs.length;
  }

  /// ==========================
  /// HIGH RISK COUNT
  /// ==========================
  Future<int> highRiskZones() async {
    final snapshot = await _firestore
        .collection(_collection)
        .where(
      "riskLevel",
      isEqualTo: "High",
    )
        .get();

    return snapshot.docs.length;
  }

  /// ==========================
  /// ACTIVE ZONES COUNT
  /// ==========================
  Future<int> activeZones() async {
    final snapshot = await _firestore
        .collection(_collection)
        .where(
      "status",
      isEqualTo: "Active",
    )
        .get();

    return snapshot.docs.length;
  }

  /// ==========================
  /// SAFE ZONES COUNT
  /// ==========================
  Future<int> safeZones() async {
    final snapshot = await _firestore
        .collection(_collection)
        .where(
      "riskLevel",
      isEqualTo: "Low",
    )
        .get();

    return snapshot.docs.length;
  }
}