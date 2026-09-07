import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'alert_details_screen.dart';
import 'services/alert_service.dart';
import 'auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ── Alert Model for Broadcast Alerts ──────────────────────────────────────────
class AlertModel {
  final String docId;
  final String type; // e.g. "Heatwave", "Flood"
  final String risk; // e.g. "Medium", "High"
  final String district; // e.g. "Sibi" and "mandi bhaudin"
  final String message;
  final String title;
  final DateTime time;
  final double? lat;
  final double? lng;

  const AlertModel({
    required this.docId,
    required this.type,
    required this.risk,
    required this.district,
    required this.message,
    required this.title,
    required this.time,
    this.lat,
    this.lng,
  });

  factory AlertModel.fromFirestore(String id, Map<String, dynamic> data) {
    // Firestore ke time field ko handle karne ke liye
    DateTime parsedTime = DateTime.now();
    var timeField = data["time"] ?? data["createdAt"];
    if (timeField is Timestamp) {
      parsedTime = timeField.toDate();
    } else if (timeField is String) {
      parsedTime = DateTime.tryParse(timeField) ?? DateTime.now();
    }

    return AlertModel(
      docId: id,
      type: data["disaster"] ?? data["disasterType"] ?? "Unknown",
      risk: data["risk"] ?? data["priority"] ?? "Low",
      district: data["district"] ?? data["targetArea"] ?? "",
      message: data["message"] ?? "Emergency alert issued.",
      title: data["title"] ?? "Emergency Alert",
      time: parsedTime,
      //convert lat & lon into double from firestore
      lat: (data["lat"] ?? data["latitude"])?.toDouble(),
      lng: (data["lng"] ?? data["longitude"])?.toDouble(),
    );
  }
   String get subtitle {
    if (message.isNotEmpty && message != "Emergency alert issued.") {
      return message;
    }
    return "$type risk detected in $district. Risk level: $risk.";
   }

  String get formattedTime {
    final now = DateTime.now();
    final isToday = time.year == now.year && time.month == now.month && time.day == now.day;
    final timeStr = DateFormat('h:mm a').format(time);
    return isToday ? "Today $timeStr" : "${DateFormat('MMM d').format(time)} $timeStr";
  }

  IconData get icon {
    String lowerType = type.toLowerCase();
    if (lowerType.contains("flood")) return Icons.home_outlined;
    if (lowerType.contains("storm")) return Icons.thunderstorm_outlined;
    if (lowerType.contains("heatwave")) return Icons.wb_sunny_outlined;
    if (lowerType.contains("rain")) return Icons.cloud_outlined;
    return Icons.warning_amber_outlined;
  }

  Color get iconBg {
    String lowerRisk = risk.toLowerCase();
    if (lowerRisk.contains("high") || lowerRisk.contains("severe")) {
      return const Color(0xFFE53935); // Red for High risk
    } else if (lowerRisk.contains("medium")) {
      return const Color(0xFFFB8C00); // Orange for Medium risk
    }
    return const Color(0xFF1B5E20); // Green for Low risk
  }
}

// ── Alerts Screen ─────────────────────────────────────────────────────────────
class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  static const Color _primaryGreen = Color(0xFF1B5E20);
  static const Color _bgColor = Color(0xFFF0F2F5);

  @override
  Widget build(BuildContext context) {
    String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: _buildAppBar(context),
      // Pehle user ka document check karein ge ke uska city kya save hai
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('citizens').doc(currentUserId).get(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _primaryGreen));
          }

          if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
            return const Center(child: Text("User profile not found."));
          }

          // User ke document se city nikalna (Aapke database mein field ka naam 'city' ya 'district' ho sakta hai)
          var userData = userSnapshot.data!.data() as Map<String, dynamic>;
          String userCity = userData['city'] ?? userData['district'] ?? 'Phalia';

          // Ab us userCity ke mutabiq broadcast_alerts ko stream karein
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection("broadcast_alerts")
                .where("city", isEqualTo: userCity) // Sirf user ke shehar ke alerts
                .orderBy("createdAt", descending: true)
                .snapshots(),
            builder: (context, alertSnapshot) {
              if (alertSnapshot.hasError) {
                return Center(child: Text("Error: ${alertSnapshot.error}"));
              }
              if (alertSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: _primaryGreen));
              }

              final docs = alertSnapshot.data!.docs;
              if (docs.isEmpty) {
                return Center(
                  child: Text(
                    "No active alerts for $userCity right now.",
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                );
              }

              final alerts = docs
                  .map((d) => AlertModel.fromFirestore(d.id, d.data() as Map<String, dynamic>))
                  .toList();

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                itemCount: alerts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final alert = alerts[index];
                  return _AlertCard(
                    alert: alert,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => AlertDetailsScreen(alert: alert)),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: _primaryGreen,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Emergency Alerts',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
      ),
      centerTitle: true,
    );
  }
}


// ── Alert Card ────────────────────────────────────────────────────────────────
class _AlertCard extends StatelessWidget {
  final AlertModel alert;
  final VoidCallback onTap;

  const _AlertCard({required this.alert, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: alert.iconBg, shape: BoxShape.circle),
              child: Icon(alert.icon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          alert.title,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        alert.formattedTime,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF9E9E9E)),
                        textAlign: TextAlign.right,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    alert.message,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF616161), height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}




















