import 'package:flutter/material.dart';

class StatusChip extends StatelessWidget {
  final String status;

  const StatusChip({
    super.key,
    required this.status,
  });

  Color get _backgroundColor {
    switch (status.toLowerCase()) {
      case "pending":
        return Colors.orange.shade100;

      case "in progress":
        return Colors.blue.shade100;

      case "resolved":
        return Colors.green.shade100;

      default:
        return Colors.grey.shade300;
    }
  }

  Color get _textColor {
    switch (status.toLowerCase()) {
      case "pending":
        return Colors.orange.shade800;

      case "in progress":
        return Colors.blue.shade800;

      case "resolved":
        return Colors.green.shade800;

      default:
        return Colors.black87;
    }
  }

  IconData get _icon {
    switch (status.toLowerCase()) {
      case "pending":
        return Icons.pending_actions;

      case "in progress":
        return Icons.engineering;

      case "resolved":
        return Icons.check_circle;

      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(
        _icon,
        color: _textColor,
        size: 18,
      ),
      backgroundColor: _backgroundColor,
      label: Text(
        status,
        style: TextStyle(
          color: _textColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}