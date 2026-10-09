import 'package:flutter/material.dart';
import '../../model/report_model.dart';

class ReportStatistics extends StatelessWidget {
  final List<Report> reports;

  const ReportStatistics({
    super.key,
    required this.reports,
  });

  @override
  Widget build(BuildContext context) {
    final total = reports.length;

    final pending =
        reports.where((e) => e.status == "Pending").length;

    final working =
        reports.where((e) => e.status == "In Progress").length;

    final resolved =
        reports.where((e) => e.status == "Resolved").length;

    return Row(
      children: [
        Expanded(
          child: _card(
            "Total Reports",
            total.toString(),
            Colors.blue,
            Icons.assignment,
          ),
        ),

        const SizedBox(width: 15),

        Expanded(
          child: _card(
            "Pending",
            pending.toString(),
            Colors.orange,
            Icons.pending_actions,
          ),
        ),

        const SizedBox(width: 15),

        Expanded(
          child: _card(
            "Working",
            working.toString(),
            Colors.indigo,
            Icons.engineering,
          ),
        ),

        const SizedBox(width: 15),

        Expanded(
          child: _card(
            "Resolved",
            resolved.toString(),
            Colors.green,
            Icons.check_circle,
          ),
        ),
      ],
    );
  }

  Widget _card(
      String title,
      String value,
      Color color,
      IconData icon,
      ) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 25,
          horizontal: 20,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 38,
              color: color,
            ),

            const SizedBox(height: 12),

            Text(
              value,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}