import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'pending_approval_screen.dart';

class RescueRegistrationScreen extends StatefulWidget {
  const RescueRegistrationScreen({super.key});

  @override
  State<RescueRegistrationScreen> createState() => _RescueRegistrationScreenState();
}

class _RescueRegistrationScreenState extends State<RescueRegistrationScreen> {
  static const Color primaryGreen = Color(0xFF1B5E20);

  final _registerFormKey = GlobalKey<FormState>();
  final TextEditingController _teamNameController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();
  final TextEditingController _specializationController = TextEditingController();
  final TextEditingController _leaderNameController = TextEditingController();
  final TextEditingController _leaderEmailController = TextEditingController();
  final TextEditingController _leaderPasswordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _membersCountController = TextEditingController(text: '1');

  String _selectedTeamType = 'Fire';
  String _selectedVehicle = 'Ambulance';
  bool _isRegistering = false;

  @override
  void dispose() {
    _teamNameController.dispose();
    _areaController.dispose();
    _specializationController.dispose();
    _leaderNameController.dispose();
    _leaderEmailController.dispose();
    _leaderPasswordController.dispose();
    _phoneController.dispose();
    _membersCountController.dispose();
    super.dispose();
  }

  Future<Position?> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showError('Location services are disabled. Please turn on GPS.');
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showError('Location permission is required to register team.');
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showError('Location permission is permanently denied.');
      return null;
    }

    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  Future<void> _registerNewTeam() async {
    if (!_registerFormKey.currentState!.validate()) return;

    setState(() => _isRegistering = true);

    try {
      final Position? position = await _getCurrentLocation();
      if (position == null) {
        setState(() => _isRegistering = false);
        return;
      }

      final UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _leaderEmailController.text.trim(),
        password: _leaderPasswordController.text.trim(),
      );

      final String uid = userCredential.user!.uid;
      await userCredential.user!.updateDisplayName(_leaderNameController.text.trim());

      final teamDocRef = FirebaseFirestore.instance.collection('rescueTeams').doc();
      final String teamId = teamDocRef.id;

      final WriteBatch batch = FirebaseFirestore.instance.batch();

      batch.set(teamDocRef, {
        'teamId': teamId,
        'teamName': _teamNameController.text.trim(),
        'teamType': _selectedTeamType,
        'specialization': _specializationController.text.trim(),
        'assignedArea': _areaController.text.trim(),
        'leaderUid': uid,
        'leader': _leaderNameController.text.trim(),
        'leaderName': _leaderNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'vehicle': _selectedVehicle,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'members': int.tryParse(_membersCountController.text.trim()) ?? 1,
        'availability': 'Available',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      batch.set(FirebaseFirestore.instance.collection('rescueTeamUsers').doc(uid), {
        'uid': uid,
        'name': _leaderNameController.text.trim(),
        'email': _leaderEmailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'specialization': _specializationController.text.trim(),
        'teamId': teamId,
        'teamName': _teamNameController.text.trim(),
        'role': 'rescue_leader',
        'isLeader': true,
        'status': 'pending',
        'latitude': position.latitude,
        'longitude': position.longitude,
        'createdAt': FieldValue.serverTimestamp(),
      });

      batch.set(FirebaseFirestore.instance.collection('authIndex').doc(uid), {
        'uid': uid,
        'email': _leaderEmailController.text.trim(),
        'role': 'rescue_leader',
        'collection': 'rescueTeamUsers',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const PendingApprovalScreen()),
        );
      }
    } catch (e) {
      _showError('Registration failed: $e');
    } finally {
      if (mounted) setState(() => _isRegistering = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Register Rescue Team'),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _registerFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _teamNameController,
                decoration: const InputDecoration(labelText: 'Team Name', border: OutlineInputBorder()),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedTeamType,
                decoration: const InputDecoration(labelText: 'Team Type', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'Fire', child: Text('Fire Rescue')),
                  DropdownMenuItem(value: 'Medical', child: Text('Medical Rescue')),
                  DropdownMenuItem(value: 'Flood', child: Text('Flood Rescue')),
                  DropdownMenuItem(value: 'General', child: Text('General Rescue')),
                ],
                onChanged: (v) => setState(() => _selectedTeamType = v!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _specializationController,
                decoration: const InputDecoration(labelText: 'Specialization', border: OutlineInputBorder()),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _areaController,
                decoration: const InputDecoration(labelText: 'Operating Area / City', border: OutlineInputBorder()),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _leaderNameController,
                decoration: const InputDecoration(labelText: 'Leader Full Name', border: OutlineInputBorder()),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _membersCountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Number of Team Members', border: OutlineInputBorder()),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _leaderEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Leader Email', border: OutlineInputBorder()),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Contact Number', border: OutlineInputBorder()),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedVehicle,
                decoration: const InputDecoration(labelText: 'Vehicle Type', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'Ambulance', child: Text('Ambulance')),
                  DropdownMenuItem(value: 'Truck', child: Text('Truck')),
                  DropdownMenuItem(value: 'Boat', child: Text('Boat')),
                  DropdownMenuItem(value: 'None', child: Text('None')),
                ],
                onChanged: (v) => setState(() => _selectedVehicle = v!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _leaderPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                validator: (v) => v == null || v.length < 6 ? 'Min 6 characters' : null,
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isRegistering ? null : _registerNewTeam,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isRegistering
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Register Team Leader', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}