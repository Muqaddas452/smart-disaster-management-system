import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RescueMemberEditProfileScreen extends StatefulWidget {
  const RescueMemberEditProfileScreen({super.key});

  @override
  State<RescueMemberEditProfileScreen> createState() =>
      _RescueMemberEditProfileScreenState();
}

class _RescueMemberEditProfileScreenState
    extends State<RescueMemberEditProfileScreen> {
  static const Color kGreen = Color(0xFF1B5E38);
  static const Color kBgColor = Color(0xFFF7F7F2);

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emergencyPhoneController = TextEditingController();
  final TextEditingController _personalAddressController = TextEditingController();
  final TextEditingController _officialAddressController = TextEditingController();
  final TextEditingController _specializationController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadMemberData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emergencyPhoneController.dispose();
    _personalAddressController.dispose();
    _officialAddressController.dispose();
    _specializationController.dispose();
    super.dispose();
  }

  // ── Firestore se Member Data Load Karna
  Future<void> _loadMemberData() async {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('rescueTeamUsers')
          .doc(uid)
          .get();

      if (doc.exists) {
        final data = doc.data() ?? {};
        setState(() {
          _nameController.text = data['name'] ?? data['fullName'] ?? '';
          _phoneController.text = data['phone'] ?? data['phoneNumber'] ?? '';
          _emergencyPhoneController.text = data['emergencyPhone'] ?? '';
          _personalAddressController.text = data['personalAddress'] ?? data['address'] ?? '';
          _officialAddressController.text = data['officialAddress'] ?? '';
          _specializationController.text = data['specialization'] ?? '';
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error loading profile data: $e', isError: true);
    }
  }

  // ── Updated Profile Data Save Karna
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection('rescueTeamUsers')
          .doc(uid)
          .update({
        'name': _nameController.text.trim(),
        'fullName': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'emergencyPhone': _emergencyPhoneController.text.trim(),
        'personalAddress': _personalAddressController.text.trim(),
        'address': _personalAddressController.text.trim(),
        'officialAddress': _officialAddressController.text.trim(),
        'specialization': _specializationController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        _showSnackBar('Profile updated successfully!');
        Navigator.pop(context);
      }
    } catch (e) {
      _showSnackBar('Failed to update profile: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : kGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: AppBar(
        backgroundColor: kGreen,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kGreen))
          : SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Profile Photo with Camera Icon
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person,
                        size: 65,
                        color: Colors.grey,
                      ),
                    ),
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: kGreen,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.camera_alt,
                              size: 18, color: Colors.white),
                          onPressed: () {
                            _showSnackBar('Photo upload option coming soon');
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── Full Name Field
              _buildFieldLabel('Full Name'),
              _buildInputField(
                controller: _nameController,
                hint: 'Enter full name',
                validator: (val) =>
                val == null || val.trim().isEmpty ? 'Name is required' : null,
              ),

              // ── Phone Number Field
              _buildFieldLabel('Phone Number'),
              _buildInputField(
                controller: _phoneController,
                hint: '+923128164931',
                keyboardType: TextInputType.phone,
                suffixIcon: Icons.smartphone_outlined,
                validator: (val) =>
                val == null || val.trim().isEmpty ? 'Phone number is required' : null,
              ),
              const Padding(
                padding: EdgeInsets.only(left: 4, top: 4, bottom: 12),
                child: Text(
                  'ⓘ Format: +92 300 123 4567 for emergency alerts.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),

              // ── Emergency Contact Field
              _buildFieldLabel('Emergency Contact'),
              _buildInputField(
                controller: _emergencyPhoneController,
                hint: '+923062948343',
                keyboardType: TextInputType.phone,
                suffixIcon: Icons.medical_services_outlined,
              ),

              // ── Personal Address Field
              _buildFieldLabel('Personal Address'),
              _buildInputField(
                controller: _personalAddressController,
                hint: 'Street Masomiya Masjid, Gurrah',
                maxLines: 2,
                suffixIcon: Icons.home_outlined,
              ),

              // ── Official Address Field
              _buildFieldLabel('Official Address'),
              _buildInputField(
                controller: _officialAddressController,
                hint: 'Gurrah Mohallah, Mandi Bahaudin',
                maxLines: 2,
                suffixIcon: Icons.business_outlined,
              ),

              // ── Specialization Field
              _buildFieldLabel('Specialization'),
              _buildInputField(
                controller: _specializationController,
                hint: 'In flood rescue, medical first responder...',
                suffixIcon: Icons.star_outline,
              ),

              const SizedBox(height: 32),

              // ── Save Changes Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 2,
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                    'Save Changes',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 12),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    IconData? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          suffixIcon: suffixIcon != null
              ? Icon(suffixIcon, color: Colors.grey.shade400, size: 20)
              : null,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: kGreen, width: 1.5),
          ),
        ),
      ),
    );
  }
}