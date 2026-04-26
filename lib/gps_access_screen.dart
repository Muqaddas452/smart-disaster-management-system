import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

// gps_access_screen.dart

class GpsAccessScreen extends StatelessWidget {
  const GpsAccessScreen({super.key});

  static const _primaryGreen = Color(0xFF4CAF50);
  static const _lightGreen = Color(0xFFE8F5E9);
  static const _darkGreen = Color(0xFF1B5E20);

  Future<void> _requestLocationPermission(BuildContext context) async {
    // Step 1:get permission
    final status = await Permission.location.request();

    if (!context.mounted) return;

    if (status.isGranted) {
      //if get Permission then go in report screen
      Navigator.pop(context, true); // true = permission granted
    } else if (status.isPermanentlyDenied) {
      //Permanently denied
      await openAppSettings();
    } else {
      // Denied
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location permission is required for emergency reporting.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.black87),
          onPressed: () => Navigator.pop(context, false),
        ),
        title: const Text(
          'Disaster Management',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ── GPS Icon ──
              Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(
                  color: _lightGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: _primaryGreen,
                  size: 58,
                ),
              ),

              const SizedBox(height: 32),

              // ── Title ──
              const Text(
                'Enable GPS Access',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 16),

              // ── Subtitle ──
              const Text(
                'GPS access is not enabled. Please turn on your location services to proceed with auto-location detection.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF757575),
                  height: 1.6,
                ),
              ),

              const Spacer(flex: 3),

              // ── Allow Button ──
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _requestLocationPermission(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Allow Location Access',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Cancel ──
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF757575),
                    fontWeight: FontWeight.w500,
                  ),
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