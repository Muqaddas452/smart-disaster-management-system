import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'alert_details_screen.dart';
import 'package:smartdisaster/services/alert_service.dart';
import 'package:smartdisaster/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ── OFFLINE SUPPORT ────────────────────────────────────────────────
// Adjust these two import paths to match where db_helper.dart and
// citizen_dao.dart actually live in your project.
import 'package:smartdisaster/database/db_helper.dart';
import 'package:smartdisaster/database/citizen_dao.dart';

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
      district: data["city"] ?? data["district"] ?? data["targetArea"] ?? "",
      message: data["message"] ?? "Emergency alert issued.",
      title: data["title"] ?? "Emergency Alert",
      time: parsedTime,
      //convert lat & lon into double from firestore
      lat: (data["lat"] ?? data["latitude"])?.toDouble(),
      lng: (data["lng"] ?? data["longitude"])?.toDouble(),
    );
  }

  // ── Rebuild an AlertModel from a row cached via CitizenDao.cacheAlerts()
  // (table: cached_alerts — docId, disasterType, priority, targetArea,
  // message, createdAt). Used only when the app is offline.
  factory AlertModel.fromCache(Map<String, dynamic> data) {
    DateTime parsedTime = DateTime.now();
    final tsField = data["createdAt"];
    if (tsField is String && tsField.isNotEmpty) {
      parsedTime = DateTime.tryParse(tsField) ?? DateTime.now();
    }

    final String type = data["disasterType"] ?? "Unknown";

    return AlertModel(
      docId: data["docId"] ?? "",
      type: type,
      risk: data["priority"] ?? "Low",
      district: data["targetArea"] ?? "",
      message: data["message"] ?? "Emergency alert issued.",
      title: type != "Unknown" ? "$type Alert" : "Emergency Alert",
      time: parsedTime,
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
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  static const Color _primaryGreen = Color(0xFF1B5E20);
  static const Color _bgColor = Color(0xFFF0F2F5);

  bool _isOffline = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    _initConnectivity();
  }

  Future<void> _initConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() => _isOffline = result.contains(ConnectivityResult.none));
    }
    _connectivitySub = Connectivity().onConnectivityChanged.listen((result) {
      if (mounted) {
        setState(() => _isOffline = result.contains(ConnectivityResult.none));
      }
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  // Same tokenize + intersect keyword match used on the home screen's
  // live alert banner — used offline to approximate the online
  // exact-city filter against whatever address is in the cached profile.
  bool _keywordMatch(String targetArea, String citizenAddress) {
    List<String> tokenize(String input) {
      final normalized = input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
      return normalized.split(' ').where((w) => w.trim().length >= 3).toList();
    }

    final targetTokens = tokenize(targetArea).toSet();
    final addressTokens = tokenize(citizenAddress).toSet();
    return targetTokens.intersection(addressTokens).isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: _buildAppBar(context),
      body: _isOffline
          ? _buildOfflineBody(context, currentUserId)
          : _buildOnlineBody(context, currentUserId),
    );
  }

  Widget _buildOnlineBody(BuildContext context, String currentUserId) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('citizens').doc(currentUserId).get(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _primaryGreen));
        }

        if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
          return const Center(child: Text("User profile not found."));
        }

        var userData = userSnapshot.data!.data() as Map<String, dynamic>;

        // Citizen ka poora address nikalna (address, location, ya city field se)
        String citizenAddress = (userData['address'] ?? userData['location'] ?? userData['city'] ?? '').toString().trim();

        if (citizenAddress.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                "Please update your address in your profile to view matching alerts.",
                style: TextStyle(fontSize: 15, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        // Ab hum broadcast_alerts se saare active alerts fetch karenge aur app mein filter karenge
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection("broadcast_alerts")
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
              return const Center(
                child: Text(
                  "No active alerts right now.",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              );
            }

            // All alerts convert to model
            final allAlerts = docs
                .map((d) => AlertModel.fromFirestore(d.id, d.data() as Map<String, dynamic>))
                .toList();

            // KEYWORD MATCH FILTER: Sirf wo alerts filter honge jinka targetArea/city citizen ke poore address se match karega
            final matchedAlerts = allAlerts.where((alert) {
              final targetArea = alert.district; // Alert wala city/district (jaise "Mandi Bahauddin")
              if (targetArea.isEmpty) return true; // Agar alert mein district blank ho to sab ko dikhaye
              return _keywordMatch(targetArea, citizenAddress);
            }).toList();

            if (matchedAlerts.isEmpty) {
              return Center(
                child: Text(
                  "No active alerts for your area ($citizenAddress).",
                  style: const TextStyle(fontSize: 15, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              );
            }

            // Cache silently for offline use
            final cachePayload = matchedAlerts
                .map((a) => {
              'docId': a.docId,
              'disasterType': a.type,
              'priority': a.risk,
              'targetArea': a.district,
              'message': a.message,
              'createdAt': a.time.toIso8601String(),
            })
                .toList();
            CitizenDao.cacheAlerts(cachePayload);

            return ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              itemCount: matchedAlerts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final alert = matchedAlerts[index];
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
    );
  }
  Widget _buildOfflineBody(BuildContext context, String currentUserId) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: CitizenDao.getCachedProfile(currentUserId),
      builder: (context, profileSnap) {
        final cachedAddress = (profileSnap.data?['address'] as String?) ?? '';

        return FutureBuilder<List<Map<String, dynamic>>>(
          future: CitizenDao.getCachedAlerts(),
          builder: (context, alertsSnap) {
            if (alertsSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: _primaryGreen));
            }

            var cachedRaw = alertsSnap.data ?? [];

            // Best-effort match against the citizen's cached address when
            // we have one on file — the cache doesn't store the exact
            // 'city' field the online query filters on.
            if (cachedAddress.isNotEmpty) {
              final filtered = cachedRaw.where((data) {
                final targetArea = (data['targetArea'] as String?) ?? '';
                return targetArea.isEmpty || _keywordMatch(targetArea, cachedAddress);
              }).toList();
              if (filtered.isNotEmpty) cachedRaw = filtered;
            }

            if (cachedRaw.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    "No cached alerts available offline.",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final alerts = cachedRaw.map((d) => AlertModel.fromCache(d)).toList();

            return Column(
              children: [
                Container(
                  width: double.infinity,
                  color: const Color(0xFFFFF3E0),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: const Text(
                    'Offline — showing last saved alerts',
                    style: TextStyle(fontSize: 11, color: Color(0xFFE65100), fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: ListView.separated(
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
                  ),
                ),
              ],
            );
          },
        );
      },
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






