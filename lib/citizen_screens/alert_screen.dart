import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'alert_details_screen.dart';

// ── Alert Model ───────────────────────────────────────────────────────────────
// `type` ab backend ke disaster label ke sath match karta hai
// (Flood / Storm / Heatwave / Heavy Rains) — icon/color yahin se decide hote hain.
class AlertModel {
  final String docId;
  final String type; // e.g. "Flood", "Storm", "Heatwave", "Heavy Rains"
  final String risk; // e.g. "Low" / "Medium" / "High"
  final String district;
  final DateTime time;

  const AlertModel({
    required this.docId,
    required this.type,
    required this.risk,
    required this.district,
    required this.time,
  });

  factory AlertModel.fromFirestore(String id, Map<String, dynamic> data) {
    return AlertModel(
      docId: id,
      type: data["disaster"] ?? "Unknown",
      risk: data["risk"] ?? "Low",
      district: data["district"] ?? "",
      time: DateTime.tryParse(data["time"] ?? "") ?? DateTime.now(),
    );
  }

  String get title {
    switch (type) {
      case "Flood":
        return "Severe Flood Alert";
      case "Storm":
        return "Storm Warning";
      case "Heatwave":
        return "Heatwave Warning";
      case "Heavy Rains":
        return "Heavy Rain Alert";
      default:
        return "$type Alert";
    }
  }

  String get subtitle {
    switch (type) {
      case "Flood":
        return "Flooding risk detected in $district. Risk level: $risk.";
      case "Storm":
        return "Storm conditions detected in $district. Risk level: $risk.";
      case "Heatwave":
        return "High temperatures detected in $district. Risk level: $risk.";
      case "Heavy Rains":
        return "Heavy rainfall detected in $district. Risk level: $risk.";
      default:
        return "$district — risk level: $risk.";
    }
  }

  String get formattedTime {
    final now = DateTime.now();
    final isToday = time.year == now.year && time.month == now.month && time.day == now.day;
    final timeStr = DateFormat('h:mm a').format(time);
    return isToday ? "Today $timeStr" : "${DateFormat('MMM d').format(time)} $timeStr";
  }

  IconData get icon {
    switch (type) {
      case "Flood":
        return Icons.home_outlined;
      case "Storm":
        return Icons.thunderstorm_outlined;
      case "Heatwave":
        return Icons.wb_sunny_outlined;
      case "Heavy Rains":
        return Icons.cloud_outlined;
      default:
        return Icons.warning_amber_outlined;
    }
  }

  Color get iconBg {
    switch (type) {
      case "Flood":
        return const Color(0xFFE53935);
      case "Storm":
        return const Color(0xFF5E35B1);
      case "Heatwave":
        return const Color(0xFFFB8C00);
      case "Heavy Rains":
        return const Color(0xFFFDD835);
      default:
        return const Color(0xFF757575);
    }
  }
}

// ── Alerts Screen ─────────────────────────────────────────────────────────────
class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  static const Color _primaryGreen = Color(0xFF1B5E20);
  static const Color _bgColor = Color(0xFFF0F2F5);

  // TODO: is district ko user ke profile/selected-location se dynamically set karein
  static const String _currentDistrict = "Karachi";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: _buildAppBar(context),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("alerts")
            .where("district", isEqualTo: _currentDistrict)
            .where("disaster", isNotEqualTo: "Normal")
            .orderBy("disaster") // Firestore rule: isNotEqualTo ke sath orderBy usi field pe pehle chahiye
            .orderBy("time", descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text("No active alerts right now."));
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
        'Alerts',
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
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
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
                    alert.subtitle,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF616161), height: 1.4),
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
























