import 'package:flutter/material.dart';

import '../../model/feedback_model.dart';
import 'feedback_details_dialog.dart';

class FeedbackTable extends StatelessWidget {
  final List<FeedbackModel> feedbacks;

  const FeedbackTable({
    super.key,
    required this.feedbacks,
  });

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case "read":
        return Colors.green;

      default:
        return Colors.orange;
    }
  }

  Widget _ratingStars(int rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
            (index) => Icon(
          index < rating
              ? Icons.star
              : Icons.star_border,
          color: Colors.amber,
          size: 18,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasMoreThan10 = feedbacks.length > 10;

    final Widget content = Column(
      children: [
        // HEADER
        Row(
          children: const [
            Expanded(
              flex: 2,
              child: Text(
                "Name",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            Expanded(
              flex: 2,
              child: Text(
                "Rating",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            Expanded(
              child: Text(
                "Status",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            Expanded(
              child: Text(
                "Date",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            Expanded(
              child: Text(
                "Action",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),

        const Divider(),

        // EMPTY STATE
        if (feedbacks.isEmpty)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(
              child: Text(
                "No Feedback Available",
                style: TextStyle(
                  fontSize: 18,
                ),
              ),
            ),
          ),

        // FEEDBACK LIST
        ...feedbacks.map(
              (feedback) {
            return Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 10,
              ),

              child: Row(
                children: [
                  // NAME
                  Expanded(
                    flex: 2,
                    child: Text(
                      feedback.name,
                      overflow:
                      TextOverflow.ellipsis,
                    ),
                  ),

                  // RATING
                  Expanded(
                    flex: 2,
                    child: _ratingStars(
                      feedback.rating,
                    ),
                  ),

                  // STATUS
                  Expanded(
                    child: Container(
                      padding:
                      const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _statusColor(
                          feedback.status,
                        ).withOpacity(.15),
                        borderRadius:
                        BorderRadius.circular(20),
                      ),
                      child: Text(
                        feedback.status,
                        textAlign:
                        TextAlign.center,
                        style: TextStyle(
                          color: _statusColor(
                            feedback.status,
                          ),
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  // DATE
                  Expanded(
                    child: Text(
                      feedback.formattedDate,
                    ),
                  ),

                  // ACTION
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(
                        Icons.visibility,
                        size: 18,
                      ),
                      label: const Text("View"),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) =>
                              FeedbackDetailsDialog(
                                feedback: feedback,
                              ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),

        child: hasMoreThan10
            ? SizedBox(
          height: 500,
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              child: content,
            ),
          ),
        )
            : content,
      ),
    );
  }
}