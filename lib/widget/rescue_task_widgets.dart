import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Small reusable visual components used by the Rescue Tasks screen.
class RescueTaskWidgets {
  static Widget emergencyIcon(String emergency) {

    final value = emergency.toLowerCase();



    IconData icon = Icons.warning_amber_rounded;



    if (value.contains('flood')) {

      icon = Icons.water_rounded;

    } else if (value.contains('fire')) {

      icon = Icons.local_fire_department_rounded;

    } else if (value.contains('earthquake')) {

      icon = Icons.public_rounded;

    } else if (value.contains('storm')) {

      icon = Icons.thunderstorm_rounded;

    } else if (value.contains('rain')) {

      icon = Icons.cloudy_snowing;

    } else if (value.contains('accident')) {

      icon = Icons.car_crash_rounded;

    } else if (value.contains('heat')) {

      icon = Icons.wb_sunny_rounded;

    }



    return Container(

      width: 32,

      height: 32,

      decoration: BoxDecoration(

        color: AppColors.primary.withOpacity(0.15),

        borderRadius: BorderRadius.circular(8),

      ),

      child: Icon(icon, size: 17, color: AppColors.primary),

    );

  }



  static Color severityColor(String severity) {

    final value = severity.toLowerCase();



    if (value == 'critical' || value == 'extreme') return Colors.red;

    if (value == 'high') return Colors.orange;

    if (value == 'medium') return Colors.blue;

    if (value == 'low') return Colors.green;

    return Colors.grey;

  }



  static Widget severityBadge(String severity) {

    final color = severityColor(severity);



    return Container(

      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),

      decoration: BoxDecoration(

        color: color.withOpacity(0.15),

        borderRadius: BorderRadius.circular(20),

      ),

      child: Text(

        severity.toUpperCase(),

        overflow: TextOverflow.ellipsis,

        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),

      ),

    );

  }



  static Widget statusBadge(String status) {

    final value = status.toLowerCase();



    Color color = Colors.blue;

    IconData icon = Icons.assignment_rounded;



    if (value == 'dispatched') {

      color = Colors.orange;

      icon = Icons.send_rounded;

    } else if (value == 'accepted') {

      color = AppColors.primary;

      icon = Icons.check_circle_outline;

    } else if (value == 'assigned') {

      color = Colors.blue;

      icon = Icons.groups_rounded;

    } else if (value == 'enroute') {

      color = Colors.red;

      icon = Icons.local_shipping_rounded;

    } else if (value == 'in_progress') {

      color = Colors.orange;

      icon = Icons.engineering_rounded;

    } else if (value == 'resolved') {

      color = Colors.green;

      icon = Icons.task_alt_rounded;

    }



    return Container(

      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),

      decoration: BoxDecoration(

        color: color.withOpacity(0.15),

        borderRadius: BorderRadius.circular(20),

      ),

      child: Row(

        mainAxisSize: MainAxisSize.min,

        children: [

          Icon(icon, size: 15, color: color),

          const SizedBox(width: 5),

          Flexible(

            child: Text(

              statusLabel(status),

              overflow: TextOverflow.ellipsis,

              style:

              TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),

            ),

          ),

        ],

      ),

    );

  }



  static String statusLabel(String status) {

    switch (status.toLowerCase()) {

      case 'dispatched':

        return 'DISPATCHED';

      case 'accepted':

        return 'ACCEPTED';

      case 'assigned':

        return 'ASSIGNED';

      case 'enroute':

        return 'EN ROUTE';

      case 'in_progress':

        return 'IN PROGRESS';

      case 'resolved':

        return 'RESOLVED';

      default:

        return status.toUpperCase();

    }

  }



  static Widget dialogInfo(String title, String value) {

    return Padding(

      padding: const EdgeInsets.only(bottom: 8),

      child: Row(

        children: [

          SizedBox(

            width: 90,

            child: Text(title, style: const TextStyle(fontSize: 13, color: Colors.grey)),

          ),

          Expanded(

            child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),

          ),

        ],

      ),

    );

  }



  static Widget detailBox(String title, String value, IconData icon) {

    return SizedBox(

      width: 190,

      child: Container(

        padding: const EdgeInsets.all(13),

        decoration: BoxDecoration(

          color: Colors.grey.shade50,

          borderRadius: BorderRadius.circular(10),

          border: Border.all(color: Colors.grey.shade200),

        ),

        child: Row(

          children: [

            Icon(icon, size: 18, color: AppColors.primary),

            const SizedBox(width: 9),

            Expanded(

              child: Column(

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),

                  const SizedBox(height: 3),

                  Text(

                    value,

                    overflow: TextOverflow.ellipsis,

                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87),

                  ),

                ],

              ),

            ),

          ],

        ),

      ),

    );

  }



  static Widget buildTimeline(String status) {

    final current = status.toLowerCase();



    final steps = [

      'dispatched',

      'accepted',

      'assigned',

      'enroute',

      'in_progress',

      'resolved',

    ];



    final labels = [

      'Task Dispatched',

      'Leader Accepted',

      'Members Assigned',

      'Team En Route',

      'Rescue In Progress',

      'Task Resolved',

    ];



    int currentIndex = steps.indexOf(current);

    if (currentIndex < 0) currentIndex = 0;



    return Column(

      children: List.generate(steps.length, (index) {

        final done = index <= currentIndex;



        return Row(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            Column(

              children: [

                Container(

                  width: 28,

                  height: 28,

                  decoration: BoxDecoration(

                    color: done ? Colors.green : Colors.grey.shade100,

                    shape: BoxShape.circle,

                    border: Border.all(

                      color: done ? Colors.green : Colors.grey.shade300,

                    ),

                  ),

                  child: Icon(

                    done ? Icons.check : Icons.circle_outlined,

                    size: 15,

                    color: done ? Colors.white : Colors.grey,

                  ),

                ),

                if (index < steps.length - 1)

                  Container(

                    width: 2,

                    height: 28,

                    color: index < currentIndex ? Colors.green : Colors.grey.shade300,

                  ),

              ],

            ),

            const SizedBox(width: 12),

            Padding(

              padding: const EdgeInsets.only(top: 5),

              child: Text(

                labels[index],

                style: TextStyle(

                  fontSize: 14,

                  fontWeight: done ? FontWeight.w700 : FontWeight.w400,

                  color: done ? Colors.black87 : Colors.grey,

                ),

              ),

            ),

          ],

        );

      }),

    );

  }
}

class RescueTaskTableHeader extends StatelessWidget {
  final String title;
  final double width;

  const RescueTaskTableHeader(this.title, {required this.width});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: Colors.black54,
          letterSpacing: .4,
        ),
      ),
    );
  }
}
