import 'package:flutter/material.dart';

class RescueStatusChip extends StatelessWidget {
  final String status;

  const RescueStatusChip({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;

    switch (status) {
      case "Available":
        backgroundColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        break;

      case "On Mission":
        backgroundColor = Colors.orange.shade100;
        textColor = Colors.orange.shade800;
        break;

      case "Offline":
        backgroundColor = Colors.red.shade100;
        textColor = Colors.red.shade800;
        break;

      default:
        backgroundColor = Colors.grey.shade300;
        textColor = Colors.black87;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}