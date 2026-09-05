import 'package:flutter/material.dart';

import '../../model/feedback_model.dart';
import '../../services/feedback_service.dart';

import '../../widget/feedback/feedback_stat_cards.dart';
import '../../widget/feedback/feedback_table.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final FeedbackService _service = FeedbackService();

  String search = "";

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          "User Feedback",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 5),

        const Text(
          "View and manage feedback submitted by users.",
          style: TextStyle(color: Colors.grey),
        ),

        const SizedBox(height: 25),

        FeedbackStatCards(),

        const SizedBox(height: 25),

        SizedBox(
          width: 400,
          child: TextField(
            decoration: InputDecoration(
              hintText: "Search by name or email",
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (value) {
              setState(() {
                search = value.toLowerCase();
              });
            },
          ),
        ),

        const SizedBox(height: 25),

        StreamBuilder<List<FeedbackModel>>(
          stream: _service.getFeedback(),
          builder: (context, snapshot) {
            if (snapshot.connectionState ==
                ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(50),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(50),
                  child: Text(snapshot.error.toString()),
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(50),
                  child: Text("No Feedback Found"),
                ),
              );
            }

            List<FeedbackModel> feedbacks = snapshot.data!;

            if (search.isNotEmpty) {
              feedbacks = feedbacks.where((feedback) {
                return feedback.name
                    .toLowerCase()
                    .contains(search) ||
                    feedback.email
                        .toLowerCase()
                        .contains(search);
              }).toList();
            }

            return FeedbackTable(
              feedbacks: feedbacks,
            );
          },
        ),
      ],
    );
  }
}