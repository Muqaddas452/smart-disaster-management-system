
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AIConfidencePanel extends StatelessWidget {
  AIConfidencePanel({super.key});

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Widget confidenceTile(
      String disaster,
      double confidence,
      Color color,
      ) {
    final safeConfidence = confidence.clamp(0.0, 100.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                disaster,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${safeConfidence.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: safeConfidence / 100,
            minHeight: 10,
            borderRadius: BorderRadius.circular(10),
            color: color,
            backgroundColor: Colors.grey.shade300,
          ),
        ],
      ),
    );
  }

  double? _readConfidence(
      Map<String, dynamic> confidence,
      String key,
      ) {
    final value = confidence[key];

    if (value is num) {
      return value.toDouble();
    }

    return null;
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
              'AI Confidence',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _firestore
                  .collection('latest_alerts')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return const Text(
                    'Unable to load confidence data.',
                  );
                }

                final documents = snapshot.data?.docs ?? [];

                final alerts = documents.where((doc) {
                  final data = doc.data();
                  final confidence = data['model_confidence'];

                  return confidence is Map &&
                      confidence.isNotEmpty;
                }).toList();

                if (alerts.isEmpty) {
                  return const Text(
                    'No AI confidence data available yet.',
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: alerts.take(5).map((doc) {
                    final data = doc.data();

                    final district =
                        data['district']?.toString() ?? doc.id;

                    final confidence =
                    Map<String, dynamic>.from(
                      data['model_confidence'] as Map,
                    );

                    final disasterConfidence =
                    _readConfidence(confidence, 'disaster');

                    final severityConfidence =
                    _readConfidence(confidence, 'severity');

                    final floodConfidence =
                    _readConfidence(confidence, 'flood');

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          district,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 14),

                        if (disasterConfidence != null)
                          confidenceTile(
                            'Disaster Type',
                            disasterConfidence,
                            Colors.blue,
                          ),

                        if (severityConfidence != null)
                          confidenceTile(
                            'Severity',
                            severityConfidence,
                            Colors.orange,
                          ),

                        if (floodConfidence != null)
                          confidenceTile(
                            'Flood Risk',
                            floodConfidence,
                            Colors.red,
                          ),

                        const Divider(height: 24),
                      ],
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}