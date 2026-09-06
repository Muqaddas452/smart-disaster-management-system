import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geolocator/geolocator.dart';

import 'package:smart_disaster_management_system/citizen_screens/safety_tips_screen.dart';
import '../../citizen_screens/report_screen.dart';
import 'alert_screen.dart';
import 'map_screen.dart';
import 'view_citizen_profile_screen.dart';

class AppColors {
  static const Color primary = Color(0xFF1B5E20);
  static const Color primaryLight = Color(0xFF2E7D32);
  static const Color background = Color(0xFFF7F7F7);
  static const Color white = Color(0xFFFFFFFF);
  static const Color alertOrange = Color(0xFFE65100);
  static const Color alertOrangeBg = Color(0xFFFFF3E0);
  static const Color verified = Color(0xFF2E7D32);
  static const Color pending = Color(0xFFE65100);
  static const Color redLive = Color(0xFFE53935);
  static const Color textDark = Color(0xFF1A1A1A);
  static const Color textGrey = Color(0xFF757575);
  static const Color divider = Color(0xFFEEEEEE);
  static const Color callRed = Color(0xFFD32F2F);
  static const Color callRedBg = Color(0xFFFFEBEE);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  double? _userLat;
  double? _userLng;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _saveFcmToken();
  }

  Future<void> _saveFcmToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      FirebaseMessaging messaging = FirebaseMessaging.instance;

      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {

        String? token = await messaging.getToken();

        if (token != null) {
          debugPrint("============== FCM TOKEN GENERATED ==============");
          debugPrint(token);
          debugPrint("===============================================");

          await FirebaseFirestore.instance
              .collection('citizens')
              .doc(user.uid)
              .set({'fcmToken': token}, SetOptions(merge: true));
        }
      }
    } catch (e) {
      debugPrint("Error generating FCM token: $e");
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );

      if (mounted) {
        setState(() {
          _userLat = position.latitude;
          _userLng = position.longitude;
        });
      }

      // Save this location to the logged-in user's citizens document.
      // This covers users who completed their profile before location capture existed,
      // and also keeps the location fresh every time they open the Home screen.
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('citizens').doc(user.uid).set({
          'latitude': position.latitude,
          'longitude': position.longitude,
          'locationUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)); // merge: true so we don't overwrite name/address/phone etc.
      }
    } catch (e) {
      // ignore
    }
  }

  final List<_NavItem> _navItems = const [
    _NavItem(icon: Icons.home_rounded, label: 'Home'),
    _NavItem(icon: Icons.map_outlined, label: 'Map'),
    _NavItem(icon: Icons.upload_rounded, label: 'Report'),
    _NavItem(icon: Icons.notifications_outlined, label: 'Alerts'),
    _NavItem(icon: Icons.person_outline, label: 'Profile'),
  ];

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  void _onNavTap(int index) {
    setState(() => _selectedIndex = index);

    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const MapScreen(),
        ),
      );
      return;
    }
    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const ReportScreen(),
        ),
      );
      return;
    }
    if (index == 3) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const AlertsScreen()));
      return;
    }
    if (index == 4) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const ViewProfileScreen(),
        ),
      );
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const _AppTopBar(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _LiveAlertBanner(),
                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: _LiveMapCard(),
                  ),
                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: _SafetyTipsButton(),
                  ),
                  const SizedBox(height: 20),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: _SectionHeader(
                      title: 'My Reports Status',
                      actionText: 'View All',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('manual_reports')
                          .where('reportedBy',
                          isEqualTo:
                          FirebaseAuth.instance.currentUser?.uid)
                          .orderBy('timestamp', descending: true)
                          .limit(3)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                                child: CircularProgressIndicator(
                                    strokeWidth: 2)),
                          );
                        }

                        if (snapshot.hasError) {
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Reports error: ${snapshot.error}',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.red),
                            ),
                          );
                        }

                        final docs = snapshot.data?.docs ?? [];

                        if (docs.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 6,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: const Text(
                              'No reports submitted yet.',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.textGrey),
                            ),
                          );
                        }

                        return Column(
                          children: docs.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;

                            final String description =
                                data['description'] ?? 'Emergency Report';
                            final String status = data['status'] ?? 'Pending';
                            final bool isVerified =
                            status.toLowerCase().contains('verified');

                            final Timestamp? ts = data['timestamp'];
                            final String timeAgo =
                            ts != null ? _timeAgo(ts.toDate()) : '';

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _ReportCard(
                                title: description.length > 40
                                    ? '${description.substring(0, 40)}...'
                                    : description,
                                subtitle: '$status${timeAgo.isNotEmpty ? ' • $timeAgo' : ''}',
                                isVerified: isVerified,
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: _SectionHeader(title: 'Nearest Help Centers'),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('shelters')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                                child: CircularProgressIndicator(
                                    strokeWidth: 2)),
                          );
                        }

                        if (snapshot.hasError) {
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Unable to load help centers right now.',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.textGrey),
                            ),
                          );
                        }

                        final docs = snapshot.data?.docs ?? [];

                        if (docs.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'No help centers available.',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.textGrey),
                            ),
                          );
                        }

                        final List<Map<String, dynamic>> sheltersList =
                        docs.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final double lat = (data['lat'] ?? 0).toDouble();
                          final double lng = (data['lng'] ?? 0).toDouble();

                          double? distanceKm;
                          if (_userLat != null && _userLng != null) {
                            final meters = Geolocator.distanceBetween(
                                _userLat!, _userLng!, lat, lng);
                            distanceKm = meters / 1000;
                          }

                          return {
                            'name': data['name'] ?? 'Help Center',
                            'type': data['type'] ?? 'shelter',
                            'location': data['location'] ?? '',
                            'capacity': (data['capacity'] ?? 0) as int,
                            'occupied': (data['occupied'] ?? 0) as int,
                            'lat': lat,
                            'lng': lng,
                            'distanceKm': distanceKm,
                          };
                        }).toList();

                        if (_userLat != null && _userLng != null) {
                          sheltersList.sort((a, b) {
                            final da = a['distanceKm'] as double?;
                            final db = b['distanceKm'] as double?;
                            if (da == null || db == null) return 0;
                            return da.compareTo(db);
                          });
                        }

                        final nearest = sheltersList.take(2).toList();

                        if (nearest.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'No help centers found nearby.',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.textGrey),
                            ),
                          );
                        }

                        return Column(
                          children: nearest.map((shelter) {
                            final String type = shelter['type'];
                            final double? distanceKm = shelter['distanceKm'];

                            IconData icon;
                            Color color;
                            if (type == 'hospital') {
                              icon = Icons.local_hospital_outlined;
                              color = AppColors.primary;
                            } else if (type == 'rescue_station' ||
                                type == 'rescue') {
                              icon = Icons.emergency_outlined;
                              color = AppColors.callRed;
                            } else {
                              icon = Icons.holiday_village_outlined;
                              color = AppColors.primary;
                            }

                            final String distanceText = distanceKm != null
                                ? '${distanceKm.toStringAsFixed(1)} km away'
                                : (shelter['location'] ?? '');

                            final int capacity = shelter['capacity'] ?? 0;
                            final int occupied = shelter['occupied'] ?? 0;
                            final int available =
                            (capacity - occupied).clamp(0, capacity);
                            final String subtitle = available > 0
                                ? '$distanceText • $available/$capacity spots available'
                                : '$distanceText • Full';

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _HelpCenterCard(
                                icon: icon,
                                iconColor: color,
                                title: shelter['name'],
                                subtitle: subtitle,
                                buttonLabel: 'Get Directions',
                                buttonIcon: Icons.navigation_outlined,
                                buttonColor: color,
                                buttonBg: AppColors.divider,
                                onButtonTap: () {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Location: ${shelter['lat']}, ${shelter['lng']}'),
                                    ),
                                  );
                                },
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        items: _navItems,
        selectedIndex: _selectedIndex,
        onTap: _onNavTap,
      ),
    );
  }
}

class _AppTopBar extends StatelessWidget {
  const _AppTopBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 14,
        left: 16,
        right: 16,
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.security, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Text(
            'Smart Disaster Management System',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveAlertBanner extends StatelessWidget {
  const _LiveAlertBanner();

  bool _hasMatchingKeyword(String targetArea, String citizenAddress) {
    List<String> tokenize(String input) {
      final normalized =
      input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
      return normalized
          .split(' ')
          .where((w) => w.trim().length >= 3)
          .toList();
    }

    final targetTokens = tokenize(targetArea).toSet();
    final addressTokens = tokenize(citizenAddress).toSet();

    return targetTokens.intersection(addressTokens).isNotEmpty;
  }

  Color _priorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return AppColors.callRed;
      case 'low':
        return AppColors.primaryLight;
      default:
        return AppColors.alertOrange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream:
      FirebaseFirestore.instance.collection('citizens').doc(uid).snapshots(),
      builder: (context, citizenSnapshot) {
        if (!citizenSnapshot.hasData || !citizenSnapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final citizenData =
        citizenSnapshot.data!.data() as Map<String, dynamic>?;
        final String address = citizenData?['address'] ?? '';

        if (address.isEmpty) return const SizedBox.shrink();

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('broadcast_alerts')
              .where('status', isEqualTo: 'Sent')
              .orderBy('createdAt', descending: true)
              .limit(15)
              .snapshots(),
          builder: (context, alertSnapshot) {
            if (!alertSnapshot.hasData || alertSnapshot.data!.docs.isEmpty) {
              return const SizedBox.shrink();
            }

            Map<String, dynamic>? matchedAlert;
            for (final doc in alertSnapshot.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              final String targetArea = data['targetArea'] ?? '';
              if (targetArea.isNotEmpty &&
                  _hasMatchingKeyword(targetArea, address)) {
                matchedAlert = data;
                break;
              }
            }

            if (matchedAlert == null) return const SizedBox.shrink();

            final String disasterType =
                matchedAlert['disasterType'] ?? 'Alert';
            final String message = matchedAlert['message'] ?? '';
            final String priority = matchedAlert['priority'] ?? 'Medium';

            return _AlertBanner(
              title: 'ALERT: $disasterType in Your Area',
              subtitle: message,
              color: _priorityColor(priority),
            );
          },
        );
      },
    );
  }
}

class _AlertBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;

  const _AlertBanner({
    required this.title,
    required this.subtitle,
    this.color = AppColors.alertOrange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 52,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.warning_amber_rounded,
                color: color, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textGrey, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveMapCard extends StatelessWidget {
  const _LiveMapCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Live Disaster Map',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark)),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                          color: AppColors.redLive, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 5),
                    const Text('LIVE',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.redLive)),
                  ],
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
            child: Container(
              height: 200,
              width: double.infinity,
              color: const Color(0xFFD9E8D9),
              child: Stack(
                children: [
                  CustomPaint(
                    size: const Size(double.infinity, 200),
                    painter: _FakeMapPainter(),
                  ),
                  ..._mapPins.map((pin) => _MapPin(pin: pin)),
                  Positioned(
                    right: 10,
                    bottom: 40,
                    child: Column(
                      children: [
                        _MapZoomBtn(icon: Icons.add),
                        const SizedBox(height: 4),
                        _MapZoomBtn(icon: Icons.remove),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const List<_PinData> _mapPins = [
  _PinData('Islamabad', 0.55, 0.18),
  _PinData('Peshawar', 0.46, 0.28),
  _PinData('Lahore', 0.68, 0.32),
  _PinData('Quetta', 0.30, 0.52),
  _PinData('Karachi', 0.26, 0.72),
];

class _PinData {
  final String city;
  final double dx;
  final double dy;
  const _PinData(this.city, this.dx, this.dy);
}

class _MapPin extends StatelessWidget {
  final _PinData pin;
  const _MapPin({required this.pin});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Positioned(
          left: constraints.maxWidth * pin.dx,
          top: 200 * pin.dy,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 3)
                  ],
                ),
                child: Text(pin.city,
                    style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark)),
              ),
              const Icon(Icons.location_on,
                  color: AppColors.primary, size: 20),
            ],
          ),
        );
      },
    );
  }
}

class _MapZoomBtn extends StatelessWidget {
  final IconData icon;
  const _MapZoomBtn({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.15), blurRadius: 3)
        ],
      ),
      child: Icon(icon, size: 16, color: AppColors.textDark),
    );
  }
}

class _FakeMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFB2DFDB).withValues(alpha: 0.5)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(size.width * 0.1, size.height * 0.4)
      ..quadraticBezierTo(size.width * 0.4, size.height * 0.6,
          size.width * 0.7, size.height * 0.5)
      ..quadraticBezierTo(size.width * 0.85, size.height * 0.45,
          size.width, size.height * 0.55);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _SafetyTipsButton extends StatelessWidget {
  const _SafetyTipsButton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SafetyTipsScreen()),
          );
        },
        icon: const Icon(Icons.shield_outlined, size: 20),
        label: const Text('View Critical Safety Tips',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 1,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionText;

  const _SectionHeader({required this.title, this.actionText});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark)),
        if (actionText != null)
          Text(actionText!,
              style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.primaryLight,
                  fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isVerified;

  const _ReportCard({
    required this.title,
    required this.subtitle,
    required this.isVerified,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isVerified
                  ? AppColors.verified.withValues(alpha: 0.1)
                  : AppColors.pending.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isVerified
                  ? Icons.check_circle_outline
                  : Icons.pending_outlined,
              color: isVerified ? AppColors.verified : AppColors.pending,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textGrey)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right,
              color: AppColors.textGrey, size: 20),
        ],
      ),
    );
  }
}

class _HelpCenterCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final IconData buttonIcon;
  final Color buttonColor;
  final Color buttonBg;
  final VoidCallback onButtonTap;

  const _HelpCenterCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.buttonIcon,
    required this.buttonColor,
    required this.buttonBg,
    required this.onButtonTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textGrey)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: onButtonTap,
              icon: Icon(buttonIcon, size: 16, color: buttonColor),
              label: Text(buttonLabel,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: buttonColor)),
              style: TextButton.styleFrom(
                backgroundColor: buttonBg,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

class _BottomNav extends StatelessWidget {
  final List<_NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({
    required this.items,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.divider, width: 1)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 4,
        top: 8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (index) {
          final item = items[index];
          final isSelected = index == selectedIndex;

          return GestureDetector(
            onTap: () => onTap(index),
            behavior: HitTestBehavior.opaque,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item.icon,
                    size: 24,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textGrey),
                const SizedBox(height: 4),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w400,
                    color:
                    isSelected ? AppColors.primary : AppColors.textGrey,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}