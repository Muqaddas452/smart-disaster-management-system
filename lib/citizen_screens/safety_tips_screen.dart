import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:smart_disaster_management_system/database/citizen_dao.dart'; // adjust path if needed

// UI and PDF-opening logic are exactly the same as before. The only
// addition: tips are now shown instantly from the SQLite cache (works
// offline too), then silently refreshed + re-cached whenever the live
// Firestore stream has new data.
class SafetyTipsScreen extends StatefulWidget {
  const SafetyTipsScreen({super.key});

  @override
  State<SafetyTipsScreen> createState() => _SafetyTipsScreenState();
}

class _SafetyTipsScreenState extends State<SafetyTipsScreen> {
  List<Map<String, dynamic>> _tips = [];
  bool _loadedOnce = false;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // 1) Show cache immediately — this works even with zero internet.
    final cached = await CitizenDao.getCachedSafetyTips();
    if (cached.isNotEmpty && mounted) {
      setState(() {
        _tips = cached;
        _loadedOnce = true;
      });
    }

    // 2) Live Firestore stream — same query as the original StreamBuilder,
    // just now we cache the results and call setState ourselves.
    _sub = FirebaseFirestore.instance
        .collection('safety_tips')
        .snapshots()
        .listen((snap) async {
      final tips = snap.docs.map((d) {
        final data = d.data();
        return {
          'docId': d.id,
          'title': data['title'] ?? 'No Title',
          'pdfUrl': data['pdf_url'] ?? '',
        };
      }).toList();

      await CitizenDao.cacheSafetyTips(tips);
      if (mounted) {
        setState(() {
          _tips = tips;
          _loadedOnce = true;
        });
      }
    }, onError: (_) {
      // Offline — the cached list is already showing, nothing to do here.
      if (mounted) setState(() => _loadedOnce = true);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

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
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (!_loadedOnce) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    if (_tips.isEmpty) {
      return const Center(
        child: Text("Koi Guidelines majood nahi hain.", style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      itemCount: _tips.length,
      itemBuilder: (context, index) {
        final data = _tips[index];

        // Extracting fields from Firestore/cache
        String title = data['title'] ?? 'No Title';
        String pdfUrl = data['pdfUrl'] ?? '';

        // Dummy date for representation (use Firestore's date here if available)
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
  }
}