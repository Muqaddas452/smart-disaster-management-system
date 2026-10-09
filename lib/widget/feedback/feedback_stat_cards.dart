import 'package:flutter/material.dart';

import '../../services/feedback_service.dart';

class FeedbackStatCards extends StatelessWidget {
  FeedbackStatCards({super.key});

  final FeedbackService _service = FeedbackService();

  Widget _statCard({
    required IconData icon,
    required Color color,
    required String title,
    required Stream stream,
    String suffix = "",
  }) {
    return Expanded(
      child: StreamBuilder(
        stream: stream,
        builder: (context, snapshot) {
          String value = "0";

          if (snapshot.hasData) {
            final data = snapshot.data;

            if (title == "Average Rating") {
              value = (data as double).toStringAsFixed(1);
            } else {
              value = data.toString();
            }

            value += suffix;
          }

          return Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 22,
                horizontal: 18,
              ),
              child: Column(
                children: [

                  CircleAvatar(
                    radius: 28,
                    backgroundColor: color.withOpacity(.12),
                    child: Icon(
                      icon,
                      color: color,
                      size: 30,
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [

        _statCard(
          icon: Icons.feedback,
          color: Colors.blue,
          title: "Total Feedback",
          stream: _service.totalFeedback(),
        ),

        const SizedBox(width: 18),

        _statCard(
          icon: Icons.mark_email_unread,
          color: Colors.orange,
          title: "New",
          stream: _service.newFeedback(),
        ),

        const SizedBox(width: 18),

        _statCard(
          icon: Icons.check_circle,
          color: Colors.green,
          title: "Read",
          stream: _service.readFeedback(),
        ),

        const SizedBox(width: 18),

        _statCard(
          icon: Icons.star,
          color: Colors.amber,
          title: "Average Rating",
          stream: _service.averageRating(),
        ),

      ],
    );
  }
}