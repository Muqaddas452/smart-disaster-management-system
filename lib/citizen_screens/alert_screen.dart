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

// ── Helpers ───────────────────────────────────────────────────────────────────

// Firestore mein lat/lng number ya String dono ho sakte hain — safe parse.
// (AlertModel ki lat/lng alert details screen ke liye hain; matching mein
// ab use nahi hoti.)
double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

// Pehli non-empty string wapas karta hai. `??` sirf null check karta hai,
// empty string "" pe agli field pe nahi jata — isliye ye helper.
String _firstNonEmpty(List<dynamic> values) {
  for (final v in values) {
    final s = (v ?? '').toString().trim();
    if (s.isNotEmpty) return s;
  }
  return '';
}

// Text ko normalize: lowercase, symbols hata kar single spaces (Urdu letters
// bhi preserve hote hain).
String _normalize(String input) {
  return input
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\u0600-\u06FF]+'), ' ')
      .trim();
}

// Alert ki city field ko cities mein todta hai (comma, "and", "&", "/" se).
// Har part normalized wapas aata hai.
List<String> _splitCities(String raw) {
  return raw
      .split(RegExp(r',|/|&|\||;|\band\b', caseSensitive: false))
      .map(_normalize)
      .where((s) => s.length >= 3)
      .toList();
}

// Citizen ke address se uski city nikalta hai.
// `candidates` = openweathermap ke saare districts + alerts ki cities.
// Jo candidate address mein POORE naam ke saath SAB SE PEHLE aaye wahi
// citizen ki city hai (address aam taur par chhoti jagah -> bari jagah
// likha hota hai, jaise "Phalia, Mandi Bahauddin").
// Barabar position pe lamba naam jeetta hai ("Dera Ghazi Khan" > "Dera Ghazi").
// Kuch na mile to null.
String? _resolveCitizenCity(String address, Iterable<String> candidates) {
  final paddedAddress = ' ${_normalize(address)} ';
  String? best;
  int bestIndex = -1;

  for (final candidate in candidates) {
    final n = _normalize(candidate);
    if (n.length < 3) continue;
    final idx = paddedAddress.indexOf(' $n ');
    if (idx == -1) continue;
    if (best == null ||
        idx < bestIndex ||
        (idx == bestIndex && n.length > best.length)) {
      best = n;
      bestIndex = idx;
    }
  }
  return best;
}

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
      //convert lat & lon into double from firestore (number ya String dono safe)
      lat: _toDouble(data["lat"] ?? data["latitude"]),
      lng: _toDouble(data["lng"] ?? data["longitude"]),
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

// Citizen ka profile doc + openweathermap ke districts (ek saath load hote hain)
class _ProfileData {
  final DocumentSnapshot doc;
  final List<String> districts;
  const _ProfileData(this.doc, this.districts);
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

  // Districts ki collection ka naam aur us mein field ka naam.
  // Agar tumhari collection/field ka naam alag hai to yahan badlo.
  static const String _districtCollection = 'openweathermap';
  static const String _districtField = 'district';

  bool _isOffline = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  // Profile + districts sirf EK baar load hote hain.
  Future<_ProfileData>? _profileFuture;

  // Matched alerts ka stream bhi EK baar banta hai. Filtering aur offline
  // cache yahin hota hai, build() ke andar nahi.
  Stream<List<AlertModel>>? _alertsStream;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isNotEmpty) {
      _profileFuture = _loadProfileData(uid);
    }
    _initConnectivity();
  }

  Future<_ProfileData> _loadProfileData(String uid) async {
    final doc = await FirebaseFirestore.instance.collection('citizens').doc(uid).get();

    // Districts ki list — fail ho jaye to khali list, tab bhi alerts ki
    // apni cities se matching chalti rahegi.
    List<String> districts = [];
    try {
      final snap = await FirebaseFirestore.instance.collection(_districtCollection).get();
      districts = snap.docs
          .map((d) => (d.data()[_districtField] ?? '').toString().trim())
          .where((s) => s.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('[Alerts] districts load nahi huay: $e');
    }

    return _ProfileData(doc, districts);
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

  // ── MAIN MATCH LOGIC (sirf city) ──────────────────────────────────
  // Alert citizen ke liye hai agar:
  //  1) alert mein city likhi hi nahi  -> sab ke liye
  //  2) alert ki koi bhi city == citizen ki city
  // Citizen ki city na mile (address mein koi known city nahi) to
  // city wale alerts nahi dikhte.
  bool _isAlertForCitizen(AlertModel alert, String? citizenCity) {
    final alertCities = _splitCities(alert.district);
    if (alertCities.isEmpty) return true;
    if (citizenCity == null) return false;
    return alertCities.contains(citizenCity);
  }

  // Alerts ka stream: filter + offline cache har snapshot pe sirf ek baar.
  Stream<List<AlertModel>> _buildAlertsStream({
    required String citizenAddress,
    required List<String> districts,
  }) {
    return FirebaseFirestore.instance
        .collection("broadcast_alerts")
        .orderBy("createdAt", descending: true)
        .snapshots()
        .map((snapshot) {
      final allAlerts = snapshot.docs
          .map((d) => AlertModel.fromFirestore(d.id, d.data() as Map<String, dynamic>))
          .toList();

      // Citizen ki city: districts + alerts ki cities mein se jo address
      // mein sab se pehle aaye.
      final candidates = <String>[...districts];
      for (final a in allAlerts) {
        candidates.addAll(_splitCities(a.district));
      }
      final String? citizenCity = _resolveCitizenCity(citizenAddress, candidates);

      // Debug: console mein dekh sakti ho ke city kya detect hui
      debugPrint('[Alerts] address="$citizenAddress" -> city="$citizenCity"');

      final matchedAlerts =
      allAlerts.where((alert) => _isAlertForCitizen(alert, citizenCity)).toList();

      // Cache silently for offline use — sirf wahi alerts jo is citizen
      // ke liye match hue, taake offline mein bhi sirf uske alerts dikhen.
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

      return matchedAlerts;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: _buildAppBar(context),
      body: _isOffline ? _buildOfflineBody(context) : _buildOnlineBody(context),
    );
  }

  Widget _buildOnlineBody(BuildContext context) {
    final profileFuture = _profileFuture;
    if (profileFuture == null) {
      return const Center(child: Text("User profile not found."));
    }

    return FutureBuilder<_ProfileData>(
      future: profileFuture,
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _primaryGreen));
        }

        if (!userSnapshot.hasData || !userSnapshot.data!.doc.exists) {
          return const Center(child: Text("User profile not found."));
        }

        final profile = userSnapshot.data!;
        var userData = profile.doc.data() as Map<String, dynamic>;

        // Citizen ka address (address, location, ya city field se — jo pehli
        // non-empty ho)
        final String citizenAddress =
        _firstNonEmpty([userData['address'], userData['location'], userData['city']]);

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

        _alertsStream ??= _buildAlertsStream(
          citizenAddress: citizenAddress,
          districts: profile.districts,
        );

        return StreamBuilder<List<AlertModel>>(
          stream: _alertsStream,
          builder: (context, alertSnapshot) {
            if (alertSnapshot.hasError) {
              return Center(child: Text("Error: ${alertSnapshot.error}"));
            }
            if (alertSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: _primaryGreen));
            }

            final matchedAlerts = alertSnapshot.data ?? [];

            if (matchedAlerts.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    "No active alerts for your area ($citizenAddress).",
                    style: const TextStyle(fontSize: 15, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

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

  // Offline: cache mein pehle se sirf is citizen ke matched alerts hain
  // (online pe filter hone ke baad save hue the), isliye yahan dobara
  // filter nahi karte.
  Widget _buildOfflineBody(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: CitizenDao.getCachedAlerts(),
      builder: (context, alertsSnap) {
        if (alertsSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _primaryGreen));
        }

        final cachedRaw = alertsSnap.data ?? [];

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




