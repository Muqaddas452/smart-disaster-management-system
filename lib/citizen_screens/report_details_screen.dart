import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReportDetailScreen extends StatelessWidget {
  final String reportId;

  const ReportDetailScreen({super.key, required this.reportId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF055C05),
        title: const Text('Report Details', style: TextStyle(color: Colors.white, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('manual_reports').doc(reportId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(
                0xFF065706)));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Report details not found.'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          // Form ki tamam fields
          final String name = data['name'] ?? data['fullName'] ?? 'Not provided';
          final String phone = data['phone'] ?? data['phoneNumber'] ?? 'Not provided';
          final String emergencyType = data['emergencyType'] ?? data['type'] ?? 'General Emergency';
          final String description = data['description'] ?? 'No description';
          final String severity = data['severity'] ?? data['severityLevel'] ?? 'Low';
          final String location = data['location'] ?? data['address'] ?? 'Auto-detected location';
          final String status = data['status'] ?? 'Pending';
          final Timestamp? ts = data['timestamp'];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Status', style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: status.toLowerCase().contains('verified') ? Colors.green.shade100 : Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: status.toLowerCase().contains('verified') ? Colors.green.shade800 : Colors.orange.shade800
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  _detailItem('Your Name', name),
                  const SizedBox(height: 12),
                  _detailItem('Phone Number', phone),
                  const SizedBox(height: 12),
                  _detailItem('Emergency Type', emergencyType),
                  const SizedBox(height: 12),
                  _detailItem('Description of Incident', description),
                  const SizedBox(height: 12),
                  _detailItem('Severity Level', severity),
                  const SizedBox(height: 12),
                  _detailItem('Current Location', location),

                  if (ts != null) ...[
                    const SizedBox(height: 12),
                    _detailItem('Submitted On', ts.toDate().toString().substring(0, 16)),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _detailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w600)),
      ],
    );
  }
}