import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart'; // Used to get the device's real-time GPS location
import '../services/fcm_token_service.dart';

class ProfileCompletionScreen extends StatefulWidget {
  const ProfileCompletionScreen({super.key});

  @override
  State<ProfileCompletionScreen> createState() => _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends State<ProfileCompletionScreen> {
  // Text Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  bool _isLoading = false;
  bool _isFetchingLocation = false; // True while we are getting GPS coordinates from the device

  @override
  void initState() {
    super.initState();
    _fetchExistingName();
  }

  // Pre-fill Name field if it was saved during Sign Up
  Future<void> _fetchExistingName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('citizens').doc(user.uid).get();
      if (doc.exists && doc.data()!.containsKey('name')) {
        setState(() {
          _nameController.text = doc.get('name') ?? '';
        });
      }
    }
  }

  // Gets the user's current GPS position from the device.
  // Returns null if location services/permission are not available, and shows the reason to the user.
  Future<Position?> _getCurrentLocation() async {
    // Step 1: Check if location services (GPS) are turned on for the whole device
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please turn on Location Services to continue.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }

    // Step 2: Check current permission status for this app
    LocationPermission permission = await Geolocator.checkPermission();

    // Step 3: If permission was never asked or was denied once, ask the user again
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission is required to save your address.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return null;
      }
    }

    // Step 4: If user permanently denied permission, they must enable it from phone settings
    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission is permanently denied. Please enable it from phone settings.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }

    // Step 5: Permission is granted, so fetch the actual current position (lat/long)
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return position;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get location: $e'), backgroundColor: Colors.red),
        );
      }
      return null;
    }
  }

  Future<void> _saveProfileToFirestore() async {
    final name = _nameController.text.trim();
    final address = _addressController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty || address.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required (*) fields.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _isFetchingLocation = true; // Show that we are currently fetching GPS location
    });

    // Get the device's current real-time latitude and longitude
    final position = await _getCurrentLocation();

    setState(() {
      _isFetchingLocation = false;
    });

    // If location could not be fetched (permission/service issue), stop here.
    // The _getCurrentLocation() method has already shown the reason via SnackBar.
    if (position == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;

      // 1. Update citizens document for the already logged-in user (uid comes from FirebaseAuth)
      await FirebaseFirestore.instance.collection('citizens').doc(uid).update({
        'name': name,
        'address': address,
        'phone': phone,
        'isProfileComplete': true,
        'latitude': position.latitude, // Real-time GPS latitude
        'longitude': position.longitude, // Real-time GPS longitude
        'locationUpdatedAt': FieldValue.serverTimestamp(), // When the location was last captured
      });

      // 2. Ensure FCM Token is saved & listening on Profile Completion
      await FcmTokenService.saveFCMToken(uid);
      FcmTokenService.listenForTokenRefresh(uid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile verified and completed successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pushReplacementNamed(context, '/citizenHome');
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save profile: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black, size: 28),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Complete Your Profile',
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                      SizedBox(height: screenHeight * 0.04),

                      _buildInputLabel('Full Name', isRequired: true),
                      const SizedBox(height: 8),
                      _buildTextField(controller: _nameController, hintText: 'Enter your full name'),
                      SizedBox(height: screenHeight * 0.025),

                      _buildInputLabel('Email Address', isRequired: false),
                      const SizedBox(height: 8),
                      _buildDisabledEmailField(),
                      SizedBox(height: screenHeight * 0.025),

                      _buildInputLabel('Residential Address (Street, Area, City)', isRequired: true),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _addressController,
                        hintText: 'College Chowk Mandi Bahauddin, Pakistan',
                        maxLines: 3,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Used for emergency identification and rescue routing.',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      SizedBox(height: screenHeight * 0.025),

                      _buildInputLabel('Contact Number', isRequired: true),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _phoneController,
                        hintText: '+92 (300) 123-4567',
                        keyboardType: TextInputType.phone,
                      ),

                      SizedBox(height: screenHeight * 0.06),

                      // Save & Continue Button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _saveProfileToFirestore,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0DCD55),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 2,
                          ),
                          child: _isLoading
                              ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                // Different message depending on which step is currently happening
                                _isFetchingLocation ? 'Getting location...' : 'Saving...',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                            ],
                          )
                              : const Text(
                            'Save & Continue',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInputLabel(String labelText, {required bool isRequired}) {
    return RichText(
      text: TextSpan(
        text: labelText,
        style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w600),
        children: isRequired ? [const TextSpan(text: ' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))] : [],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 15),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.green, width: 2),
        ),
      ),
    );
  }

  Widget _buildDisabledEmailField() {
    final String userEmail = FirebaseAuth.instance.currentUser?.email ?? 'No email found';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(color: const Color(0xFFF0F2F5), borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(userEmail, style: const TextStyle(color: Colors.black87, fontSize: 15)),
          const Icon(Icons.lock, color: Colors.grey, size: 20),
        ],
      ),
    );
  }
}