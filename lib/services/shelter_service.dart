import 'package:cloud_firestore/cloud_firestore.dart';

import '../model/shelter_model.dart';

class ShelterService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final String _collection = "shelters";

  //==========================================================
  // GET ALL SHELTERS
  //==========================================================

  Stream<List<ShelterModel>> getShelters() {
    return _firestore
        .collection(_collection)
        .orderBy("createdAt", descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
          .map((doc) => ShelterModel.fromFirestore(doc))
          .toList(),
    );
  }

  //==========================================================
  // ADD SHELTER
  //==========================================================

  Future<void> addShelter(ShelterModel shelter) async {
    await _firestore
        .collection(_collection)
        .add(shelter.toMap());
  }

  //==========================================================
  // UPDATE SHELTER
  //==========================================================

  Future<void> updateShelter(
      ShelterModel shelter,
      ) async {
    await _firestore
        .collection(_collection)
        .doc(shelter.id)
        .update(shelter.toMap());
  }

  //==========================================================
  // DELETE SHELTER
  //==========================================================

  Future<void> deleteShelter(String id) async {
    await _firestore
        .collection(_collection)
        .doc(id)
        .delete();
  }

  //==========================================================
  // UPDATE OCCUPANCY
  //==========================================================

  Future<void> updateOccupancy({
    required String id,
    required int occupied,
  }) async {
    final doc =
    await _firestore.collection(_collection).doc(id).get();

    if (!doc.exists) return;

    final data = doc.data()!;

    final capacity = (data["capacity"] ?? 0) as int;

    await _firestore.collection(_collection).doc(id).update({
      "occupied": occupied,
      "status": occupied >= capacity ? "Full" : "Open",
    });
  }

  //==========================================================
  // UPDATE STATUS
  //==========================================================

  Future<void> updateStatus({
    required String id,
    required String status,
  }) async {
    await _firestore.collection(_collection).doc(id).update({
      "status": status,
    });
  }

  //==========================================================
  // STATISTICS
  //==========================================================

  Stream<int> totalShelters() {
    return getShelters().map((list) => list.length);
  }

  Stream<int> openShelters() {
    return getShelters().map(
          (list) => list
          .where((e) => e.status == "Open")
          .length,
    );
  }

  Stream<int> fullShelters() {
    return getShelters().map(
          (list) => list
          .where((e) => e.status == "Full")
          .length,
    );
  }

  Stream<int> totalCapacity() {
    return getShelters().map(
          (list) => list.fold(
        0,
            (sum, shelter) => sum + shelter.capacity,
      ),
    );
  }
}