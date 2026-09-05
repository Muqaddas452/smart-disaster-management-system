import 'package:cloud_firestore/cloud_firestore.dart';

import '../model/resource_model.dart';

class ResourceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final String _collection = "resources";

  //==========================================================
  // GET ALL RESOURCES
  //==========================================================

  Stream<List<ResourceModel>> getResources() {
    return _firestore
        .collection(_collection)
        .orderBy("createdAt", descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
          .map((doc) => ResourceModel.fromFirestore(doc))
          .toList(),
    );
  }

  //==========================================================
  // ADD RESOURCE
  //==========================================================

  Future<void> addResource(
      ResourceModel resource,
      ) async {
    await _firestore
        .collection(_collection)
        .add(resource.toMap());
  }

  //==========================================================
  // UPDATE RESOURCE
  //==========================================================

  Future<void> updateResource(
      ResourceModel resource,
      ) async {
    await _firestore
        .collection(_collection)
        .doc(resource.id)
        .update(resource.toMap());
  }

  //==========================================================
  // DELETE RESOURCE
  //==========================================================

  Future<void> deleteResource(String id) async {
    await _firestore
        .collection(_collection)
        .doc(id)
        .delete();
  }

  //==========================================================
  // UPDATE QUANTITY
  //==========================================================

  Future<void> updateQuantity({
    required String id,
    required int quantity,
  }) async {
    await _firestore.collection(_collection).doc(id).update({
      "quantity": quantity,
    });
  }

  //==========================================================
  // STATISTICS
  //==========================================================

  Stream<int> totalResources() {
    return getResources().map(
          (list) => list.length,
    );
  }

  Stream<int> totalItems() {
    return getResources().map(
          (list) => list.fold(
        0,
            (sum, resource) => sum + resource.quantity,
      ),
    );
  }
}