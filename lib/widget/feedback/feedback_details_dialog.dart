import 'package:flutter/material.dart';

import '../../model/feedback_model.dart';
import '../../services/feedback_service.dart';

class FeedbackDetailsDialog extends StatefulWidget {
  final FeedbackModel feedback;

  const FeedbackDetailsDialog({
    super.key,
    required this.feedback,
  });

  @override
  State<FeedbackDetailsDialog> createState() =>
      _FeedbackDetailsDialogState();
}

class _FeedbackDetailsDialogState
    extends State<FeedbackDetailsDialog> {
  final FeedbackService _service = FeedbackService();

  bool loading = false;

  Future<void> markRead() async {
    try {
      setState(() {
        loading = true;
      });

      await _service.markAsRead(widget.feedback.id);

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
        ),
      );
    }
  }

  Future<void> deleteFeedback() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Delete Feedback"),
          content: const Text(
            "Are you sure you want to delete this feedback?",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      setState(() {
        loading = true;
      });

      await _service.deleteFeedback(widget.feedback.id);

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
        ),
      );
    }
  }

  Widget infoTile(
      String title,
      String value,
      IconData icon,
      ) {
    return ListTile(
      dense: true,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(value),
    );
  }

  Widget ratingStars(int rating) {
    return Row(
      children: List.generate(
        5,
            (index) => Icon(
          index < rating
              ? Icons.star
              : Icons.star_border,
          color: Colors.amber,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final feedback = widget.feedback;

    return Dialog(
      child: SizedBox(
        width: 650,
        child: loading
            ? const Padding(
          padding: EdgeInsets.all(60),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        )
            : SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [

                const Center(
                  child: Text(
                    "Feedback Details",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                infoTile(
                  "Name",
                  feedback.name,
                  Icons.person,
                ),

                infoTile(
                  "Email",
                  feedback.email,
                  Icons.email,
                ),

                ListTile(
                  leading: const Icon(Icons.star),
                  title: const Text("Rating"),
                  subtitle: ratingStars(
                    feedback.rating,
                  ),
                ),

                infoTile(
                  "Date",
                  feedback.formattedDate,
                  Icons.calendar_today,
                ),

                infoTile(
                  "Time",
                  feedback.formattedTime,
                  Icons.access_time,
                ),

                const SizedBox(height: 15),

                const Text(
                  "Feedback Message",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                Container(
                  width: double.infinity,
                  padding:
                  const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius:
                    BorderRadius.circular(
                        10),
                  ),
                  child: Text(
                    feedback.message,
                  ),
                ),

                const SizedBox(height: 20),

                Row(
                  children: [

                    const Text(
                      "Status:",
                      style: TextStyle(
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),

                    const SizedBox(width: 10),

                    Chip(
                      backgroundColor:
                      feedback.status ==
                          "Read"
                          ? Colors.green
                          : Colors.orange,
                      label: Text(
                        feedback.status,
                        style:
                        const TextStyle(
                          color:
                          Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 25),

                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [

                    ElevatedButton.icon(
                      icon: const Icon(
                          Icons.check),
                      label:
                      const Text("Mark Read"),
                      style:
                      ElevatedButton
                          .styleFrom(
                        backgroundColor:
                        Colors.green,
                        foregroundColor:
                        Colors.white,
                      ),
                      onPressed: feedback
                          .status ==
                          "Read"
                          ? null
                          : markRead,
                    ),

                    ElevatedButton.icon(
                      icon: const Icon(
                          Icons.delete),
                      label:
                      const Text("Delete"),
                      style:
                      ElevatedButton
                          .styleFrom(
                        backgroundColor:
                        Colors.red,
                        foregroundColor:
                        Colors.white,
                      ),
                      onPressed:
                      deleteFeedback,
                    ),

                    OutlinedButton(
                      onPressed: () {
                        Navigator.pop(
                            context);
                      },
                      child:
                      const Text("Close"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}