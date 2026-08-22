import 'package:flutter/material.dart';


class GenerateReportDialog extends StatelessWidget {

  const GenerateReportDialog({super.key});


  @override
  Widget build(BuildContext context) {

    return AlertDialog(

      title: const Text(
        "Generate Report",
      ),

      content: const Text(
        "Generate disaster management report using current data?",
      ),

      actions: [

        TextButton(

          onPressed: () {

            Navigator.pop(context);

          },

          child: const Text(
            "Cancel",
          ),

        ),


        ElevatedButton(

          onPressed: () {

            Navigator.pop(context);

            ScaffoldMessenger.of(context)
                .showSnackBar(

              const SnackBar(
                content: Text(
                  "Report Generated Successfully",
                ),
              ),

            );

          },

          child: const Text(
            "Generate",
          ),

        ),

      ],

    );

  }

}