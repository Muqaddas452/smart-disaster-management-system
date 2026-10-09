import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'rescue_home_screen.dart'; // Home screen import added

class MemberRegisterScreen extends StatefulWidget {
  final String email;
  final String teamId;
  final String teamName;
  final String invitationId;

  const MemberRegisterScreen({
    super.key,
    required this.email,
    required this.teamId,
    required this.teamName,
    required this.invitationId,
  });

  @override
  State<MemberRegisterScreen> createState() => _MemberRegisterScreenState();
}

class _MemberRegisterScreenState extends State<MemberRegisterScreen> {
  static const Color primaryGreen = Color(0xFF1B5E20);
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  final _personalAddressController = TextEditingController();
  final _officialAddressController = TextEditingController();
  final _specializationController = TextEditingController();
  final _passwordController = TextEditingController();

  String _selectedBloodGroup = 'A+';
  bool _isLoading = false;

  final List<String> _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emergencyPhoneController.dispose();
    _personalAddressController.dispose();
    _officialAddressController.dispose();
    _specializationController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<Position?> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showMessage('Please turn on GPS/Location services.');
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showMessage('Location permission is required.');
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showMessage('Location permission permanently denied.');
      return null;
    }

    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  Future<void> _registerMember() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final Position? position = await _getCurrentLocation();
      if (position == null) {
        setState(() => _isLoading = false);
        return;
      }

      final UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: widget.email,
        password: _passwordController.text.trim(),
      );

      final String uid = userCredential.user!.uid;
      await userCredential.user!.updateDisplayName(_nameController.text.trim());

      final WriteBatch batch = FirebaseFirestore.instance.batch();

      batch.set(FirebaseFirestore.instance.collection('rescueTeamUsers').doc(uid), {
        'uid': uid,
        'name': _nameController.text.trim(),
        'email': widget.email,
        'phone': _phoneController.text.trim(),
        'emergencyPhone': _emergencyPhoneController.text.trim(),
        'personalAddress': _personalAddressController.text.trim(),
        'officialAddress': _officialAddressController.text.trim(),
        'specialization': _specializationController.text.trim(),
        'bloodGroup': _selectedBloodGroup,
        'role': 'rescue_member',
        'isLeader': false,
        'teamId': widget.teamId,
        'teamName': widget.teamName,
        'status': 'active',
        'latitude': position.latitude,
        'longitude': position.longitude,
        'createdAt': FieldValue.serverTimestamp(),
      });

      batch.set(FirebaseFirestore.instance.collection('authIndex').doc(uid), {
        'uid': uid,
        'email': widget.email,
        'role': 'rescue_member',
        'collection': 'rescueTeamUsers',
        'createdAt': FieldValue.serverTimestamp(),
      });

      batch.update(
        FirebaseFirestore.instance.collection('teamInvitations').doc(widget.invitationId),
        {'status': 'accepted', 'acceptedAt': FieldValue.serverTimestamp()},
      );

      await batch.commit();

      _showMessage('Registration completed successfully!');

      if (mounted) {
        // Navigate directly to Home Screen and clear previous route stack
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => RescueTeamHomeScreen(
              isLeader: false, // Hide Add Member option in navigation
              teamId: widget.teamId,
              teamName: widget.teamName,
            ),
          ),
              (route) => false,
        );
      }
    } catch (e) {
      _showMessage('Registration error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Member Registration'),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Joining Team: ${widget.teamName}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryGreen),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  initialValue: widget.email,
                  enabled: false,
                  decoration: const InputDecoration(labelText: 'Verified Email', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _specializationController,
                  decoration: const InputDecoration(labelText: 'Specialization', border: OutlineInputBorder()),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder()),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emergencyPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Emergency Phone', border: OutlineInputBorder()),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _personalAddressController,
                  decoration: const InputDecoration(labelText: 'Personal Address', border: OutlineInputBorder()),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedBloodGroup,
                  decoration: const InputDecoration(labelText: 'Blood Group', border: OutlineInputBorder()),
                  items: _bloodGroups.map((bg) => DropdownMenuItem(value: bg, child: Text(bg))).toList(),
                  onChanged: (val) => setState(() => _selectedBloodGroup = val!),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Create Password', border: OutlineInputBorder()),
                  validator: (v) => v == null || v.length < 6 ? 'Min 6 characters' : null,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _registerMember,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Complete Registration', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}