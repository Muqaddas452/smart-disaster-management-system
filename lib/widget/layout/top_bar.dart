import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../model/alert_model.dart';
import '../../services/alert_service.dart';
import '../alerts/broadcast_alert_dialog.dart';

class TopBar extends StatefulWidget implements PreferredSizeWidget {
  final String title;
  final String subtitle;
  final bool showMenuButton;
  final VoidCallback? onMenuTap;

  const TopBar({
    super.key,
    required this.title,
    required this.subtitle,
    this.showMenuButton = false,
    this.onMenuTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(70);

  @override
  State<TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<TopBar> {
  // ============================================================
  // SEARCH
  // ============================================================

  final TextEditingController _searchController =
  TextEditingController();

  final FocusNode _searchFocusNode = FocusNode();

  final LayerLink _searchLayerLink = LayerLink();

  OverlayEntry? _searchOverlay;

  Timer? _searchDebounce;

  bool _searching = false;

  List<_SearchResult> _searchResults = [];

  // ============================================================
  // SEARCH TEXT CHANGE
  // ============================================================

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();

    final query = value.trim();

    if (query.isEmpty) {
      _removeSearchOverlay();

      setState(() {
        _searchResults = [];
        _searching = false;
      });

      return;
    }

    setState(() {
      _searching = true;
    });

    _showSearchOverlay();

    _searchDebounce = Timer(
      const Duration(milliseconds: 400),
          () {
        _performSearch(query);
      },
    );
  }

  // ============================================================
  // PERFORM SEARCH
  // ============================================================

  Future<void> _performSearch(String query) async {
    final lowerQuery = query.toLowerCase();

    try {
      final firestore = FirebaseFirestore.instance;

      final List<_SearchResult> results = [];

      // ========================================================
      // REPORTS
      // IMPORTANT:
      // Your project uses manual_reports
      // ========================================================

      final reportsSnapshot = await firestore
          .collection('manual_reports')
          .limit(50)
          .get();

      for (final doc in reportsSnapshot.docs) {
        final data = doc.data();

        final reporterName =
        (data['reporterName'] ??
            data['reportedBy'] ??
            '')
            .toString();

        final emergencyType =
        (data['emergencyType'] ??
            data['incident_type'] ??
            '')
            .toString();

        final description =
        (data['description'] ?? '').toString();

        if (_containsQuery(
          lowerQuery,
          [
            reporterName,
            emergencyType,
            description,
          ],
        )) {
          results.add(
            _SearchResult(
              type: _SearchResultType.report,
              id: doc.id,
              title: reporterName.isEmpty
                  ? "User Report"
                  : reporterName,
              subtitle: emergencyType.isEmpty
                  ? description
                  : emergencyType,
              icon: Icons.assignment,
              color: Colors.blue,
            ),
          );
        }
      }

      // ========================================================
      // RESCUE TEAMS
      // ========================================================

      final teamsSnapshot = await firestore
          .collection('rescueTeams')
          .limit(50)
          .get();

      for (final doc in teamsSnapshot.docs) {
        final data = doc.data();

        final teamName =
        (data['teamName'] ?? '').toString();

        final leader =
        (data['leaderName'] ??
            data['leader'] ??
            '')
            .toString();

        final vehicle =
        (data['vehicle'] ?? '').toString();

        if (_containsQuery(
          lowerQuery,
          [
            teamName,
            leader,
            vehicle,
          ],
        )) {
          results.add(
            _SearchResult(
              type: _SearchResultType.team,
              id: doc.id,
              title: teamName.isEmpty
                  ? "Rescue Team"
                  : teamName,
              subtitle: leader.isEmpty
                  ? "Rescue Team"
                  : "Leader: $leader",
              icon: Icons.groups,
              color: Colors.green,
            ),
          );
        }
      }

      // ========================================================
      // CITIZENS
      // ========================================================

      final citizensSnapshot = await firestore
          .collection('citizens')
          .limit(50)
          .get();

      for (final doc in citizensSnapshot.docs) {
        final data = doc.data();

        final name =
        (data['name'] ?? '').toString();

        final email =
        (data['email'] ?? '').toString();

        final phone =
        (data['phone'] ?? '').toString();

        if (_containsQuery(
          lowerQuery,
          [
            name,
            email,
            phone,
          ],
        )) {
          results.add(
            _SearchResult(
              type: _SearchResultType.citizen,
              id: doc.id,
              title: name.isEmpty
                  ? "Citizen"
                  : name,
              subtitle: email.isEmpty
                  ? phone
                  : email,
              icon: Icons.person,
              color: Colors.purple,
            ),
          );
        }
      }

      if (!mounted) return;

      setState(() {
        _searchResults = results.take(15).toList();
        _searching = false;
      });

      _showSearchOverlay();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _searchResults = [];
        _searching = false;
      });

      _showSearchOverlay();

      _showSnackBar(
        "Search failed. Please try again.",
        isError: true,
      );
    }
  }

  bool _containsQuery(
      String query,
      List<String> values,
      ) {
    return values.any(
          (value) => value.toLowerCase().contains(query),
    );
  }

  // ============================================================
  // SEARCH OVERLAY
  // ============================================================

  void _showSearchOverlay() {
    _removeSearchOverlay();

    if (_searchController.text.trim().isEmpty) {
      return;
    }

    final overlay = Overlay.of(context);

    _searchOverlay = OverlayEntry(
      builder: (context) {
        return Positioned(
          width: 300,
          child: CompositedTransformFollower(
            link: _searchLayerLink,
            showWhenUnlinked: false,

            // Search box is 220 wide.
            // Dropdown starts at search box.
            offset: const Offset(0, 48),

            child: Material(
              elevation: 12,
              borderRadius: BorderRadius.circular(10),
              color: Colors.white,
              child: Container(
                constraints: const BoxConstraints(
                  maxHeight: 350,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.grey.shade200,
                  ),
                ),
                child: _buildSearchResults(),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_searchOverlay!);
  }

  void _removeSearchOverlay() {
    _searchOverlay?.remove();
    _searchOverlay = null;
  }

  // ============================================================
  // SEARCH RESULT TAP
  // ============================================================

  void _onSearchResultTap(
      _SearchResult result,
      ) {
    _removeSearchOverlay();

    _searchController.clear();
    _searchFocusNode.unfocus();

    setState(() {
      _searchResults = [];
      _searching = false;
    });

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                result.icon,
                color: result.color,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(result.title),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                result.subtitle.isEmpty
                    ? "No additional information available."
                    : result.subtitle,
              ),
              const SizedBox(height: 15),
              Text(
                "ID: ${result.id}",
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // BROADCAST ALERT
  // ============================================================

  void _openBroadcastAlert() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return const BroadcastAlertDialog();
      },
    );
  }

  // ============================================================
  // NOTIFICATION DETAILS
  // ============================================================

  void _showAlertDetails(
      AlertModel alert,
      ) {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                _getAlertIcon(alert.disaster),
                color: _getPriorityColor(
                  alert.priority,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(alert.disaster),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                _detailRow(
                  "Priority",
                  alert.priority,
                ),
                const SizedBox(height: 10),
                _detailRow(
                  "Area",
                  alert.area,
                ),
                const SizedBox(height: 10),
                _detailRow(
                  "Status",
                  alert.status,
                ),
                const SizedBox(height: 10),
                _detailRow(
                  "Message",
                  alert.message,
                ),
                const SizedBox(height: 10),
                _detailRow(
                  "Date",
                  "${alert.date.day}/"
                      "${alert.date.month}/"
                      "${alert.date.year}",
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  Widget _detailRow(
      String title,
      String value,
      ) {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value.isEmpty ? "-" : value,
        ),
      ],
    );
  }

  // ============================================================
  // SNACKBAR
  // ============================================================

  void _showSnackBar(
      String message, {
        bool isError = false,
      }) {
    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor:
        isError ? Colors.red : Colors.green,
        content: Text(message),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;

    final bool showSearch = w > 900;
    final bool showBroadcast = w > 700;

    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: AppColors.border,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // ======================================================
          // MENU
          // ======================================================

          if (widget.showMenuButton)
            IconButton(
              onPressed: widget.onMenuTap,
              icon: const Icon(
                Icons.menu_rounded,
              ),
              color: AppColors.textSecondary,
            ),

          // ======================================================
          // TITLE
          // ======================================================

          Expanded(
            child: Column(
              mainAxisAlignment:
              MainAxisAlignment.center,
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium,
                ),
                Text(
                  widget.subtitle,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall,
                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // ======================================================
          // SEARCH
          // ======================================================

          if (showSearch)
            CompositedTransformTarget(
              link: _searchLayerLink,
              child: SizedBox(
                width: 220,
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onChanged: _onSearchChanged,

                  onTap: () {
                    if (_searchController.text
                        .trim()
                        .isNotEmpty) {
                      _showSearchOverlay();
                    }
                  },

                  decoration: InputDecoration(
                    hintText:
                    'Search reports, teams…',

                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 18,
                    ),

                    suffixIcon:
                    _searchController.text
                        .isNotEmpty
                        ? IconButton(
                      icon: const Icon(
                        Icons.clear,
                        size: 18,
                      ),
                      onPressed: () {
                        _searchController
                            .clear();

                        _removeSearchOverlay();

                        setState(() {
                          _searchResults =
                          [];
                          _searching =
                          false;
                        });
                      },
                    )
                        : null,

                    contentPadding:
                    const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),

                    isDense: true,
                  ),
                ),
              ),
            ),

          if (showSearch)
            const SizedBox(width: 12),

          // ======================================================
          // BROADCAST ALERT
          // ======================================================

          if (showBroadcast)
            OutlinedButton.icon(
              onPressed:
              _openBroadcastAlert,
              icon: const Icon(
                Icons.campaign_rounded,
                size: 15,
                color: AppColors.danger,
              ),
              label: const Text(
                "Broadcast Alert",
                style: TextStyle(
                  color: AppColors.danger,
                  fontSize: 12,
                ),
              ),
              style:
              OutlinedButton.styleFrom(
                side: const BorderSide(
                  color: AppColors.danger,
                ),
                padding:
                const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),

          const SizedBox(width: 12),

          // ======================================================
          // NOTIFICATIONS
          // ======================================================

          StreamBuilder<List<AlertModel>>(
            stream: AlertService().getAlerts(),

            builder: (context, snapshot) {
              final alerts =
                  snapshot.data ?? [];

              final latestAlerts =
              alerts.take(5).toList();

              return PopupMenuButton<int>(
                tooltip: "Notifications",

                position:
                PopupMenuPosition.under,

                icon: _notificationIcon(
                  latestAlerts.length,
                ),

                itemBuilder: (_) {
                  if (latestAlerts.isEmpty) {
                    return [
                      const PopupMenuItem<int>(
                        enabled: false,
                        child: SizedBox(
                          width: 220,
                          child:
                          Text("No Alerts"),
                        ),
                      ),
                    ];
                  }

                  return [
                    PopupMenuItem<int>(
                      enabled: false,
                      child: Text(
                        "Recent Alerts (${alerts.length})",
                        style:
                        const TextStyle(
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),
                    ),

                    ...List.generate(
                      latestAlerts.length,
                          (index) {
                        final alert =
                        latestAlerts[index];

                        return PopupMenuItem<int>(
                          value: index,
                          child:
                          _notificationItem(
                            alert,
                          ),
                        );
                      },
                    ),

                    const PopupMenuDivider(),

                    const PopupMenuItem<int>(
                      value: -1,
                      child: Row(
                        children: [
                          Icon(
                            Icons.notifications,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            "View all alerts",
                          ),
                        ],
                      ),
                    ),
                  ];
                },

                onSelected: (value) {
                  if (value == -1) {
                    _showAllAlerts(alerts);
                    return;
                  }

                  if (value >= 0 &&
                      value <
                          latestAlerts.length) {
                    _showAlertDetails(
                      latestAlerts[value],
                    );
                  }
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SEARCH RESULTS WIDGET
  // ============================================================

  Widget _buildSearchResults() {
    return _searching
        ? const Padding(
      padding: EdgeInsets.all(20),
      child: Center(
        child:
        CircularProgressIndicator(),
      ),
    )
        : _searchResults.isEmpty
        ? const Padding(
      padding: EdgeInsets.all(20),
      child: Text(
        "No matching records found.",
      ),
    )
        : ListView.builder(
      padding:
      const EdgeInsets.symmetric(
        vertical: 6,
      ),
      shrinkWrap: true,
      itemCount:
      _searchResults.length,
      itemBuilder:
          (context, index) {
        final result =
        _searchResults[index];

        return ListTile(
          dense: true,

          leading: CircleAvatar(
            radius: 18,
            backgroundColor:
            result.color
                .withOpacity(.12),
            child: Icon(
              result.icon,
              color: result.color,
              size: 18,
            ),
          ),

          title: Text(
            result.title,
            maxLines: 1,
            overflow:
            TextOverflow.ellipsis,
          ),

          subtitle: Text(
            "${_typeLabel(result.type)} • "
                "${result.subtitle}",
            maxLines: 1,
            overflow:
            TextOverflow.ellipsis,
          ),

          onTap: () {
            _onSearchResultTap(
              result,
            );
          },
        );
      },
    );
  }

  String _typeLabel(
      _SearchResultType type,
      ) {
    switch (type) {
      case _SearchResultType.report:
        return "Report";

      case _SearchResultType.team:
        return "Rescue Team";

      case _SearchResultType.citizen:
        return "Citizen";
    }
  }

  // ============================================================
  // NOTIFICATION ICON
  // ============================================================

  Widget _notificationIcon(
      int count,
      ) {
    return SizedBox(
      width: 28,
      height: 28,
      child: Stack(
        children: [
          const Positioned(
            left: 2,
            top: 2,
            child: Icon(
              Icons.notifications_outlined,
              color:
              AppColors.textSecondary,
            ),
          ),

          if (count > 0)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                constraints:
                const BoxConstraints(
                  minWidth: 15,
                  minHeight: 15,
                ),
                padding:
                const EdgeInsets.symmetric(
                  horizontal: 3,
                ),
                decoration:
                const BoxDecoration(
                  color: AppColors.danger,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  count > 9
                      ? "9+"
                      : count.toString(),
                  textAlign:
                  TextAlign.center,
                  style:
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // NOTIFICATION ITEM
  // ============================================================

  Widget _notificationItem(
      AlertModel alert,
      ) {
    return SizedBox(
      width: 280,
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Icon(
            _getAlertIcon(
              alert.disaster,
            ),
            color: _getPriorityColor(
              alert.priority,
            ),
            size: 18,
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  alert.disaster,
                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,
                  style:
                  const TextStyle(
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  alert.area,
                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,
                  style:
                  const TextStyle(
                    fontSize: 11,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  alert.message,
                  maxLines: 2,
                  overflow:
                  TextOverflow.ellipsis,
                  style:
                  const TextStyle(
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ALL ALERTS
  // ============================================================

  void _showAllAlerts(
      List<AlertModel> alerts,
      ) {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text(
            "All Notifications",
          ),
          content: SizedBox(
            width: 500,
            height: 450,
            child: alerts.isEmpty
                ? const Center(
              child: Text(
                "No alerts available.",
              ),
            )
                : ListView.separated(
              itemCount:
              alerts.length,
              separatorBuilder:
                  (_, __) =>
              const Divider(),
              itemBuilder:
                  (context, index) {
                final alert =
                alerts[index];

                return ListTile(
                  leading: Icon(
                    _getAlertIcon(
                      alert.disaster,
                    ),
                    color:
                    _getPriorityColor(
                      alert.priority,
                    ),
                  ),
                  title: Text(
                    alert.disaster,
                  ),
                  subtitle: Text(
                    "${alert.area}\n"
                        "${alert.message}",
                    maxLines: 2,
                    overflow:
                    TextOverflow
                        .ellipsis,
                  ),
                  onTap: () {
                    Navigator.pop(
                      context,
                    );

                    _showAlertDetails(
                      alert,
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child:
              const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // ALERT ICON
  // ============================================================

  IconData _getAlertIcon(
      String disaster,
      ) {
    switch (disaster.toLowerCase()) {
      case "flood":
        return Icons.flood;

      case "heavy rain":
        return Icons.cloud;

      case "storm":
        return Icons.thunderstorm;

      case "heatwave":
        return Icons.wb_sunny;

      case "earthquake":
        return Icons.warning;

      default:
        return Icons.notifications;
    }
  }

  // ============================================================
  // PRIORITY COLOR
  // ============================================================

  Color _getPriorityColor(
      String priority,
      ) {
    switch (priority.toLowerCase()) {
      case "critical":
        return Colors.red;

      case "high":
        return Colors.orange;

      case "medium":
        return Colors.amber;

      default:
        return Colors.green;
    }
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _searchDebounce?.cancel();

    _removeSearchOverlay();

    _searchController.dispose();
    _searchFocusNode.dispose();

    super.dispose();
  }
}

// ================================================================
// SEARCH RESULT MODEL
// ================================================================

enum _SearchResultType {
  report,
  team,
  citizen,
}

class _SearchResult {
  final _SearchResultType type;
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _SearchResult({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}