import 'package:flutter/material.dart';

class AIPredictionCard extends StatelessWidget {
  final String disaster;
  final String risk;
  final double? confidence;
  final String location;
  final DateTime? updatedAt;

  const AIPredictionCard({
    super.key,
    required this.disaster,
    required this.risk,
    this.confidence,
    this.location = '',
    this.updatedAt,
  });

  Color _riskColor() {
    switch (risk.toLowerCase()) {
      case 'critical':
        return Colors.deepPurple;
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _timeAgo() {
    if (updatedAt == null) {
      return 'Unknown';
    }

    final difference = DateTime.now().difference(updatedAt!);

    if (difference.isNegative || difference.inSeconds < 60) {
      return 'Just now';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours} hr ago';
    }

    return '${difference.inDays} day ago';
  }

  @override
  Widget build(BuildContext context) {
    final riskColor = _riskColor();

    return Card(
      elevation: 8,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(15),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.psychology,
                  color: Colors.deepPurple,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'AI Prediction',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),

            const Divider(),

            Text(
              'Disaster : $disaster',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                const Text(
                  'Risk Level : ',
                  style: TextStyle(fontSize: 16),
                ),
                Text(
                  risk.toUpperCase(),
                  style: TextStyle(
                    color: riskColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),

            if (confidence != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.analytics_outlined,
                    size: 18,
                    color: Colors.deepPurple,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Confidence : ${confidence!.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],

            if (location.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.location_on,
                    size: 17,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      location,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 8),

            Text(
              'Updated : ${_timeAgo()}',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}