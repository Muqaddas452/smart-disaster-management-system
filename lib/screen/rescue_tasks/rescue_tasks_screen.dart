import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../services/rescue_task_service.dart';
import '../../widget/rescue_task_widgets.dart';

class RescueTasksScreen extends StatefulWidget {
  const RescueTasksScreen({super.key});

  @override
  State<RescueTasksScreen> createState() => _RescueTasksScreenState();
}

class _RescueTasksScreenState extends State<RescueTasksScreen> {
  final RescueTaskService _taskService = RescueTaskService();

  final TextEditingController _searchController =
  TextEditingController();

  String _selectedFilter = 'All';
  String _searchText = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // FIRESTORE STREAMS
  // ============================================================

  Stream<QuerySnapshot<Map<String, dynamic>>> _tasksStream() =>
      _taskService.tasksStream();

  Stream<QuerySnapshot<Map<String, dynamic>>> _reportsStream() =>
      _taskService.reportsStream();

  Stream<QuerySnapshot<Map<String, dynamic>>> _teamsStream() =>
      _taskService.teamsStream();

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _tasksStream(),
      builder: (context, taskSnapshot) {
        if (taskSnapshot.hasError) {
          return _errorView(taskSnapshot.error.toString());
        }

        if (taskSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final tasks = taskSnapshot.data?.docs ?? [];

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _reportsStream(),
          builder: (context, reportSnapshot) {
            if (reportSnapshot.hasError) {
              return _errorView(reportSnapshot.error.toString());
            }

            if (reportSnapshot.connectionState ==
                ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final reports = reportSnapshot.data?.docs ?? [];

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _teamsStream(),
              builder: (context, teamSnapshot) {
                if (teamSnapshot.hasError) {
                  return _errorView(teamSnapshot.error.toString());
                }

                if (teamSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final teams = teamSnapshot.data?.docs ?? [];

                return _buildScreen(tasks, reports, teams);
              },
            );
          },
        );
      },
    );
  }

  // ============================================================
  // MAIN SCREEN
  // ============================================================

  Widget _buildScreen(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> tasks,
      List<QueryDocumentSnapshot<Map<String, dynamic>>> reports,
      List<QueryDocumentSnapshot<Map<String, dynamic>>> teams,
      ) {
    final filteredTasks = tasks.where((doc) {
      final data = doc.data();

      final status =
      (data['status'] ?? 'dispatched').toString().toLowerCase();

      final text = '${data['taskId'] ?? doc.id} '
          '${data['emergencyType'] ?? data['type'] ?? ''} '
          '${data['location'] ?? ''} '
          '${data['address'] ?? ''} '
          '${data['city'] ?? ''} '
          '${data['leaderName'] ?? ''} '
          '${data['teamName'] ?? ''} '
          '${data['sourceType'] ?? ''}'
          .toLowerCase();

      final matchesSearch = _searchText.isEmpty ||
          text.contains(_searchText.toLowerCase());

      bool matchesFilter = true;

      if (_selectedFilter == 'New') {
        matchesFilter = status == 'dispatched';
      } else if (_selectedFilter == 'Assigned') {
        matchesFilter = status == 'assigned';
      } else if (_selectedFilter == 'Active') {
        matchesFilter = status == 'accepted' ||
            status == 'enroute' ||
            status == 'in_progress';
      } else if (_selectedFilter == 'Completed') {
        matchesFilter = status == 'resolved';
      }

      return matchesSearch && matchesFilter;
    }).toList();

    final newCount = tasks.where((doc) {
      final status =
      (doc.data()['status'] ?? '').toString().toLowerCase();
      return status == 'dispatched';
    }).length;

    final assignedCount = tasks.where((doc) {
      return (doc.data()['status'] ?? '').toString().toLowerCase() ==
          'assigned';
    }).length;

    final activeCount = tasks.where((doc) {
      final status =
      (doc.data()['status'] ?? '').toString().toLowerCase();
      return ['accepted', 'enroute', 'in_progress'].contains(status);
    }).length;

    final completedCount = tasks.where((doc) {
      return (doc.data()['status'] ?? '').toString().toLowerCase() ==
          'resolved';
    }).length;

    final assignedReportIds = tasks
        .map((doc) => doc.data()['reportId']?.toString())
        .where((id) => id != null && id.isNotEmpty)
        .cast<String>()
        .toSet();

    final pendingReports = reports.where((report) {
      final data = report.data();

      final taskId = data['taskId']?.toString() ?? '';
      final status = data['status']?.toString().toLowerCase() ?? '';

      final hasTask = taskId.isNotEmpty ||
          assignedReportIds.contains(report.id);

      final resolved = status == 'resolved' || status == 'completed';

      return !hasTask && !resolved;
    }).toList();

    // Background now matches Rescue Teams (Colors.grey.shade100).
    return Container(
      color: Colors.grey.shade100,
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                _buildStats(
                  newCount,
                  assignedCount,
                  activeCount,
                  completedCount,
                ),
                if (pendingReports.isNotEmpty)
                  _buildPendingReports(pendingReports, teams),
                if (pendingReports.isNotEmpty) const SizedBox(height: 20),
                _buildTaskSection(filteredTasks, tasks.length, teams),
              ],
            ),
          ),

          // Manual "Create Task" button — same dialog/logic as before,
          // just restyled to the app's primary brand color.
          Positioned(
            right: 24,
            bottom: 24,
            child: FloatingActionButton.extended(
              onPressed: () => _showCreateManualTaskDialog(teams),
              icon: const Icon(Icons.add_rounded, size: 21),
              label: const Text(
                'Create Task',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.assignment_turned_in_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rescue Tasks',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Assign and monitor emergency response operations',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _tasksStream(),
          builder: (context, snapshot) {
            final count = snapshot.data?.docs.length ?? 0;

            return Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.sync_rounded, size: 17, color: Colors.green),
                  const SizedBox(width: 7),
                  Text(
                    '$count Tasks',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // ============================================================
  // STAT CARDS
  // Cards now have a tinted background matching each stat's
  // color (same look as Rescue Teams stat cards) instead of a
  // plain white card with just the icon colored.
  // ============================================================

  Widget _buildStats(
      int newCount,
      int assignedCount,
      int activeCount,
      int completedCount,
      ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        final cardWidth = width > 1000
            ? (width - 48) / 4
            : width > 650
            ? (width - 16) / 2
            : width;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _statCard(
              'New Tasks',
              newCount,
              Icons.fiber_new_rounded,
              Colors.orange,
              cardWidth,
            ),
            _statCard(
              'Assigned',
              assignedCount,
              Icons.person_add_alt_1_rounded,
              Colors.blue,
              cardWidth,
            ),
            _statCard(
              'Active Rescues',
              activeCount,
              Icons.local_shipping_rounded,
              Colors.red,
              cardWidth,
            ),
            _statCard(
              'Completed',
              completedCount,
              Icons.task_alt_rounded,
              Colors.green,
              cardWidth,
            ),
          ],
        );
      },
    );
  }

  Widget _statCard(
      String title,
      int value,
      IconData icon,
      Color color,
      double width,
      ) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          // Plain light-grey background — same as Rescue Teams
          // stat cards. Only the icon circle carries the color.
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withOpacity(0.20),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 15, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Text(
                  value.toString(),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PENDING REPORTS
  // ============================================================

  Widget _buildPendingReports(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> reports,
      List<QueryDocumentSnapshot<Map<String, dynamic>>> teams,
      ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(top: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reports Awaiting Assignment',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Assign an available rescue team to incoming reports',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${reports.length} Pending',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...reports.take(5).map((report) => _pendingReportTile(report, teams)),
        ],
      ),
    );
  }

  Widget _pendingReportTile(
      QueryDocumentSnapshot<Map<String, dynamic>> report,
      List<QueryDocumentSnapshot<Map<String, dynamic>>> teams,
      ) {
    final data = report.data();

    final emergency = (data['emergencyType'] ?? 'Emergency').toString();
    final severity = (data['severity'] ?? 'Unknown').toString();
    final city =
    (data['city'] ?? data['location'] ?? 'Location unavailable')
        .toString();
    final reporter = (data['reporterName'] ?? 'Citizen').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          RescueTaskWidgets.emergencyIcon(emergency),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  emergency,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$reporter • $city',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
          RescueTaskWidgets.severityBadge(severity),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () => _showAssignDialog(report, teams),
            icon: const Icon(Icons.assignment_ind_rounded, size: 16),
            label: const Text(
              'Assign',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding:
              const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TASK SECTION
  // ============================================================

  Widget _buildTaskSection(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> tasks,
      int totalTasks,
      List<QueryDocumentSnapshot<Map<String, dynamic>>> teams,
      ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Rescue Operations',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                ),
                SizedBox(
                  width: 220,
                  height: 38,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchText = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search tasks...',
                      hintStyle: const TextStyle(fontSize: 14),
                      prefixIcon:
                      const Icon(Icons.search_rounded, size: 18),
                      suffixIcon: _searchText.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchText = '';
                          });
                        },
                      )
                          : null,
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(9),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedFilter,
                      icon: const Icon(Icons.keyboard_arrow_down, size: 17),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                      items: const [
                        'All',
                        'New',
                        'Assigned',
                        'Active',
                        'Completed',
                      ].map((filter) {
                        return DropdownMenuItem(
                          value: filter,
                          child: Text(filter),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _selectedFilter = value;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade300),
          if (tasks.isEmpty) _emptyTasks() else _taskTable(tasks, teams),
        ],
      ),
    );
  }

  // ============================================================
  // TASK TABLE
  // Header background + dividers now match Rescue Teams table
  // (grey.shade200 heading, plain grey dividers).
  // ============================================================

  Widget _taskTable(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> tasks,
      List<QueryDocumentSnapshot<Map<String, dynamic>>> teams,
      ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: constraints.maxWidth < 1050
                ? 1050
                : constraints.maxWidth,
            child: Column(
              children: [
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  color: Colors.grey.shade200,
                  child: const Row(
                    children: [
                      RescueTaskTableHeader('TASK', width: 125),
                      RescueTaskTableHeader('EMERGENCY', width: 150),
                      RescueTaskTableHeader('LOCATION', width: 170),
                      RescueTaskTableHeader('TEAM / LEADER', width: 210),
                      RescueTaskTableHeader('SEVERITY', width: 110),
                      RescueTaskTableHeader('STATUS', width: 150),
                      RescueTaskTableHeader('ACTION', width: 130),
                    ],
                  ),
                ),
                Divider(height: 1, color: Colors.grey.shade300),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 480),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      return _taskRow(tasks[index], teams);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _taskRow(
      QueryDocumentSnapshot<Map<String, dynamic>> doc,
      List<QueryDocumentSnapshot<Map<String, dynamic>>> teams,
      ) {
    final data = doc.data();

    final taskId = (data['taskId'] ?? doc.id).toString();
    final emergency =
    (data['emergencyType'] ?? data['type'] ?? 'Emergency').toString();
    final location = (data['city'] ??
        data['location'] ??
        data['address'] ??
        'Unknown')
        .toString();
    final teamId = (data['teamId'] ?? '').toString();
    final team = (data['teamName'] ?? 'Unassigned').toString();
    final leader = (data['leaderName'] ?? 'Unassigned').toString();
    final severity = (data['severity'] ?? 'Unknown').toString();
    final status = (data['status'] ?? 'dispatched').toString();
    final isUnassigned = teamId.isEmpty;

    return InkWell(
      onTap: () => _showTaskDetails(doc),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 125,
              child: Text(
                taskId.length > 12 ? taskId.substring(0, 12) : taskId,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
            SizedBox(
              width: 150,
              child: Row(
                children: [
                  RescueTaskWidgets.emergencyIcon(emergency),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      emergency,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 170,
              child: Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 15, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      location,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 210,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    team,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    leader,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ),
            SizedBox(width: 110, child: RescueTaskWidgets.severityBadge(severity)),
            SizedBox(width: 150, child: RescueTaskWidgets.statusBadge(status)),
            SizedBox(
              width: 130,
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'View task',
                    onPressed: () => _showTaskDetails(doc),
                    icon: Icon(Icons.visibility_outlined,
                        size: 18, color: AppColors.primary),
                  ),
                  if (isUnassigned)
                    IconButton(
                      tooltip: 'Assign Task',
                      onPressed: () => _showAssignTeamDialog(doc, teams),
                      icon: const Icon(
                        Icons.assignment_ind_rounded,
                        size: 18,
                        color: Colors.green,
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

  // ============================================================
  // ICONS / BADGES
  // ============================================================











  // ============================================================
  // CREATE MANUAL TASK DIALOG
  // (unchanged logic — dropdown of available teams, emergency
  // type, description, priority, latitude, longitude, address)
  // ============================================================

  void _showCreateManualTaskDialog(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> teams,
      ) {
    String? selectedTeamId;
    final descriptionController = TextEditingController();
    final latitudeController = TextEditingController();
    final longitudeController = TextEditingController();
    final addressController = TextEditingController();

    String selectedEmergencyType = 'Flood';
    String selectedPriority = 'High';

    final availableTeams = teams.where((team) {
      final status = (team.data()['status'] ?? '').toString().toLowerCase();
      return status == 'available';
    }).toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool isCreating = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.add_task_rounded, color: AppColors.primary),
                  const SizedBox(width: 10),
                  const Text(
                    'Create Manual Rescue Task',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Rescue Team',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 7),
                      if (availableTeams.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'No available rescue team right now. A team must be free (status = Available) before you can create a task for it.',
                            style: TextStyle(fontSize: 14, color: Colors.orange),
                          ),
                        )
                      else
                        DropdownButtonFormField<String>(
                          initialValue: selectedTeamId,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            prefixIcon: const Icon(Icons.groups_rounded),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(9),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          items: availableTeams.map((team) {
                            final teamData = team.data();
                            final teamName =
                            (teamData['teamName'] ?? team.id).toString();
                            final leaderName =
                            (teamData['leaderName'] ?? 'No leader').toString();

                            return DropdownMenuItem<String>(
                              value: team.id,
                              child: Text(
                                '$teamName • $leaderName',
                                style: const TextStyle(fontSize: 14),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setDialogState(() {
                              selectedTeamId = value;
                            });
                          },
                        ),
                      const SizedBox(height: 14),
                      const Text(
                        'Emergency Type',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 7),
                      DropdownButtonFormField<String>(
                        initialValue: selectedEmergencyType,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          prefixIcon: const Icon(Icons.warning_amber_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(9),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        items: const [
                          'Flood',
                          'Heavy Rain',
                          'Storm',
                          'Earthquake',
                          'Heatwave',
                          'Fire',
                          'Accident',
                          'Other',
                        ].map((type) {
                          return DropdownMenuItem<String>(
                            value: type,
                            child: Text(type),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() {
                            selectedEmergencyType = value;
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Description',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 7),
                      TextField(
                        controller: descriptionController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Enter emergency description',
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(bottom: 45),
                            child: Icon(Icons.description_outlined),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(9),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Priority',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 7),
                      DropdownButtonFormField<String>(
                        initialValue: selectedPriority,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          prefixIcon: const Icon(Icons.priority_high_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(9),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        items: const [
                          'Low',
                          'Medium',
                          'High',
                          'Critical',
                        ].map((priority) {
                          return DropdownMenuItem<String>(
                            value: priority,
                            child: Text(priority),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() {
                            selectedPriority = value;
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Latitude',
                                  style: TextStyle(
                                      fontSize: 14, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 7),
                                TextField(
                                  controller: latitudeController,
                                  keyboardType: const TextInputType
                                      .numberWithOptions(decimal: true, signed: true),
                                  decoration: InputDecoration(
                                    hintText: '31.5204',
                                    prefixIcon: const Icon(
                                        Icons.location_searching_rounded, size: 19),
                                    filled: true,
                                    fillColor: Colors.grey.shade100,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(9),
                                      borderSide:
                                      BorderSide(color: Colors.grey.shade300),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Longitude',
                                  style: TextStyle(
                                      fontSize: 14, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 7),
                                TextField(
                                  controller: longitudeController,
                                  keyboardType: const TextInputType
                                      .numberWithOptions(decimal: true, signed: true),
                                  decoration: InputDecoration(
                                    hintText: '74.3587',
                                    prefixIcon: const Icon(
                                        Icons.location_searching_rounded, size: 19),
                                    filled: true,
                                    fillColor: Colors.grey.shade100,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(9),
                                      borderSide:
                                      BorderSide(color: Colors.grey.shade300),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Address',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 7),
                      TextField(
                        controller: addressController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Enter emergency location/address',
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(bottom: 18),
                            child: Icon(Icons.location_on_outlined),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(9),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.withOpacity(0.2)),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline_rounded, size: 18, color: Colors.blue),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'This task is created directly by the admin and is not linked to a citizen report.',
                                style: TextStyle(fontSize: 13, color: Colors.blue),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isCreating
                      ? null
                      : () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: isCreating
                      ? null
                      : () async {
                    if (selectedTeamId == null) {
                      _showDialogError('Please select a rescue team.');
                      return;
                    }

                    final teamId = selectedTeamId!;
                    final description = descriptionController.text.trim();
                    final latitudeText = latitudeController.text.trim();
                    final longitudeText = longitudeController.text.trim();
                    final address = addressController.text.trim();

                    if (description.isEmpty) {
                      _showDialogError('Please enter task description.');
                      return;
                    }
                    if (latitudeText.isEmpty) {
                      _showDialogError('Please enter latitude.');
                      return;
                    }
                    if (longitudeText.isEmpty) {
                      _showDialogError('Please enter longitude.');
                      return;
                    }
                    if (address.isEmpty) {
                      _showDialogError('Please enter address.');
                      return;
                    }

                    final latitude = double.tryParse(latitudeText);
                    final longitude = double.tryParse(longitudeText);

                    if (latitude == null || longitude == null) {
                      _showDialogError(
                          'Latitude and longitude must be valid numbers.');
                      return;
                    }
                    if (latitude < -90 || latitude > 90) {
                      _showDialogError('Latitude must be between -90 and 90.');
                      return;
                    }
                    if (longitude < -180 || longitude > 180) {
                      _showDialogError('Longitude must be between -180 and 180.');
                      return;
                    }

                    setDialogState(() {
                      isCreating = true;
                    });

                    final success = await _createManualTask(
                      teamId: teamId,
                      emergencyType: selectedEmergencyType,
                      description: description,
                      priority: selectedPriority,
                      latitude: latitude,
                      longitude: longitude,
                      address: address,
                    );

                    if (success && dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    } else if (dialogContext.mounted) {
                      setDialogState(() {
                        isCreating = false;
                      });
                    }
                  },
                  icon: isCreating
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                      : const Icon(Icons.add_task_rounded, size: 17),
                  label: Text(isCreating ? 'Creating...' : 'Create Task'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      descriptionController.dispose();
      latitudeController.dispose();
      longitudeController.dispose();
      addressController.dispose();
    });
  }

  // ============================================================
  // CREATE MANUAL TASK (unchanged)
  // ============================================================

  Future<bool> _createManualTask({
    required String teamId,
    required String emergencyType,
    required String description,
    required String priority,
    required double latitude,
    required double longitude,
    required String address,
  }) async {
    try {
      await _taskService.createManualTask(
        teamId: teamId,
        emergencyType: emergencyType,
        description: description,
        priority: priority,
        latitude: latitude,
        longitude: longitude,
        address: address,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Manual rescue task created successfully.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return true;
    } catch (e) {
      _showErrorSnackBar('Failed to create manual task: $e');
      return false;
    }
  }

  void _showDialogError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  // ============================================================
  // ASSIGN DIALOG (unchanged logic)
  // ============================================================

  void _showAssignDialog(
      QueryDocumentSnapshot<Map<String, dynamic>> report,
      List<QueryDocumentSnapshot<Map<String, dynamic>>> teams,
      ) {
    String? selectedTeamId;

    final availableTeams = teams.where((team) {
      final status = (team.data()['status'] ?? '').toString().toLowerCase();
      return status == 'available';
    }).toList();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final data = report.data();

            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.assignment_ind_rounded, color: AppColors.primary),
                  const SizedBox(width: 10),
                  const Text(
                    'Assign Rescue Task',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              content: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RescueTaskWidgets.dialogInfo('Emergency', (data['emergencyType'] ?? 'Emergency').toString()),
                    RescueTaskWidgets.dialogInfo('Citizen', (data['reporterName'] ?? 'Unknown Citizen').toString()),
                    RescueTaskWidgets.dialogInfo('Location', (data['city'] ?? data['location'] ?? 'Unknown').toString()),
                    RescueTaskWidgets.dialogInfo('Severity', (data['severity'] ?? 'Unknown').toString()),
                    const SizedBox(height: 16),
                    const Text(
                      'Select Rescue Team',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 7),
                    if (availableTeams.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'No available rescue team is currently available.',
                          style: TextStyle(fontSize: 14, color: Colors.orange),
                        ),
                      )
                    else
                      DropdownButtonFormField<String>(
                        initialValue: selectedTeamId,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(9),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        items: availableTeams.map((team) {
                          final teamData = team.data();
                          final teamName = (teamData['teamName'] ?? team.id).toString();
                          final leaderName = (teamData['leaderName'] ?? 'No leader').toString();

                          return DropdownMenuItem<String>(
                            value: team.id,
                            child: Text('$teamName • $leaderName',
                                style: const TextStyle(fontSize: 14)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedTeamId = value;
                          });
                        },
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: availableTeams.isEmpty || selectedTeamId == null
                      ? null
                      : () async {
                    final selectedTeam = availableTeams
                        .firstWhere((team) => team.id == selectedTeamId);

                    await _assignTask(report, selectedTeam);

                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: const Text('Assign Task'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // CREATE CENTRAL TASK (unchanged)
  // ============================================================

  Future<void> _assignTask(
    QueryDocumentSnapshot<Map<String, dynamic>> report,
    QueryDocumentSnapshot<Map<String, dynamic>> team,
  ) async {
    try {
      await _taskService.assignReportToTeam(report, team);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rescue task assigned successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to assign task: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ============================================================
  // ASSIGN TEAM TO AN EXISTING (UNASSIGNED) TASK (unchanged)
  // ============================================================

  void _showAssignTeamDialog(
      QueryDocumentSnapshot<Map<String, dynamic>> task,
      List<QueryDocumentSnapshot<Map<String, dynamic>>> teams,
      ) {
    String? selectedTeamId;

    final availableTeams = teams.where((team) {
      final status = (team.data()['status'] ?? '').toString().toLowerCase();
      return status == 'available';
    }).toList();

    final data = task.data();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.assignment_ind_rounded, color: AppColors.primary),
                  const SizedBox(width: 10),
                  const Text(
                    'Assign Rescue Task',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RescueTaskWidgets.dialogInfo('Emergency',
                          (data['emergencyType'] ?? data['type'] ?? 'Emergency').toString()),
                      RescueTaskWidgets.dialogInfo('Description',
                          (data['description'] ?? 'No description provided').toString()),
                      RescueTaskWidgets.dialogInfo('Priority',
                          (data['priority'] ?? data['severity'] ?? 'Unknown').toString()),
                      RescueTaskWidgets.dialogInfo('Latitude', (data['latitude'] ?? '-').toString()),
                      RescueTaskWidgets.dialogInfo('Longitude', (data['longitude'] ?? '-').toString()),
                      RescueTaskWidgets.dialogInfo('Address',
                          (data['address'] ?? data['location'] ?? data['city'] ?? '-').toString()),
                      const SizedBox(height: 16),
                      const Text(
                        'Select Rescue Team (Team ID)',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 7),
                      if (availableTeams.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'No available rescue team is currently available.',
                            style: TextStyle(fontSize: 14, color: Colors.orange),
                          ),
                        )
                      else
                        DropdownButtonFormField<String>(
                          initialValue: selectedTeamId,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(9),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          items: availableTeams.map((team) {
                            final teamData = team.data();
                            final teamName = (teamData['teamName'] ?? team.id).toString();
                            final leaderName = (teamData['leaderName'] ?? 'No leader').toString();

                            return DropdownMenuItem<String>(
                              value: team.id,
                              child: Text('$teamName • $leaderName',
                                  style: const TextStyle(fontSize: 14)),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setDialogState(() {
                              selectedTeamId = value;
                            });
                          },
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: availableTeams.isEmpty || selectedTeamId == null
                      ? null
                      : () async {
                    final selectedTeam = availableTeams
                        .firstWhere((team) => team.id == selectedTeamId);

                    await _assignTeamToTask(task, selectedTeam);

                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: const Text('Assign Task'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // ASSIGN TEAM TO EXISTING TASK (unchanged)
  // ============================================================

  Future<void> _assignTeamToTask(
    QueryDocumentSnapshot<Map<String, dynamic>> task,
    QueryDocumentSnapshot<Map<String, dynamic>> team,
  ) async {
    try {
      await _taskService.assignTeamToExistingTask(task, team);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rescue team assigned successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to assign team: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ============================================================
  // TASK DETAILS (unchanged)
  // ============================================================

  void _showTaskDetails(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SizedBox(
            width: 650,
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.assignment_turned_in_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Rescue Task',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                              ),
                              Text(
                                (data['taskId'] ?? doc.id).toString(),
                                style: const TextStyle(fontSize: 13, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        RescueTaskWidgets.statusBadge((data['status'] ?? 'dispatched').toString()),
                      ],
                    ),
                    const SizedBox(height: 22),
                    _detailGrid(data),
                    const SizedBox(height: 25),
                    const Text(
                      'Rescue Progress',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 15),
                    RescueTaskWidgets.buildTimeline((data['status'] ?? 'dispatched').toString()),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _detailGrid(Map<String, dynamic> data) {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        RescueTaskWidgets.detailBox('Emergency',
            data['emergencyType']?.toString() ?? data['type']?.toString() ?? 'Emergency',
            Icons.warning_amber_rounded),
        RescueTaskWidgets.detailBox('Citizen',
            data['citizenName']?.toString() ?? data['reporterName']?.toString() ?? 'Citizen',
            Icons.person_rounded),
        RescueTaskWidgets.detailBox('Location',
            data['city']?.toString() ?? data['location']?.toString() ?? data['address']?.toString() ?? 'Unknown',
            Icons.location_on_rounded),
        RescueTaskWidgets.detailBox('Rescue Team', data['teamName']?.toString() ?? 'Unassigned',
            Icons.local_shipping_rounded),
        RescueTaskWidgets.detailBox('Leader', data['leaderName']?.toString() ?? 'Unassigned',
            Icons.person_pin_rounded),
        RescueTaskWidgets.detailBox('Severity', data['severity']?.toString() ?? 'Unknown',
            Icons.priority_high_rounded),
        RescueTaskWidgets.detailBox('Source', _sourceLabel(data['sourceType']?.toString()),
            Icons.source_rounded),
      ],
    );
  }

  String _sourceLabel(String? source) {
    switch (source?.toLowerCase()) {
      case 'citizen_report':
        return 'Citizen Report';
      case 'natural_disaster':
        return 'Natural Disaster';
      case 'ai_prediction':
        return 'AI Prediction';
      case 'usgs_earthquake':
        return 'USGS Earthquake';
      case 'weather':
        return 'Weather Alert';
      case 'admin_manual':
        return 'Admin Manual';
      default:
        return source ?? 'Unknown';
    }
  }







  Widget _emptyTasks() {
    return Padding(
      padding: const EdgeInsets.all(50),
      child: Column(
        children: [
          Icon(Icons.assignment_outlined, size: 50, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text(
            'No rescue tasks found',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black87),
          ),
          const SizedBox(height: 5),
          const Text(
            'Assigned rescue operations will appear here.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _errorView(String error) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(30),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.red, size: 40),
            const SizedBox(height: 10),
            const Text(
              'Unable to load Rescue Tasks',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// TABLE HEADER
// ============================================================

