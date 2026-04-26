import 'package:flutter/material.dart';
import 'alert_details_screen.dart';

// ── Alert Model ───────────────────────────────────────────────────────────────
class AlertModel {
  final String title;
  final String subtitle;
  final String time;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;

  const AlertModel({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
  });
}

// ── Alerts Screen
class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  static const Color _primaryGreen = Color(0xFF1B5E20);
  static const Color _bgColor = Color(0xFFF0F2F5);

  static final List<AlertModel> _alerts = [
    const AlertModel(
      title: 'Severe Flood Alert',
      subtitle: 'Evacuate immediately. Follow official city guidelines for high-risk zones.',
      time: 'Today 10:45 AM',
      icon: Icons.home_outlined,
      iconColor: Colors.white,
      iconBg: Color(0xFFE53935),
    ),
    const AlertModel(
      title: 'Heatwave Warning Today',
      subtitle: 'High temperatures expected. Stay hydrated and avoid sun exposure.',
      time: 'Today 8:20 AM',
      icon: Icons.wb_sunny_outlined,
      iconColor: Colors.white,
      iconBg: Color(0xFFFB8C00),
    ),
    const AlertModel(
      title: 'Rescue Team Dispatched',
      subtitle: 'A rescue team is en route to your area to provide assistance.',
      time: 'Yesterday 6:10 PM',
      icon: Icons.local_shipping_outlined,
      iconColor: Colors.white,
      iconBg: Color(0xFF43A047),
    ),
    const AlertModel(
      title: 'Rain Expected Tonight',
      subtitle: 'Light to moderate rainfall forecasted. Be cautious of slippery roads.',
      time: 'Yesterday 3:00 PM',
      icon: Icons.cloud_outlined,
      iconColor: Colors.white,
      iconBg: Color(0xFFFDD835),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: _buildAppBar(context),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        itemCount: _alerts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final alert = _alerts[index];
          return _AlertCard(
            alert: alert,
            onTap: () {
              // ✅ TRIGGER: Heatwave (index 1) pe tap → AlertDetailsScreen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>AlertDetailsScreen(alert: alert),
                ),
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
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      centerTitle: true,
      actions: [
        Stack(
          alignment: Alignment.topRight,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined,
                  color: Colors.white, size: 26),
              onPressed: () {},
            ),
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    '2',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
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
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon circle
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: alert.iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(alert.icon, color: alert.iconColor, size: 26),
            ),
            const SizedBox(width: 14),
            // Content
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
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        alert.time,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9E9E9E),
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    alert.subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF616161),
                      height: 1.4,
                    ),
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