
import 'package:cloud_firestore/cloud_firestore.dart';

import '../model/affected_zone_model.dart';

class AffectedZoneService {
final FirebaseFirestore _firestore =
FirebaseFirestore.instance;

final String _collection = "affected_zones";

// Collection used to remember zones deleted by admin
final String _deletedCollection =
"deleted_affected_zones";

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

try {
// STEP 1:
// Remember that admin deleted this zone
await _firestore
    .collection(_deletedCollection)
    .doc(zoneId)
    .set({
"zoneId": zoneId,
"deletedAt":
FieldValue.serverTimestamp(),
});

// STEP 2:
// Delete the actual affected zone
await _firestore
    .collection(_collection)
    .doc(zoneId)
    .delete();

print(
"Affected zone deleted: $zoneId",
);

} catch (e) {
print(
"Error deleting affected zone: $e",
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
