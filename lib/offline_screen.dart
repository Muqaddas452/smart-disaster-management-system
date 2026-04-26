import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:smart_disaster_management_system/report_status_screen.dart';


class OfflineStatusScreen extends StatefulWidget {
  const OfflineStatusScreen({super.key});

  @override
  State<OfflineStatusScreen> createState() => _OfflineStatusScreenState();
}

class _OfflineStatusScreenState extends State<OfflineStatusScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotateController;

  @override
  void initState() {
    super.initState();

    // Rotating animation for "Waiting" icon
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // ✅ Auto-listen for internet — jab aaye toh success screen pe jao
    Connectivity().onConnectivityChanged.listen((result) {
      if (!mounted) return;
      final isOnline = result != ConnectivityResult.none;
      if (isOnline) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ReportStatusScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ── No WiFi Icon ──
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  color: Color(0xFFE53935),
                  size: 38,
                ),
              ),

              const SizedBox(height: 40),

              // ── Title ──
              const Text(
                'You are currently offline',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 16),

              // ── Subtitle ──
              const Text(
                'Your disaster report has been saved and is pending submission.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF757575),
                  height: 1.6,
                ),
              ),

              const SizedBox(height: 28),

              // ── Status Badge: Pending ──
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFFFCC02),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.access_time_rounded,
                        color: Color(0xFFFB8C00), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Status: Pending',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFB8C00),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 3),

              // ── Waiting for Internet Button (disabled) ──
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: null, // disabled — auto submit hoga
                  icon: RotationTransition(
                    turns: _rotateController,
                    child: const Icon(Icons.sync_rounded,
                        color: Color(0xFF9E9E9E)),
                  ),
                  label: const Text(
                    'Waiting for Internet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF9E9E9E),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF0F0F0),
                    disabledBackgroundColor: const Color(0xFFF0F0F0),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── Auto submit note ──
              const Text(
                'Your report will be automatically submitted once internet is available.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF9E9E9E),
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}