import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class SafetyTipsScreen extends StatelessWidget {
  // Const constructor add kar diya hai
  const SafetyTipsScreen({super.key});

  // Function to open PDF URL in External Browser/Application
  Future<void> _openPDFLink(BuildContext context, String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (await launchUrl(url, mode: LaunchMode.externalApplication)) {
        // Successfully launched
      } else {
        throw 'Could not launch $urlString';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("PDF open karne mien masla aaya: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12161A), // Dark background matching your UI
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1F24),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "GuideLines",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.archive_outlined, color: Colors.white),
            onPressed: () {},
          )
        ],
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Firestore ki 'safety_tips' collection se live data fetch ho raha hai
        stream: FirebaseFirestore.instance.collection('safety_tips').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.white)));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Text("Koi Guidelines majood nahi hain.", style: TextStyle(color: Colors.grey)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;

              // Firestore fields extract kar rahe hain
              String title = data['title'] ?? 'No Title';
              String pdfUrl = data['pdf_url'] ?? '';

              // Dummy date for representation (agar firestore mien date hai toh wo use kar lein)
              String dateText = "2026-06-16";

              return GestureDetector(
                onTap: () {
                  if (pdfUrl.isNotEmpty) {
                    _openPDFLink(context, pdfUrl);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Is guideline ka link majood nahi hai.")),
                    );
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E252B), // Dark Card background
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white10, width: 0.5),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Side: Image Placeholder
                      Container(
                        width: 70,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 30),
                      ),
                      const SizedBox(width: 12),

                      // Center & Right Side: Title, Date and PDF Icon
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 20),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  dateText,
                                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                                ),
                              ],
                            ),
                            Align(
                              alignment: Alignment.bottomRight,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                child: const Text(
                                  "PDF",
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 8,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}