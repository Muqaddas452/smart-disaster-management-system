import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class NavItem {
  final IconData icon;
  final String label;
  const NavItem(this.icon, this.label);
}

const List<NavItem> kNavItems = [
  NavItem(Icons.dashboard_rounded,             'Dashboard Overview'),
  NavItem(Icons.monitor_heart_rounded,         'Disaster Monitoring'),
  NavItem(Icons.map_rounded,                   'Live Map'),
  NavItem(Icons.fact_check_rounded,            'User Reports'),
  NavItem(Icons.local_shipping_rounded,        'Rescue Teams'),
  NavItem(Icons.people_rounded,                'Citizens'),
  NavItem(Icons.location_city_rounded,         'Affected Zones'),
  NavItem(Icons.feedback,                      "Feedback"),
  NavItem(Icons.notifications_active_rounded,  'Alerts & Notifications'),
  NavItem(Icons.home_work_rounded,             'Shelters & Resources'),
  NavItem(Icons.insights_rounded,              'Analytics'),
  NavItem(Icons.settings_rounded,              'Settings'),
];

class SidebarNav extends StatelessWidget {
  final int selectedIndex;
  final bool collapsed;
  final ValueChanged<int> onSelect;

  const SidebarNav({super.key, required this.selectedIndex, required this.collapsed, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final width = collapsed ? 68.0 : 230.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: width,
      decoration: const BoxDecoration(gradient: AppColors.sidebarGradient),
      child: Column(
        children: [
          const SizedBox(height: 24),
          // Brand
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.crisis_alert_rounded, color: Colors.white, size: 20),
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Admin Dashboard', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                      Text('Console v1.0',  style: TextStyle(color: Color(0xFF81C784), fontSize: 10)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Nav items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: kNavItems.length,
              itemBuilder: (ctx, i) {
                final item = kNavItems[i];
                final selected = i == selectedIndex;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: _NavTile(item: item, selected: selected, collapsed: collapsed, onTap: () => onSelect(i)),
                );
              },
            ),
          ),
          // Footer
          if (!collapsed)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: AppColors.success.withAlpha(40), borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: const [
                    Icon(Icons.circle, size: 8, color: AppColors.success),
                    SizedBox(width: 8),
                    Expanded(child: Text('All systems operational', style: TextStyle(fontSize: 10, color: Color(0xFF81C784)))),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _NavTile extends StatefulWidget {
  final NavItem item;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  const _NavTile({required this.item, required this.selected, required this.collapsed, required this.onTap});

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.selected
        ? AppColors.sidebarSelected.withAlpha(200)
        : _hovered ? Colors.white.withAlpha(20) : Colors.transparent;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(horizontal: widget.collapsed ? 0 : 12, vertical: 10),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
          child: Row(
            mainAxisAlignment: widget.collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Icon(widget.item.icon, size: 20, color: widget.selected ? Colors.white : const Color(0xFFB2DFDB)),
              if (!widget.collapsed) ...[
                const SizedBox(width: 10),
                Expanded(child: Text(widget.item.label, style: TextStyle(fontSize: 12.5, fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w400, color: widget.selected ? Colors.white : const Color(0xFFB2DFDB)))),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
