// lib/screens/reporte_screen.dart
// Manual Emergency Reporting Screen — Online/Offline support with Auto Sync

import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

import '../database/db_report_helper.dart';
import '../services/report_sync_service.dart';
import 'report_status_screen.dart';
import 'offline_screen.dart';

class ReporteScreen extends StatefulWidget {
  const ReporteScreen({super.key});

  @override
  State<ReporteScreen> createState() => _ReporteScreenState();
}

class _ReporteScreenState extends State<ReporteScreen> {
  // ── Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // ── State
  String? _selectedEmergencyType;
  String _severityLevel = 'Low';
  bool _isSubmitting = false;
  int _unsyncedCount = 0; // Pending local reports ka count

  // ── Location State
  String _autoDetectedLocation = 'Detecting location... Please wait.';
  double? _latitude;
  double? _longitude;

  // ── Connectivity Listener
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // ── Constants
  static const _primaryGreen = Color(0xFF2E7D32);
  static const _lightGreen = Color(0xFFE8F5E9);
  static const _hintGreen = Color(0xFF66BB6A);
  static const _borderGreen = Color(0xFFA5D6A7);
  static const _bgColor = Color(0xFFF5F5F5);

  static const List<String> _emergencyTypes = [
    'Natural Disasters',
    'Earthquake',
    'Flood',
    'Storm',
    'Other',
  ];

  static const List<String> _severityLevels = ['Low', 'Medium', 'High'];

  // ════════════════════════════════════════
  // LIFECYCLE
  // ════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _getUserLocation();
    _loadUnsyncedCount();
    _startConnectivityListener(); // Internet aate hi auto-sync
    _trySyncOnStart();             // App open par bhi sync try karo
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  // ════════════════════════════════════════
  // BACKEND: Pending count load karna
  // ════════════════════════════════════════

  Future<void> _loadUnsyncedCount() async {
    final count = await DBReportHelper.getUnsyncedCount();
    if (mounted) setState(() => _unsyncedCount = count);
  }

  // ════════════════════════════════════════
  // BACKEND: App start par sync try karo
  // ════════════════════════════════════════

  Future<void> _trySyncOnStart() async {
    final result = await ReportSyncService.syncPendingReports();
    if (result.syncedCount > 0 && mounted) {
      _showSnackBar('✅ ${result.syncedCount} offline report(s) synced to Firebase!');
      _loadUnsyncedCount(); // Count update karo
    }
  }

  // ════════════════════════════════════════
  // BACKEND: Connectivity Stream Listener
  // Jaise hi WiFi/Mobile data aaye, sync trigger hoga
  // ════════════════════════════════════════

  void _startConnectivityListener() {
    _connectivitySubscription = ReportSyncService.connectivityStream.listen(
          (results) async {
        final isOnline = results.isNotEmpty &&
            !results.contains(ConnectivityResult.none);

        if (isOnline) {
          final result = await ReportSyncService.syncPendingReports();
          if (result.syncedCount > 0 && mounted) {
            _showSnackBar('📡 ${result.syncedCount} pending report(s) synced automatically!');
            _loadUnsyncedCount();
          }
        }
      },
    );
  }

  // ════════════════════════════════════════
  // BACKEND: GPS Location Auto-Detect
  // ════════════════════════════════════════

  Future<void> _getUserLocation() async {
    // Step 1: GPS service enabled hai?
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await Geolocator.openLocationSettings();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _autoDetectedLocation = 'GPS is disabled. Please turn it on manually.';
          });
        }
        return;
      }
    }

    // Step 2: Permission check
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          setState(() {
            _autoDetectedLocation = 'Location permission denied.';
          });
        }
        return;
      }
    }

    // Step 3: Permanently denied — settings kholna parega
    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        setState(() {
          _autoDetectedLocation =
          'Location permanently denied. Enable from app settings.';
        });
        // App settings kholo
        await Geolocator.openAppSettings();
      }
      return;
    }

    // Step 4: Coordinates fetch karo
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
          _autoDetectedLocation =
          'Lat: ${_latitude!.toStringAsFixed(5)}, Lon: ${_longitude!.toStringAsFixed(5)}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _autoDetectedLocation = 'Could not fetch location. Try again.';
        });
      }
    }
  }

  // ════════════════════════════════════════
  // BACKEND: SUBMIT REPORT
  // ════════════════════════════════════════

  Future<void> _handleSubmit() async {
    // 1. Form validation
    if (!_formKey.currentState!.validate()) return;

    if (_selectedEmergencyType == null) {
      _showSnackBar('Please select an emergency type.', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    // 2. Report data map — Firebase field names match kiye (manual_reports collection)
    final reportData = {
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'emergencyType': _selectedEmergencyType,   // local DB mein
      'description': _descriptionController.text.trim(),
      'severity': _severityLevel,                // local DB mein
      'location': _autoDetectedLocation,
      'latitude': _latitude,
      'longitude': _longitude,
      'timestamp': DateTime.now().toIso8601String(),
    };

    try {
      // 3. Internet check (connectivity_plus 6.x — list return karta hai)
      final connectivityResult = await Connectivity().checkConnectivity();
      final isOnline = connectivityResult.isNotEmpty &&
          !connectivityResult.contains(ConnectivityResult.none);

      if (isOnline) {
        // ── ONLINE: Firestore ko directly bhejo
        final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

        await FirebaseFirestore.instance.collection('manual_reports').add({
          'name': reportData['name'],
          'phone': reportData['phone'],
          'incident_type': reportData['emergencyType'],   // Firebase field
          'description': reportData['description'],
          'severity_level': reportData['severity'],        // Firebase field
          'location': reportData['location'],
          'latitude': reportData['latitude'],
          'longitude': reportData['longitude'],
          'timestamp': FieldValue.serverTimestamp(),       // Firebase proper timestamp
          'localTimestamp': reportData['timestamp'],
          'reportedBy': uid,
          'status': 'Pending',
          'syncedFromOffline': false,
        });

        _showSnackBar('✅ Emergency report submitted successfully!');

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ReportStatusScreen()),
          );
        }
      } else {
        // ── OFFLINE: SQLite mein save karo
        await DBReportHelper.insertReport(reportData);
        await _loadUnsyncedCount(); // Count update karo

        _showSnackBar(
          '📴 No internet! Report saved locally. Will auto-sync when online.',
          isError: true,
        );

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const OfflineStatusScreen()),
          );
        }
      }
    } catch (e) {
      _showSnackBar('Something went wrong: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ════════════════════════════════════════
  // HELPERS
  // ════════════════════════════════════════

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : _primaryGreen,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ════════════════════════════════════════
  // UI BUILD
  // ════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: _buildAppBar(context),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pending sync banner — agar koi local reports hain
                if (_unsyncedCount > 0) _buildSyncBanner(),
                _buildSubtitle(),
                const SizedBox(height: 24),
                _buildLabel('Your Name'),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _nameController,
                  hint: 'Enter your full name',
                  keyboardType: TextInputType.name,
                  validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                ),
                const SizedBox(height: 20),
                _buildLabel('Phone Number'),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _phoneController,
                  hint: 'Enter your phone number',
                  keyboardType: TextInputType.phone,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Phone number is required';
                    }
                    if (v.trim().length < 7) {
                      return 'Enter a valid phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                _buildLabel('Emergency Type'),
                const SizedBox(height: 8),
                _buildDropdown(),
                const SizedBox(height: 20),
                _buildLabel('Description of Incident'),
                const SizedBox(height: 8),
                _buildDescriptionField(),
                const SizedBox(height: 20),
                _buildLabel('Severity Level'),
                const SizedBox(height: 12),
                _buildSeverityRow(),
                const SizedBox(height: 24),
                _buildLabel('Your Current Location (Auto Detected)'),
                const SizedBox(height: 8),
                _buildLocationTile(),
                const SizedBox(height: 32),
                _buildSubmitButton(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Sync Banner — pending reports dikhane k liye
  Widget _buildSyncBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: Colors.orange, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$_unsyncedCount report(s) pending sync. Will upload when internet is available.',
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: _bgColor,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Manual Emergency Reporting',
        style: TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      centerTitle: false,
    );
  }

  Widget _buildSubtitle() {
    return const Text(
      'Please provide details of the incident.',
      style: TextStyle(color: Colors.black54, fontSize: 14),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 15,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14, color: Colors.black87),
      validator: validator,
      decoration: _inputDecoration(hint),
    );
  }

  Widget _buildDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedEmergencyType,
      hint: const Text(
        'Select type of emergency',
        style: TextStyle(color: Colors.black45, fontSize: 14),
      ),
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.black45),
      isExpanded: true,
      decoration: _inputDecoration(null),
      items: _emergencyTypes
          .map(
            (type) => DropdownMenuItem(
          value: type,
          child: Text(type, style: const TextStyle(fontSize: 14)),
        ),
      )
          .toList(),
      onChanged: (val) => setState(() => _selectedEmergencyType = val),
      validator: (v) => v == null ? 'Please select an emergency type' : null,
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      maxLines: 5,
      minLines: 4,
      keyboardType: TextInputType.multiline,
      style: const TextStyle(fontSize: 14, color: Colors.black87),
      validator: (v) =>
      (v == null || v.trim().isEmpty) ? 'Description is required' : null,
      decoration: _inputDecoration('Provide a detailed description of the incident'),
    );
  }

  Widget _buildSeverityRow() {
    return Row(
      children: _severityLevels.map((level) {
        final isSelected = _severityLevel == level;
        return Padding(
          padding: const EdgeInsets.only(right: 20),
          child: GestureDetector(
            onTap: () => setState(() => _severityLevel = level),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Radio<String>(
                  value: level,
                  groupValue: _severityLevel,
                  activeColor: _primaryGreen,
                  onChanged: (val) => setState(() => _severityLevel = val!),
                ),
                Text(
                  level,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? _primaryGreen : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLocationTile() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _lightGreen,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderGreen),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on_rounded, color: _primaryGreen, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _autoDetectedLocation,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
          // Refresh button — location dobara fetch karo
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: _primaryGreen, size: 20),
            onPressed: () {
              setState(() {
                _autoDetectedLocation = 'Detecting location... Please wait.';
              });
              _getUserLocation();
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        onPressed: _isSubmitting ? null : _handleSubmit,
        child: _isSubmitting
            ? const SizedBox(
          height: 22,
          width: 22,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2.5,
          ),
        )
            : const Text(
          'Submit Emergency Report',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String? hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _hintGreen, fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _borderGreen, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primaryGreen, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.8),
      ),
    );
  }
}
