import 'package:flutter/material.dart';

import '../../model/alert_model.dart';
import '../../services/alert_service.dart';
import '../../widget/alerts/alert_stats.dart';
import '../../widget/alerts/alerts_table.dart';
import '../../widget/alerts/broadcast_alert_dialog.dart';

class AlertsScreen extends StatefulWidget {

  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final TextEditingController _searchController = TextEditingController();

  final AlertService _service = AlertService();

  String search = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search(String value) {
    setState(() {
      search = value;
    });
  }

  void _viewAlert(AlertModel alert) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Alert Details"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("ID : ${alert.id}"),
            Text("Disaster : ${alert.disaster}"),
            Text("Priority : ${alert.priority}"),
            Text("Area : ${alert.area}"),
            Text("Status : ${alert.status}"),
            const SizedBox(height: 10),
            const Text(
              "Message",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(alert.message),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Future<void> _editAlert(AlertModel alert) async {
    await showDialog(
      context: context,
      builder: (_) => BroadcastAlertDialog(
        alert: alert,
      ),
    );
  }

  Future<void> _deleteAlert(AlertModel alert) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Alert"),
        content: const Text(
          "Are you sure you want to delete this alert?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _service.deleteAlert(alert.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Alert deleted successfully"),
          ),
        );
      }
    }
  }
  Future<void> _openBroadcastDialog() async {
    await showDialog(
      context: context,
      builder: (_) => const BroadcastAlertDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AlertModel>>(
        stream: _service.getAlerts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error: ${snapshot.error}",
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: Text("No Alerts Found"),
            );
          }

          final alerts = snapshot.data!;

          final filteredAlerts = alerts.where((alert) {
            return alert.disaster
                .toLowerCase()
                .contains(search.toLowerCase()) ||
                alert.area
                    .toLowerCase()
                    .contains(search.toLowerCase()) ||
                alert.priority
                    .toLowerCase()
                    .contains(search.toLowerCase()) ||
                alert.status
                    .toLowerCase()
                    .contains(search.toLowerCase());
          }).toList();

          return Container(
              color: const Color(0xffF4F7F6),
              child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [                Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Alerts & Notifications",
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _openBroadcastDialog,
                            icon: const Icon(Icons.campaign),
                            label: const Text("Broadcast Alert"),
                          ),
                        ],
                      ),

                        const SizedBox(height: 25),

                        TextField(
                          controller: _searchController,
                          onChanged: _search,
                          decoration: InputDecoration(
                            hintText:
                            "Search by Disaster, Area, Priority or Status",
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),

                        const SizedBox(height: 30),

                        AlertStats(
                          alerts: alerts,
                        ),
                        const SizedBox(height: 30),

                        const Text(
                          "Recent Alerts",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 15),

                        AlertsTable(
                          alerts: filteredAlerts,
                          onView: _viewAlert,
                          onEdit: _editAlert,
                          onDelete: _deleteAlert,
                        ),
                      ],
                  ),
              ),
          );
        },
    );
  }
}