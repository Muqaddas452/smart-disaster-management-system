import 'package:flutter/material.dart';
import 'report_screen.dart';
import 'alert_screen.dart';
import 'widgets/map/disaster_map.dart';
import 'map_screen.dart';

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

  final List<_NavItem> _navItems = const [
    _NavItem(icon: Icons.home_rounded, label: 'Home'),
    _NavItem(icon: Icons.map_outlined, label: 'Map'),
    _NavItem(icon: Icons.upload_rounded, label: 'Report'),
    _NavItem(icon: Icons.notifications_outlined, label: 'Alerts'),
    _NavItem(icon: Icons.person_outline, label: 'Profile'),
  ];
  void _onNavTap(int index) {
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
          builder: (_) => ReporteScreen(),
        ),
      );
      return;
    }

    if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const AlertsScreen(),
        ),
      );
      return;
    }

    // Add your Profile screen here if needed
    if (index == 4) {
      // Navigator.push(...);
      return;
    }

    setState(() => _selectedIndex = index);
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
                  const _AlertBanner(
                    title: 'ALERT: Heatwave Warning in Your Area',
                    subtitle:
                    'Take precautions and stay hydrated. Avoid direct sunlight during peak hours.',
                  ),
                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: _LiveMapCard(),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _SafetyTipsButton(onTap: () {}),
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
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        _ReportCard(
                          title: 'Flood near canal road',
                          subtitle: 'Verified • 2h ago',
                          isVerified: true,
                        ),
                        SizedBox(height: 10),
                        _ReportCard(
                          title: 'Severe Rain & Storm',
                          subtitle: 'Pending Verification • 5h ago',
                          isVerified: false,
                        ),
                      ],
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
                    child: Column(
                      children: [
                        _HelpCenterCard(
                          icon: Icons.local_hospital_outlined,
                          iconColor: AppColors.primary,
                          title: 'Govt Hospital',
                          subtitle: 'Open 24/7 • 1.2 km away',
                          buttonLabel: 'Get Directions',
                          buttonIcon: Icons.navigation_outlined,
                          buttonColor: AppColors.primary,
                          buttonBg: AppColors.divider,
                          onButtonTap: () {},
                        ),
                        const SizedBox(height: 12),
                        _HelpCenterCard(
                          icon: Icons.emergency_outlined,
                          iconColor: AppColors.callRed,
                          title: 'Rescue 1122 Station',
                          subtitle: 'Ready • 0.8 km away',
                          buttonLabel: 'Call Now',
                          buttonIcon: Icons.phone_outlined,
                          buttonColor: AppColors.callRed,
                          buttonBg: AppColors.callRedBg,
                          onButtonTap: () {},
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),

      //  FIXED: onTap: _onNavTap
      bottomNavigationBar: _BottomNav(
        items: _navItems,
        selectedIndex: _selectedIndex,
        onTap: _onNavTap,
      ),
    );
  }
}

// App Top Bar
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

// Alert Banner
class _AlertBanner extends StatelessWidget {
  final String title;
  final String subtitle;

  const _AlertBanner({required this.title, required this.subtitle});

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
              color: AppColors.alertOrange,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.warning_amber_rounded,
                color: AppColors.alertOrange, size: 22),
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

// Live Map Card
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
            child: const SizedBox(
              height: 200,
              width: double.infinity,
              child: DisasterMap(
                isAdmin: false,
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

// Safety Tips Button
class _SafetyTipsButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SafetyTipsButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
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

// Section Header
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

// Report Card
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

// Help Center Card
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

// Bottom Navigation Bar
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
          final isReport = item.label == 'Report';

          return GestureDetector(
            onTap: () => onTap(index),
            behavior: HitTestBehavior.opaque,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isReport)
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(item.icon, color: Colors.white, size: 22),
                  )
                else
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