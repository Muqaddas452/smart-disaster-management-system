import 'package:flutter/material.dart';
import 'alert_screen.dart';

// ── Alert Details Screen
class AlertDetailsScreen extends StatelessWidget {
  final AlertModel alert;

  const AlertDetailsScreen({super.key, required this.alert});

  static const Color _primaryGreen = Color(0xFF1B5E20);

  // Safety guidelines per alert type
  List<_GuidelineItem> get _guidelines {
    switch (alert.title) {
      case 'Heatwave Warning Today':
        return const [
          _GuidelineItem(
            icon: Icons.water_drop_outlined,
            iconColor: Color(0xFF1E88E5),
            text: 'Stay hydrated and drink water frequently.',
          ),
          _GuidelineItem(
            icon: Icons.do_not_disturb_alt_outlined,
            iconColor: Color(0xFF1E88E5),
            text: 'Do not leave children or pets inside vehicles.',
          ),
        ];
      case 'Severe Flood Alert':
        return const [
          _GuidelineItem(
            icon: Icons.directions_run,
            iconColor: Color(0xFFE53935),
            text: 'Evacuate to higher ground immediately.',
          ),
          _GuidelineItem(
            icon: Icons.power_off_outlined,
            iconColor: Color(0xFFE53935),
            text: 'Turn off electricity and gas before leaving.',
          ),
        ];
      case 'Rescue Team Dispatched':
        return const [
          _GuidelineItem(
            icon: Icons.location_on_outlined,
            iconColor: Color(0xFF43A047),
            text: 'Stay at your location and keep phone charged.',
          ),
          _GuidelineItem(
            icon: Icons.signal_cellular_alt,
            iconColor: Color(0xFF43A047),
            text: 'Keep emergency contacts informed of your status.',
          ),
        ];
      default:
        return const [
          _GuidelineItem(
            icon: Icons.umbrella_outlined,
            iconColor: Color(0xFF1E88E5),
            text: 'Carry an umbrella and wear waterproof gear.',
          ),
          _GuidelineItem(
            icon: Icons.directions_car_outlined,
            iconColor: Color(0xFF1E88E5),
            text: 'Drive carefully on slippery roads tonight.',
          ),
        ];
    }
  }

  String get _detailDescription {
    switch (alert.title) {
      case 'Heatwave Warning Today':
        return 'Extreme temperatures expected today. Avoid direct sunlight, stay indoors, drink plenty of water, and check on elderly people and children.';
      case 'Severe Flood Alert':
        return 'Severe flooding has been reported in your area. Evacuate immediately and follow official city guidelines for high-risk zones.';
      case 'Rescue Team Dispatched':
        return 'A rescue team has been dispatched and is en route to your area. Stay calm and remain at your current location for assistance.';
      default:
        return 'Light to moderate rainfall is forecasted for tonight. Take necessary precautions and stay updated with official weather bulletins.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Large Icon ──
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: alert.iconBg.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
              child: Icon(alert.icon, color: alert.iconBg, size: 54),
            ),

            const SizedBox(height: 20),

            // ── Title ──
            Text(
              alert.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1A1A1A),
              ),
            ),

            const SizedBox(height: 6),

            // ── Date & Time ──
            Text(
              'Date & Time: ${alert.time}',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF9E9E9E),
              ),
            ),

            const SizedBox(height: 20),

            // ── Description Box ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4F8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _detailDescription,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF424242),
                  height: 1.6,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Safety Guidelines ──
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Safety Guidelines',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Guidelines list
            ..._guidelines.map(
                  (g) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: g.iconColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(g.icon, color: g.iconColor, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          g.text,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF424242),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // ── Action Buttons ──
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Call Emergency
                _ActionButton(
                  icon: Icons.phone_rounded,
                  label: 'Call Emergency',
                  color: const Color(0xFF43A047),
                  onTap: () {
                    // TODO: launch phone call — url_launcher package use karo
                    // launchUrl(Uri.parse('tel:1122'));
                  },
                ),
                const SizedBox(width: 40),
                // Find Help Center
                _ActionButton(
                  icon: Icons.location_on_rounded,
                  label: 'Find Help Center',
                  color: const Color(0xFF1E88E5),
                  onTap: () {
                    // TODO: Open map screen
                  },
                ),
              ],
            ),

            const SizedBox(height: 24),
          ],
        ),
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
        'Alert Details',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.ios_share_outlined, color: Colors.white),
          onPressed: () {
            // TODO: Share alert details
          },
        ),
      ],
    );
  }
}

// ── Guideline Item Model ──────────────────────────────────────────────────────
class _GuidelineItem {
  final IconData icon;
  final Color iconColor;
  final String text;
  const _GuidelineItem({
    required this.icon,
    required this.iconColor,
    required this.text,
  });
}

// ── Action Button ─────────────────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }
}