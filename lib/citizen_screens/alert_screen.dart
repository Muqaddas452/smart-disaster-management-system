import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smart_disaster_management_system/database/citizen_dao.dart'; // adjust path if needed
import 'alert_details_screen.dart';

// ── Alert Model ───────────────────────────────────────────────────────────────
// This model is built from the actual fields of the "broadcast_alerts"
// collection — the same collection that sends live/real alerts to citizens.
class AlertModel {
  final String docId;
  final String disasterType; // e.g. "Flood", "Storm", "Heatwave", "Heavy Rain"
  final String priority;     // "Low" / "Medium" / "High"
  final String targetArea;   // area typed by admin (e.g. "M.B.Din")
  final String message;      // alert message typed by admin
  final DateTime createdAt;

  const AlertModel({
    required this.docId,
    required this.disasterType,
    required this.priority,
    required this.targetArea,
    required this.message,
    required this.createdAt,
  });

  // Converts a Firestore document into an AlertModel
  factory AlertModel.fromFirestore(String id, Map<String, dynamic> data) {
    // createdAt is a Firestore Timestamp, so check and convert it first
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

  // NEW — builds an AlertModel from the SQLite cache. In SQLite, createdAt
  // is stored as an ISO8601 string (not a Timestamp), so it needs its own
  // factory — everything else is the same as fromFirestore.
  factory AlertModel.fromCache(Map<String, dynamic> data) {
    final rawCreatedAt = data['createdAt'];
    final DateTime createdAt = (rawCreatedAt is String && rawCreatedAt.isNotEmpty)
        ? (DateTime.tryParse(rawCreatedAt) ?? DateTime.now())
        : DateTime.now();

    return AlertModel(
      docId: data['docId'] ?? '',
      disasterType: data['disasterType'] ?? 'Unknown',
      priority: data['priority'] ?? 'Medium',
      targetArea: data['targetArea'] ?? '',
      message: data['message'] ?? '',
      createdAt: createdAt,
    );
  }

  // Big title shown on the card and the details screen
  String get title {
    switch (disasterType) {
      case "Flood":
        return "Severe Flood Alert";
      case "Storm":
        return "Storm Warning";
      case "Heatwave":
        return "Heatwave Warning";
      case "Heavy Rain": // NOTE: kept singular to match admin dashboard's exact spelling
        return "Heavy Rain Alert";
      default:
        return "$disasterType Alert";
    }
  }

  // Short description — shows the admin's own written message directly
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

// Checks for a keyword match between the admin's targetArea and the
// citizen's address. This is the exact same logic used in the home
// screen's _LiveAlertBanner, so behavior stays consistent everywhere.
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
// UI and filtering logic are exactly the same as before. The only addition:
// alerts are now shown instantly from the SQLite cache (works offline too),
// then silently refreshed + re-cached whenever the live Firestore stream
// has new data.
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  static const Color _primaryGreen = Color(0xFF1B5E20);
  static const Color _bgColor = Color(0xFFF0F2F5);

  String _address = '';
  List<AlertModel> _alerts = [];
  bool _loadedOnce = false;

  StreamSubscription? _citizenSub;
  StreamSubscription? _alertsSub;

  @override
  void initState() {
    super.initState();
    _loadFromCacheThenListen();
  }

  Future<void> _loadFromCacheThenListen() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loadedOnce = true);
      return;
    }

    // 1) Show cache immediately — this works even with zero internet.
    final cachedProfile = await CitizenDao.getCachedProfile(uid);
    final cachedAlerts = await CitizenDao.getCachedAlerts();
    if (cachedProfile != null) {
      _address = cachedProfile['address'] ?? '';
    }
    _recomputeFilteredAlerts(cachedAlerts);
    if (mounted) setState(() => _loadedOnce = true);

    // 2) Citizen's live address (profile updates once internet is back)
    _citizenSub = FirebaseFirestore.instance
        .collection('citizens')
        .doc(uid)
        .snapshots()
        .listen((snap) async {
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>?;
      final address = (data?['address'] ?? '').toString();
      if (address.isEmpty) return;

      _address = address;
      await CitizenDao.cacheProfile(
        uid: uid,
        name: (data?['name'] ?? '').toString(),
        email: (data?['email'] ?? '').toString(),
        phone: (data?['phone'] ?? '').toString(),
        address: address,
        emergencyContactName: (data?['emergencyContactName'] ?? '').toString(),
        emergencyContactPhone: (data?['emergencyContactPhone'] ?? '').toString(),
        emergencyContactRelation:
        (data?['emergencyContactRelation'] ?? '').toString(),
      );

      final freshAlerts = await CitizenDao.getCachedAlerts();
      _recomputeFilteredAlerts(freshAlerts);
    });

    // 3) Live broadcast_alerts — same query as the original StreamBuilder,
    // just now we cache the results and call setState ourselves.
    _alertsSub = FirebaseFirestore.instance
        .collection('broadcast_alerts')
        .where('status', isEqualTo: 'Sent')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .listen((snap) async {
      final alerts = snap.docs.map((d) {
        final data = d.data();
        final createdAt = data['createdAt'];
        return {
          'docId': d.id,
          'disasterType': data['disasterType'] ?? 'Unknown',
          'priority': data['priority'] ?? 'Medium',
          'targetArea': data['targetArea'] ?? '',
          'message': data['message'] ?? '',
          'createdAt': (createdAt is Timestamp)
              ? createdAt.toDate().toIso8601String()
              : DateTime.now().toIso8601String(),
        };
      }).toList();

      await CitizenDao.cacheAlerts(alerts);
      _recomputeFilteredAlerts(alerts);
    }, onError: (_) {
      // Offline — the cached list is already showing, nothing to do here.
    });
  }

  void _recomputeFilteredAlerts(List<Map<String, dynamic>> rawAlerts) {
    final models = rawAlerts.map((d) => AlertModel.fromCache(d)).toList();
    final filtered = _address.isEmpty
        ? <AlertModel>[]
        : models
        .where((alert) => _hasMatchingKeyword(alert.targetArea, _address))
        .toList();
    if (mounted) setState(() => _alerts = filtered);
  }

  @override
  void dispose() {
    _citizenSub?.cancel();
    _alertsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: _buildAppBar(context),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text("Please log in to see alerts."));
    }

    if (!_loadedOnce) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_address.isEmpty) {
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

    if (_alerts.isEmpty) {
      return const Center(
          child: Text("No active alerts for your area right now."));
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: _alerts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final alert = _alerts[index];
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