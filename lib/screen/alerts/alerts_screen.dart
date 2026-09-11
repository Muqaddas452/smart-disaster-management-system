import 'package:flutter/material.dart';

import '../../model/alert_model.dart';
import '../../model/notification_model.dart';
import '../../services/alert_service.dart';
import '../../services/notification_service.dart';
import '../../widget/alerts/alert_stats.dart';
import '../../widget/alerts/alerts_table.dart';
import '../../widget/alerts/broadcast_alert_dialog.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final TextEditingController _searchController =
  TextEditingController();

  final AlertService _service = AlertService();
  final NotificationService _notificationService =
  NotificationService();

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
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
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

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) {
      return "Just now";
    }

    final difference = DateTime.now().difference(dateTime);

    if (difference.inSeconds < 60) {
      return "Just now";
    }

    if (difference.inMinutes < 60) {
      return "${difference.inMinutes} min ago";
    }

    if (difference.inHours < 24) {
      return "${difference.inHours} hr ago";
    }

    if (difference.inDays < 7) {
      return "${difference.inDays} day ago";
    }

    return "${dateTime.day}/${dateTime.month}/${dateTime.year}";
  }

  IconData _getNotificationIcon(
      NotificationModel notification,
      ) {
    final title = notification.title.toLowerCase();
    final type = notification.type.toLowerCase();
    final recipient =
    notification.recipientType.toLowerCase();

    if (type.contains("rescue") ||
        title.contains("rescue")) {
      return Icons.local_hospital_outlined;
    }

    if (recipient.contains("leader")) {
      return Icons.groups_outlined;
    }

    if (recipient.contains("citizen")) {
      return Icons.person_outline;
    }

    return Icons.notifications_none;
  }

  Color _getIconBackground(
      NotificationModel notification,
      ) {
    final recipient =
    notification.recipientType.toLowerCase();

    if (recipient.contains("leader")) {
      return Colors.orange.withOpacity(0.12);
    }

    if (recipient.contains("citizen")) {
      return Colors.blue.withOpacity(0.12);
    }

    return Colors.grey.withOpacity(0.12);
  }

  String _getRecipientName(
      NotificationModel notification,
      ) {
    final recipient =
    notification.recipientType.toLowerCase();

    if (recipient.contains("leader")) {
      return "Rescue Leader";
    }

    if (recipient.contains("citizen")) {
      return "Citizen";
    }

    return notification.recipientType.isEmpty
        ? "User"
        : notification.recipientType;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AlertModel>>(
      stream: _service.getAlerts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
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
                // HEADER
                Row(
                  mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
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
                      label: const Text(
                        "Broadcast Alert",
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 25),

                // SEARCH
                TextField(
                  controller: _searchController,
                  onChanged: _search,
                  decoration: InputDecoration(
                    hintText:
                    "Search by Disaster, Area, Priority or Status",
                    prefixIcon:
                    const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius:
                      BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),

                const SizedBox(height: 30),

                // ALERT STATS
                AlertStats(
                  alerts: alerts,
                ),

                const SizedBox(height: 30),

                // RECENT ALERTS
                const Text(
                  "Recent Alerts",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 15),

                // Alerts > 5 = compact scroll
                  AlertsTable(
                    alerts: filteredAlerts,
                    onView: _viewAlert,
                    onEdit: _editAlert,
                    onDelete: _deleteAlert,
                  ),

                const SizedBox(height: 35),

                // =================================================
                // NOTIFICATIONS
                // =================================================

                StreamBuilder<List<NotificationModel>>(
                  stream: _notificationService
                      .getNotifications(),
                  builder: (
                      context,
                      notificationSnapshot,
                      ) {
                    if (notificationSnapshot
                        .connectionState ==
                        ConnectionState.waiting) {
                      return _buildNotificationLoading();
                    }

                    if (notificationSnapshot.hasError) {
                      return _buildNotificationError(
                        notificationSnapshot.error
                            .toString(),
                      );
                    }

                    final notifications =
                        notificationSnapshot.data ?? [];

                    final unreadCount =
                        notifications
                            .where(
                              (notification) =>
                          !notification.read,
                        )
                            .length;

                    return _buildNotifications(
                      notifications,
                      unreadCount,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotifications(
      List<NotificationModel> notifications,
      int unreadCount,
      ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xffF4F7F6),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            color: Colors.black.withOpacity(0.05),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // NOTIFICATION HEADER
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.notifications_outlined,
                  color: Colors.blue,
                ),
              ),

              const SizedBox(width: 12),

              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Notifications",
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      "Citizen and rescue team activity",
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              if (unreadCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "$unreadCount Unread",
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 18),

          if (notifications.isEmpty)
            _buildEmptyNotifications()
          else if (notifications.length > 5)
            SizedBox(
              height: 360,
              child: Scrollbar(
                thumbVisibility: true,
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: notifications.length,
                  separatorBuilder: (context, index) {
                    return const Divider(height: 1);
                  },
                  itemBuilder: (context, index) {
                    return _buildNotificationItem(
                      notifications[index],
                    );
                  },
                ),
              ),
            )
          else
            Column(
              children: notifications.map((notification) {
                return Column(
                  children: [
                    _buildNotificationItem(
                      notification,
                    ),
                    if (notification != notifications.last)
                      const Divider(height: 1),
                  ],
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(
      NotificationModel notification,
      ) {
    final isUnread = !notification.read;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        if (isUnread) {
          try {
            await _notificationService
                .markAsRead(notification.id);
          } catch (_) {}
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: 13,
          horizontal: 5,
        ),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius:
          BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            // ICON
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _getIconBackground(
                  notification,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getNotificationIcon(
                  notification,
                ),
                size: 21,
              ),
            ),

            const SizedBox(width: 12),

            // CONTENT
            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          maxLines: 1,
                          overflow:
                          TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isUnread
                                ? FontWeight.bold
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(
                          notification.createdAt,
                        ),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 5),

                  Text(
                    notification.message,
                    maxLines: 2,
                    overflow:
                    TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                      height: 1.35,
                    ),
                  ),

                  const SizedBox(height: 7),

                  Row(
                    children: [
                      Container(
                        padding:
                        const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey
                              .withOpacity(0.08),
                          borderRadius:
                          BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize:
                          MainAxisSize.min,
                          children: [
                            Icon(
                              notification
                                  .recipientType
                                  .toLowerCase()
                                  .contains(
                                  "leader")
                                  ? Icons
                                  .groups_outlined
                                  : Icons
                                  .person_outline,
                              size: 13,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _getRecipientName(
                                notification,
                              ),
                              style:
                              const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                                fontWeight:
                                FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (notification.reportId
                          .isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            "Report: ${notification.reportId}",
                            maxLines: 1,
                            overflow:
                            TextOverflow.ellipsis,
                            style:
                            const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // UNREAD DOT
            if (isUnread)
              Container(
                margin: const EdgeInsets.only(
                  left: 8,
                  top: 5,
                ),
                width: 8,
                height: 8,
                decoration:
                const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyNotifications() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 30,
      ),
      child: Column(
        children: [
          Icon(
            Icons.notifications_none,
            size: 45,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 10),
          Text(
            "No notifications yet",
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "New citizen and rescue activity will appear here.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationLoading() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: SizedBox(
          width: 25,
          height: 25,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationError(String error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Unable to load notifications: $error",
              style: const TextStyle(
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }
}