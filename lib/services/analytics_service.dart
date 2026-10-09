import 'package:cloud_firestore/cloud_firestore.dart';

import '../model/analytics_model.dart';

class AnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<AnalyticsModel> getAnalytics() {
    return _firestore
        .collection("latest_alerts")
        .snapshots()
        .asyncMap((alertsSnapshot) async {
      //---------------- LOAD DATA IN PARALLEL ----------------//

      final results = await Future.wait([
        _firestore.collection("manual_reports").get(),
        _firestore.collection("rescueTeams").get(),
      ]);

      final QuerySnapshot reports = results[0] as QuerySnapshot;
      final QuerySnapshot rescue = results[1] as QuerySnapshot;

      //---------------- TOTAL REPORTS ----------------//

      final int totalReports = reports.docs.length;

      //---------------- ACTIVE DISASTERS ----------------//

      final int activeDisasters = alertsSnapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;

        final disaster =
        (data["disaster"] ?? "Normal").toString().toLowerCase();

        return disaster != "normal";
      }).length;

      //---------------- PEOPLE RESCUED ----------------//

      final int rescuedPeople = rescue.docs.length;

      //---------------- DISASTER DISTRIBUTION ----------------//

      final Map<String, int> distribution = {};

      for (var doc in reports.docs) {
        final data = doc.data() as Map<String, dynamic>;

        final String disaster =
        (data["incident_type"] ??
            data["emergencyType"] ??
            "Unknown")
            .toString();

        distribution[disaster] =
            (distribution[disaster] ?? 0) + 1;
      }

      //---------------- MONTHLY REPORTS ----------------//

      final List<double> monthly = List.filled(12, 0);

      for (var doc in reports.docs) {
        final data = doc.data() as Map<String, dynamic>;

        Timestamp? ts;

        if (data["timestamp"] is Timestamp) {
          ts = data["timestamp"] as Timestamp;
        } else if (data["reportedAt"] is Timestamp) {
          ts = data["reportedAt"] as Timestamp;
        }

        if (ts != null) {
          final DateTime date = ts.toDate();
          monthly[date.month - 1]++;
        }
      }

      //---------------- RETURN MODEL ----------------//

      return AnalyticsModel(
        totalReports: totalReports,
        activeDisasters: activeDisasters,
        rescuedPeople: rescuedPeople,
        aiAccuracy: 96.8,
        disasterDistribution: distribution,
        monthlyReports: monthly,
      );
    });
  }
}