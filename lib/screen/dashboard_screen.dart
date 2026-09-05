import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/utils/responsive.dart';

import '../model/stat_item.dart';

import '../services/report_service.dart';
import '../services/affected_zone_service.dart';
import '../services/rescue_team_service.dart';
import '../services/shelter_service.dart';
import '../services/citizen_service.dart';

import '../widget/dashboard/analytics_panel.dart';
import '../widget/dashboard/map_panel.dart';
import '../widget/dashboard/recent_reports_table.dart';
import '../widget/dashboard/rescue_team_panel.dart';
import '../widget/dashboard/risk_prediction_panel.dart';
import '../widget/dashboard/stat_card_grid.dart';


class DashboardScreen extends StatelessWidget {

  DashboardScreen({super.key});


  final ReportService _reportService = ReportService();

  final AffectedZoneService _zoneService =
  AffectedZoneService();

  final RescueTeamService _rescueService =
  RescueTeamService();

  final ShelterService _shelterService =
  ShelterService();

  final CitizenService citizenService =
  CitizenService();


  List<StatItem> _buildStats({

    required int totalReports,

    required int activeDisasters,

    required int highRiskAreas,

    required int availableTeams,

    required int availableShelters,

    required int registeredUsers,

  }) {
    return [


      StatItem(

        title: 'Total Disaster Reports',

        value: totalReports.toString(),

        icon: Icons.assignment_rounded,

        color: AppColors.primary,

        trendLabel: 'Live',

        trend: TrendDirection.up,

      ),


      StatItem(

        title: 'Active Disasters',

        value: activeDisasters.toString(),

        icon: Icons.warning_amber_rounded,

        color: AppColors.danger,

        trendLabel: 'Firebase',

        trend: TrendDirection.up,

      ),


      StatItem(

        title: 'High Risk Areas',

        value: highRiskAreas.toString(),

        icon: Icons.location_on_rounded,

        color: AppColors.warning,

        trendLabel: 'Live',

        trend: TrendDirection.flat,

      ),


      StatItem(

        title: 'Active Rescue Teams',

        value: availableTeams.toString(),

        icon: Icons.local_shipping_rounded,

        color: AppColors.info,

        trendLabel: 'Firebase',

        trend: TrendDirection.up,

      ),


      StatItem(

        title: 'Registered Users',

        value: registeredUsers.toString(),

        icon: Icons.groups_rounded,

        color: AppColors.secondary,

        trendLabel: 'Firebase',

        trend: TrendDirection.up,

      ),


      StatItem(

        title: 'Available Shelters',

        value: availableShelters.toString(),

        icon: Icons.home_work_rounded,

        color: AppColors.primaryDark,

        trendLabel: 'Firebase',

        trend: TrendDirection.flat,

      ),


    ];
  }


  @override
  Widget build(BuildContext context) {
    return StreamBuilder(

        stream: _reportService.getReports(),

        builder: (context, reportSnapshot) {
          return StreamBuilder(

            stream: _zoneService.getAffectedZones(),

            builder: (context, zoneSnapshot) {
              return StreamBuilder(

                stream: _shelterService.getShelters(),

                builder: (context, shelterSnapshot) {
                  return StreamBuilder(

                    stream: _rescueService.availableTeams(),

                    builder: (context, teamSnapshot) {
                      return StreamBuilder<int>(

                        stream: citizenService.getCitizenCount(),

                        builder:(context, citizenSnapshot) {
                          // Data
                          final reports = reportSnapshot.data ?? [];

                          final zones = zoneSnapshot.data ?? [];

                          final shelters = shelterSnapshot.data ?? [];

                          final availableTeams = teamSnapshot.data ?? 0;

                          final registeredUsers = citizenSnapshot.data ?? 0;


                          final availableShelters = shelters.length;


                          final totalReports = reports.length;


                          final activeDisasters = reports.where((r) {
                            final status = r.status.toLowerCase();

                            return status != "resolved";
                          }).length;


                          final highRiskAreas = zones.where((z) {
                            final level = z.riskLevel.toLowerCase();

                            return level == "high" ||
                                level == "critical";
                          }).length;


                          final stats = _buildStats(

                            totalReports: totalReports,

                            activeDisasters: activeDisasters,

                            highRiskAreas: highRiskAreas,

                            availableTeams: availableTeams,

                            availableShelters: availableShelters,

                            registeredUsers: registeredUsers,

                          );


                          final compact =
                          Responsive.isCompact(context);


                          return SingleChildScrollView(

                            padding: const EdgeInsets.fromLTRB(
                              20,
                              20,
                              20,
                              40,
                            ),


                            child: Column(

                              crossAxisAlignment:
                              CrossAxisAlignment.start,


                              children: [


                                StatCardGrid(

                                  items: stats,

                                ),


                                const SizedBox(height: 20),


                                compact

                                    ? Column(

                                  children: [


                                    const MapPanel(),


                                    const SizedBox(
                                      height: 14,
                                    ),


                                    RiskPredictionPanel(),


                                    const SizedBox(
                                      height: 14,
                                    ),


                                    RescueTeamPanel(),


                                    const SizedBox(
                                      height: 14,
                                    ),


                                    const RecentReportsTable(),


                                  ],

                                )


                                    : Row(


                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,


                                  children: [


                                    Expanded(

                                      flex: 7,


                                      child: Column(


                                        children: [


                                          const MapPanel(),


                                          const SizedBox(
                                            height: 14,
                                          ),


                                          const RecentReportsTable(),


                                        ],


                                      ),

                                    ),


                                    const SizedBox(
                                      width: 14,
                                    ),


                                    Expanded(

                                      flex: 3,


                                      child: Column(


                                        children: [


                                          RiskPredictionPanel(),


                                          const SizedBox(
                                            height: 14,
                                          ),


                                          RescueTeamPanel(),


                                        ],


                                      ),

                                    ),


                                  ],


                                ),


                                const SizedBox(

                                  height: 20,

                                ),


                                const AnalyticsPanel(),


                              ],


                            ),


                          );
                        },

                      );
                    },

                  );
                },

              );
            },

          );
        });
  }
}