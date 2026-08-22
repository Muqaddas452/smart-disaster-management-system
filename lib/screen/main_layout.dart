import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/responsive.dart';
import '../widget/layout/sidebar_nav.dart';
import '../widget/layout/top_bar.dart';
import 'dashboard_screen.dart';
import 'placeholder_screen.dart';
import 'disaster_monitoring_screen.dart';
import 'live_map_screen.dart';
import 'package:adminpanel_new/screen/reports_screen.dart';
import 'package:adminpanel_new/screen/rescue_team/rescue_team_screen.dart';
import 'package:adminpanel_new/screen/affected_zone/affected_zone_screen.dart';
import '../screen/alerts/alerts_screen.dart';
import '../screen/shelters_resources_screen.dart';
import '../screen/analytics_screen.dart';
import '../screen/settings_screen.dart';
import 'feedback/feedback_screen.dart';
import '../screen/citizens/citizen_management_screen.dart';

// ✅ Simple class instead of Dart records — avoids blank screen on web
class _PageMeta {
  final String title;
  final String subtitle;
  const _PageMeta(this.title, this.subtitle);
}

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  static const List<_PageMeta> _pages = [
    _PageMeta('Dashboard Overview',      'AI-driven situational awareness for active operations'),
    _PageMeta('Disaster Monitoring',     'Continuous AI surveillance of disaster signals'),
    _PageMeta('Live Map',                'Geo-spatial view of all active operations'),
    _PageMeta('User Reports',            'Citizen-submitted incident reports queue'),
    _PageMeta('Rescue Teams',            'Deployment status across all field units'),
    _PageMeta('Citizens',                'Registered citizens management'),
    _PageMeta('Affected Zones',          'Mapped polygons of impacted regions'),
    _PageMeta('Feedback',                'User feedback and ratings'),
    _PageMeta('Alerts & Notifications',  'Outbound public & internal alert log'),
    _PageMeta('Shelters & Resources',    'Capacity and supply tracking'),
    _PageMeta('Analytics',               'Historical trends and performance metrics'),
    _PageMeta('Settings',                'System, user and integration configuration'),
  ];

  Widget _buildPage(int index) {
    switch(index) {


      case 0:
        return DashboardScreen();


      case 1:
        return const DisasterMonitoringScreen();


      case 2:
        return const LiveMapScreen();


      case 3:
        return ReportsScreen();


      case 4:
        return RescueTeamScreen();


      case 5:
        return const CitizenManagementScreen();


      case 6:
        return const AffectedZoneScreen();


      case 7:
        return const FeedbackScreen();


      case 8:
        return const AlertsScreen();


      case 9:
        return SheltersResourcesScreen();


      case 10:
        return AnalyticsScreen();


      case 11:
        return SettingsScreen();

      default:
        return PlaceholderScreen(
          title: _pages[index].title,
          description: _pages[index].subtitle,
          icon: kNavItems[index].icon,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final useDrawer = Responsive.isTablet(context);
    final collapsed  = Responsive.collapsedSidebar(context);
    final meta       = _pages[_selectedIndex];

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: useDrawer
          ? Drawer(
              backgroundColor: Colors.transparent,
              child: SidebarNav(
                selectedIndex: _selectedIndex,
                collapsed: false,
                onSelect: (i) {
                  setState(() => _selectedIndex = i);
                  Navigator.of(context).pop();
                },
              ),
            )
          : null,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Row(
          children: [
            if (!useDrawer)
              SidebarNav(
                selectedIndex: _selectedIndex,
                collapsed: collapsed,
                onSelect: (i) => setState(() => _selectedIndex = i),
              ),
            Expanded(
              child: Column(
                children: [
                  TopBar(
                    title: meta.title,
                    subtitle: meta.subtitle,
                    showMenuButton: useDrawer,
                    onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                  Expanded(
                    child: _buildPage(_selectedIndex),
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
