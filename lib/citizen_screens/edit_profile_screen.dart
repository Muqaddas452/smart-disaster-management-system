import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore read/write k liye
import 'package:firebase_auth/firebase_auth.dart'; // current user ki UID k liye
import 'profile_updated_screen.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  // current logged-in citizen ki UID
  final String _uid = FirebaseAuth.instance.currentUser!.uid;

  // CHANGED: controllers ab khali bana rahe hain — inko data
  // _loadCurrentData() function bharay ga, jab Firestore se current
  // profile fetch ho jaye ga (pehle hardcoded 'Haroon Ali' waghera tha)
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  // NEW: emergency contact k 3 naye fields k controllers
  final TextEditingController _emNameController = TextEditingController();
  final TextEditingController _emPhoneController = TextEditingController();
  final TextEditingController _emRelationController = TextEditingController();

  bool _isLoadingData = true; // jab tak current profile fetch ho rahi h
  bool _isSaving = false; // jab Save button dabne k baad Firestore write ho rahi h

  @override
  void initState() {
    super.initState();
    _loadCurrentData(); // screen khulte hi current profile data fetch karna
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emNameController.dispose();
    _emPhoneController.dispose();
    _emRelationController.dispose();
    super.dispose();
  }

  // ========================================================
  // NEW: Firestore se current profile data fetch kr k fields
  // ko pre-fill karna, taake user ko purana data khali na dikhe
  // ========================================================
  Future<void> _loadCurrentData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('citizens')
          .doc(_uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        _nameController.text = data['name'] ?? '';
        _phoneController.text = data['phone'] ?? '';
        _emNameController.text = data['emergencyContactName'] ?? '';
        _emPhoneController.text = data['emergencyContactPhone'] ?? '';
        _emRelationController.text = data['emergencyContactRelation'] ?? '';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load profile: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingData = false;
        });
      }
    }
  }

  // ========================================================
  // CHANGED: ab ye function sirf navigate nahi karta, balki
  // asal mein Firestore k 'citizens/{uid}' document ko update
  // karta h, phir hi success screen pe jata h
  // ========================================================
  Future<void> _saveChanges() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final emName = _emNameController.text.trim();
    final emPhone = _emPhoneController.text.trim();
    final emRelation = _emRelationController.text.trim();

    // basic validation — Full Name aur Phone Number required hain
    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Full Name and Phone Number are required.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await FirebaseFirestore.instance.collection('citizens').doc(_uid).update({
        'name': name,
        'phone': phone,
        // emergency contact fields — agar khali chore diye, empty string
        // save hogi, ViewProfileScreen usay khud "not added yet" treat
        // kar leta h
        'emergencyContactName': emName,
        'emergencyContactPhone': emPhone,
        'emergencyContactRelation': emRelation,
      });

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProfileUpdatedScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save changes: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5E8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E38),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      // CHANGED: jab tak current data load ho raha h, spinner dikhana —
      // taake user khali fields na dekhe jo abhi load ho rahe hain
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 16),

            // Profile Avatar with edit option
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 54,
                  backgroundColor: Colors.grey.shade300,
                  child: const Icon(Icons.person, size: 58, color: Colors.grey),
                ),
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFF1B5E38),
                  child: const Icon(Icons.camera_alt,
                      size: 16, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Full Name Field
            _buildLabel('Full Name'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _nameController,
              hintText: 'Enter full name',
            ),
            const SizedBox(height: 20),

            // Phone Number Field
            _buildLabel('Phone Number'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _phoneController,
              hintText: '+92 300 1234567',
              keyboardType: TextInputType.phone,
              suffixIcon: Icons.smartphone,
            ),
            const SizedBox(height: 4),
            const Align(
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 13, color: Colors.black45),
                  SizedBox(width: 4),
                  Text(
                    'Format: +92 300 123 4567 for emergency alerts.',
                    style: TextStyle(fontSize: 12, color: Colors.black45),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // NEW: Emergency Contact section — divider + heading
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'EMERGENCY CONTACT',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 16),

            _buildLabel('Contact Name'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _emNameController,
              hintText: 'e.g. Ali Ahmmed',
            ),
            const SizedBox(height: 20),

            _buildLabel('Contact Phone'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _emPhoneController,
              hintText: '+92 301 9876543',
              keyboardType: TextInputType.phone,
              suffixIcon: Icons.smartphone,
            ),
            const SizedBox(height: 20),

            _buildLabel('Relation'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _emRelationController,
              hintText: 'e.g. Brother, Sister, Parent',
            ),
            const SizedBox(height: 40),

            // Save Changes Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                // CHANGED: jab tak save ho raha h, button disable
                // rehta h taake user double-tap se do baar save na
                // kar de
                onPressed: _isSaving ? null : _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E38),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
                    : const Text(
                  'Save Changes',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Cancel Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: _isSaving ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: BorderSide.none,
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: Color(0xFF1B5E38),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    IconData? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hintText,
        filled: true,
        fillColor: Colors.white,
        suffixIcon: suffixIcon != null
            ? Icon(suffixIcon, color: Colors.black38, size: 20)
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}













