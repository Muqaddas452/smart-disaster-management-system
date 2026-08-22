import 'package:flutter/material.dart';

import '../../widget/alerts/broadcast_alert_dialog.dart';
import '../dashboard/dispatch_rescue_dialog.dart';
import '../../screen/live_map_screen.dart';
import '../reports/generate_report_dialog.dart';

class EmergencyActionsPanel extends StatelessWidget {
  const EmergencyActionsPanel({super.key});


  Widget actionButton({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Color color,
    VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: 220,
      height: 55,

      child: ElevatedButton.icon(

        onPressed: onPressed,

        icon: Icon(
          icon,
          color: Colors.white,
        ),

        label: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),

        style: ElevatedButton.styleFrom(

          backgroundColor: color,

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),

        ),

      ),
    );
  }



  @override
  Widget build(BuildContext context) {

    return Card(

      child: Padding(

        padding: const EdgeInsets.all(20),

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [


            const Text(
              "Emergency Actions",

              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),

            ),


            const SizedBox(height: 25),



            Wrap(

              spacing: 20,

              runSpacing: 20,


              children: [


                // Broadcast Alert

                actionButton(

                  context: context,

                  icon: Icons.campaign,

                  title: "Broadcast Alert",

                  color: Colors.red,


                  onPressed: () {

                    showDialog(

                      context: context,

                      builder: (_) =>
                      const BroadcastAlertDialog(),

                    );

                  },

                ),




                // Dispatch Rescue

                actionButton(

                  context: context,

                  icon: Icons.local_shipping,

                  title: "Dispatch Rescue",

                  color: Colors.green,


                  onPressed: () {


                    showDialog(

                      context: context,


                      builder: (_) =>
                      const DispatchRescueDialog(),


                    );


                  },

                ),





                // Open Live Map

                actionButton(
                  context: context,
                  icon: Icons.map,
                  title: "Open Live Map",
                  color: Colors.blue,

                  onPressed: () {

                    Navigator.push(

                      context,

                      MaterialPageRoute(

                        builder: (_) => const LiveMapScreen(),

                      ),

                    );

                  },

                ),



                // Generate Report

                actionButton(

                  context: context,

                  icon: Icons.picture_as_pdf,

                  title: "Generate Report",

                  color: Colors.orange,


                  onPressed: () {


                    showDialog(

                      context: context,


                      builder: (_) =>
                      const GenerateReportDialog(),


                    );


                  },

                ),


              ],

            ),


          ],

        ),

      ),

    );

  }

}