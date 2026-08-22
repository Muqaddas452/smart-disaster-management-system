import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../model/report_model.dart';
import '../../services/report_service.dart';

import '../common/glass_card.dart';
import '../common/section_header.dart';
import '../common/status_badge.dart';

class RecentReportsTable extends StatelessWidget {
  const RecentReportsTable({super.key});

  Color _severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case "critical":
        return Colors.red;
      case "high":
        return Colors.orange;
      case "medium":
        return Colors.amber;
      case "low":
        return Colors.green;
      default:
        return Colors.blueGrey;
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case "resolved":
        return Colors.green;
      case "completed":
        return Colors.green;
      case "pending":
        return Colors.orange;
      case "in progress":
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _emergencyIcon(String type) {
    switch (type.toLowerCase()) {
      case "flood":
        return Icons.water;
      case "earthquake":
        return Icons.vibration;
      case "fire":
        return Icons.local_fire_department;
      case "landslide":
        return Icons.landslide;
      case "cyclone":
        return Icons.cyclone;
      default:
        return Icons.warning_amber_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportService = ReportService();

    return StreamBuilder<List<Report>>(
      stream: reportService.getReports(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const GlassCard(
            hoverable: false,
            child: SizedBox(
              height: 300,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return GlassCard(
            hoverable: false,
            child: SizedBox(
              height: 300,
              child: Center(
                child: Text(
                  "Something went wrong",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ),
          );
        }

        final reports = (snapshot.data ?? []).take(5).toList();
        final fmt = DateFormat("MMM d, HH:mm");

        return GlassCard(
          hoverable: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                icon: Icons.assignment_rounded,
                title: "Recent Disaster Reports",
                subtitle: "${reports.length} active records",
                trailing: TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(
                    Icons.open_in_new_rounded,
                    size: 14,
                  ),
                  label: const Text("View All"),
                ),
              ),

              const SizedBox(height: 16),

              if (reports.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(
                    child: Text("No reports available"),
                  ),
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor:
                    WidgetStateProperty.all(AppColors.surfaceMuted),

                    headingTextStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),

                    dataRowColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.hovered)
                          ? AppColors.surfaceMuted
                          : null,
                    ),

                    columnSpacing: 20,

                    columns: const [
                      DataColumn(label: Text("Reporter")),
                      DataColumn(label: Text("Emergency")),
                      DataColumn(label: Text("Phone")),
                      DataColumn(label: Text("Severity")),
                      DataColumn(label: Text("Status")),
                      DataColumn(label: Text("Reported")),
                      DataColumn(label: Text("Actions")),
                    ],

                    rows: reports.map((report) {
                      return DataRow(
                        cells: [
                          DataCell(
                            Text(
                              report.reporterName,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),

                          DataCell(
                            Row(
                              children: [
                                Icon(
                                  _emergencyIcon(report.emergencyType),
                                  size: 16,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  report.emergencyType,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),

                          DataCell(
                            Text(
                              report.phoneNumber,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),

                          DataCell(
                            StatusBadge(
                              label: report.severity,
                              color: _severityColor(report.severity),
                            ),
                          ),

                          DataCell(
                            StatusBadge(
                              label: report.status,
                              color: _statusColor(report.status),
                            ),
                          ),

                          DataCell(
                            Text(
                              fmt.format(report.reportedAt),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),

                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: "View",
                                  onPressed: () {},
                                  icon: const Icon(
                                    Icons.visibility_outlined,
                                    size: 16,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 28,
                                    minHeight: 28,
                                  ),
                                ),
                                IconButton(
                                  tooltip: "Edit",
                                  onPressed: () {},
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 16,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 28,
                                    minHeight: 28,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}