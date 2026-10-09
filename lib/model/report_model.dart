import 'package:cloud_firestore/cloud_firestore.dart';


class Report {

  final String id;

  final String imageUrl;

  final String reporterName;

  final String emergencyType;

  final String phoneNumber;

  final String description;

  final double latitude;

  final double longitude;

  final String severity;

  final String status;

  final DateTime reportedAt;



  Report({

    required this.id,

    required this.imageUrl,

    required this.reporterName,

    required this.emergencyType,

    required this.phoneNumber,

    required this.description,

    required this.latitude,

    required this.longitude,

    required this.severity,

    required this.status,

    required this.reportedAt,

  });



  factory Report.fromFirestore(DocumentSnapshot doc) {


    final data =
    doc.data() as Map<String, dynamic>;



    return Report(

      id: doc.id,


      imageUrl:
      data['imageUrl'] ?? "",



      // Supports both old and new fields

      reporterName:
      data['reporterName'] ??
          data['name'] ??
          data['reportedBy'] ??
          "Unknown",



      emergencyType:
      data['emergencyType'] ??
          data['incident_type'] ??
          "Unknown",



      phoneNumber:
      data['phoneNumber'] ??
          data['phone'] ??
          "",



      description:
      data['description'] ??
          "",



      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,

      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,



      severity:
      data['severity'] ??
          data['severity_level'] ??
          "Unknown",



      status:
      data['status'] ??
          "Pending",



      reportedAt:

      data['reportedAt'] != null

          ? (data['reportedAt'] as Timestamp)
          .toDate()


          :

      data['timestamp'] != null

          ? (data['timestamp'] as Timestamp)
          .toDate()


          :

      DateTime.now(),


    );

  }



  String get formattedDate {

    return "${reportedAt.day}/"
        "${reportedAt.month}/"
        "${reportedAt.year}";

  }



  String get formattedTime {

    return "${reportedAt.hour}:"
        "${reportedAt.minute.toString().padLeft(2,'0')}";

  }

}