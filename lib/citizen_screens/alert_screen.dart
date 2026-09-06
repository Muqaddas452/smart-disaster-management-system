import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'alert_details_screen.dart';

// ── Alert Model ───────────────────────────────────────────────────────────────
// Yeh model ab "broadcast_alerts" collection ke asal fields se banta hai —
// wahi collection jahan se citizen ko live/real alerts bhejay jaate hain.
class AlertModel {
  final String docId;
  final String disasterType; // e.g. "Flood", "Storm", "Heatwave", "Heavy Rain"
  final String priority;     // "Low" / "Medium" / "High"
  final String targetArea;   // admin ne jo area likha (e.g. "M.B.Din")
  final String message;      // admin ka type kiya hua alert message
  final DateTime createdAt;

  const AlertModel({
    required this.docId,
    required this.disasterType,
    required this.priority,
    required this.targetArea,
    required this.message,
    required this.createdAt,
  });

  // Firestore document ko AlertModel mein convert karta hai
  factory AlertModel.fromFirestore(String id, Map<String, dynamic> data) {
    // createdAt Firestore mein Timestamp type hai, isliye pehle usko check kar k convert kar rahe hain
    final rawCreatedAt = data['createdAt'];
    final DateTime createdAt =
    (rawCreatedAt is Timestamp) ? rawCreatedAt.toDate() : DateTime.now();

    return AlertModel(
      docId: id,
      disasterType: data['disasterType'] ?? 'Unknown',
      priority: data['priority'] ?? 'Medium',
      targetArea: data['targetArea'] ?? '',
      message: data['message'] ?? '',
      createdAt: createdAt,
    );
  }

  // Card aur details screen pe bada title
  String get title {
    switch (disasterType) {
      case "Flood":
        return "Severe Flood Alert";
      case "Storm":
        return "Storm Warning";
      case "Heatwave":
        return "Heatwave Warning";
      case "Heavy Rain": // NOTE: singular rakha hai, admin dashboard k exact spelling se match karna
        return "Heavy Rain Alert";
      default:
        return "$disasterType Alert";
    }
  }

  // Chota description — admin ka apna likha hua message directly dikhate hain
  String get subtitle =>
      message.isNotEmpty ? message : "$disasterType alert in your area.";

  String get formattedTime {
    final now = DateTime.now();
    final isToday = createdAt.year == now.year &&
        createdAt.month == now.month &&
        createdAt.day == now.day;
    final timeStr = DateFormat('h:mm a').format(createdAt);
    return isToday
        ? "Today $timeStr"
        : "${DateFormat('MMM d').format(createdAt)} $timeStr";
  }

  IconData get icon {
    switch (disasterType) {
      case "Flood":
        return Icons.home_outlined;
      case "Storm":
        return Icons.thunderstorm_outlined;
      case "Heatwave":
        return Icons.wb_sunny_outlined;
      case "Heavy Rain":
        return Icons.cloud_outlined;
      default:
        return Icons.warning_amber_outlined;
    }
  }

  Color get iconBg {
    switch (disasterType) {
      case "Flood":
        return const Color(0xFFE53935);
      case "Storm":
        return const Color(0xFF5E35B1);
      case "Heatwave":
        return const Color(0xFFFB8C00);
      case "Heavy Rain":
        return const Color(0xFFFDD835);
      default:
        return const Color(0xFF757575);
    }
  }
}

// Citizen k address aur admin k targetArea ke darmiyan keyword match check karta hai.
// Yeh bilkul wahi logic hai jo home screen k _LiveAlertBanner mein hai —
// taake dono jagah behavior consistent rahe.
bool _hasMatchingKeyword(String targetArea, String citizenAddress) {
  List<String> tokenize(String input) {
    final normalized =
    input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
    return normalized.split(' ').where((w) => w.trim().length >= 3).toList();
  }

  final targetTokens = tokenize(targetArea).toSet();
  final addressTokens = tokenize(citizenAddress).toSet();

  return targetTokens.intersection(addressTokens).isNotEmpty;
}

// ── Alerts Screen ─────────────────────────────────────────────────────────────
class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  static const Color _primaryGreen = Color(0xFF1B5E20);
  static const Color _bgColor = Color(0xFFF0F2F5);

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: _buildAppBar(context),
      body: uid == null
          ? const Center(child: Text("Please log in to see alerts."))
      // Pehle citizen ka address nikal rahe hain, taake targetArea se match kar sakein
          : StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('citizens')
            .doc(uid)
            .snapshots(),
        builder: (context, citizenSnapshot) {
          if (!citizenSnapshot.hasData || !citizenSnapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }

          final citizenData =
          citizenSnapshot.data!.data() as Map<String, dynamic>?;
          final String address = citizenData?['address'] ?? '';

          if (address.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  "Apna address profile mein add karein taake aapko relevant alerts mil sakein.",
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          // Ab asal "broadcast_alerts" collection se Sent alerts nikal rahe hain
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('broadcast_alerts')
                .where('status', isEqualTo: 'Sent')
                .orderBy('createdAt', descending: true)
                .limit(50)
                .snapshots(),
            builder: (context, alertSnapshot) {
              if (alertSnapshot.hasError) {
                return Center(child: Text("Error: ${alertSnapshot.error}"));
              }
              if (!alertSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = alertSnapshot.data!.docs;

              // Sirf wo alerts rakh rahe hain jinka targetArea citizen k address se match ho
              final alerts = docs
                  .map((d) => AlertModel.fromFirestore(
                  d.id, d.data() as Map<String, dynamic>))
                  .where((alert) =>
                  _hasMatchingKeyword(alert.targetArea, address))
                  .toList();

              if (alerts.isEmpty) {
                return const Center(
                    child: Text("No active alerts for your area right now."));
              }

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
                        MaterialPageRoute(
                            builder: (_) => AlertDetailsScreen(alert: alert)),
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