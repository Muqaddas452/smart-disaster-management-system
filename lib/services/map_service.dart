import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/polygon_model.dart';
import '../models/rescue_team_model.dart';

class MapService {
  MapService._();

  static final MapService instance = MapService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  //----------------------------------------------------------
  // Live Affected Zones
  //----------------------------------------------------------

  Stream<List<PolygonModel>> getAffectedZones() {
    return _firestore
        .collection("affected_zones")
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => PolygonModel.fromFirestore(doc))
          .toList();
    });
  }

  //----------------------------------------------------------
  // Rescue Teams
  //----------------------------------------------------------

  Stream<List<RescueTeamModel>> getRescueTeams() {
    return Stream.value([]);
  }
}