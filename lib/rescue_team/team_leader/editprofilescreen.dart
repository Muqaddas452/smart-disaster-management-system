import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../profile_updated_screen.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emergencyPhoneController = TextEditingController();
  final TextEditingController _personalAddressController = TextEditingController();
  final TextEditingController _officialAddressController = TextEditingController();
  final TextEditingController _specializationController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _uid;

  // ---- Profile picture state ----
  File? _pickedImageFile;
  String? _photoUrl;
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    _uid = uid;

    if (uid == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('rescueTeamUsers')
          .doc(uid)
          .get();

      if (doc.exists) {
        final data = doc.data() ?? {};
        _nameController.text = data['name'] ?? '';
        _phoneController.text = data['phone'] ?? '';
        _emergencyPhoneController.text = data['emergencyPhone'] ?? '';
        _personalAddressController.text = data['personalAddress'] ?? '';
        _officialAddressController.text = data['officialAddress'] ?? '';
        _specializationController.text = data['specialization'] ?? '';
        _photoUrl = data['photoUrl'];
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load profile: $e')),
        );
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // ---- Pick image from gallery or camera ----
  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (picked != null) {
        setState(() {
          _pickedImageFile = File(picked.path);
        });
        await _uploadProfilePicture();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick image: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFF1B5E38)),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFF1B5E38)),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ---- Upload picked image to Firebase Storage & save URL to Firestore ----
  Future<void> _uploadProfilePicture() async {
    if (_pickedImageFile == null || _uid == null) return;

    setState(() => _isUploadingPhoto = true);

    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('rescue_profile_pictures')
          .child('$_uid.jpg');

      await ref.putFile(_pickedImageFile!);
      final downloadUrl = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('rescueTeamUsers').doc(_uid).update({
        'photoUrl': downloadUrl,
      });

      if (mounted) {
        setState(() {
          _photoUrl = downloadUrl;
          _pickedImageFile = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated!'), backgroundColor: Colors.green),
        );
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Failed to upload picture.'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload picture: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _saveChanges() async {
    if (_uid == null) return;

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and Phone Number cannot be empty')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection('rescueTeamUsers')
          .doc(_uid)
          .update({
        'name': name,
        'phone': phone,
        'emergencyPhone': _emergencyPhoneController.text.trim(),
        'personalAddress': _personalAddressController.text.trim(),
        'officialAddress': _officialAddressController.text.trim(),
        'specialization': _specializationController.text.trim(),
      });

      if (!mounted) return;

      // Navigate to the shared confirmation screen (same one citizen flow uses)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ProfileUpdatedScreen()),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1B5E38)))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 16),

            // Profile Avatar with edit option
            GestureDetector(
              onTap: _isUploadingPhoto ? null : _showImageSourceSheet,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 54,
                    backgroundColor: Colors.grey.shade300,
                    backgroundImage: _pickedImageFile != null
                        ? FileImage(_pickedImageFile!)
                        : (_photoUrl != null ? NetworkImage(_photoUrl!) : null) as ImageProvider?,
                    child: (_pickedImageFile == null && _photoUrl == null)
                        ? const Icon(Icons.person, size: 58, color: Colors.grey)
                        : null,
                  ),
                  if (_isUploadingPhoto)
                    const Positioned.fill(
                      child: CircleAvatar(
                        backgroundColor: Colors.black45,
                        child: SizedBox(
                          height: 24, width: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        ),
                      ),
                    ),
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFF1B5E38),
                    child: const Icon(Icons.camera_alt,
                        size: 16, color: Colors.white),
                  ),
                ],
              ),
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.info_outline, size: 13, color: Colors.black45),
                ),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Format: +92 300 123 4567 for emergency alerts.',
                    style: TextStyle(fontSize: 12, color: Colors.black45),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Emergency Contact Field
            _buildLabel('Emergency Contact'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _emergencyPhoneController,
              hintText: '+92 300 1234567',
              keyboardType: TextInputType.phone,
              suffixIcon: Icons.emergency_outlined,
            ),
            const SizedBox(height: 20),

            // Personal Address Field
            _buildLabel('Personal Address'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _personalAddressController,
              hintText: 'Enter your home address',
              suffixIcon: Icons.home_outlined,
              maxLines: 2,
            ),
            const SizedBox(height: 20),

            // Official Address Field
            _buildLabel('Official Address'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _officialAddressController,
              hintText: 'Enter your office / HQ address',
              suffixIcon: Icons.business_outlined,
              maxLines: 2,
            ),
            const SizedBox(height: 20),

            // Specialization Field
            _buildLabel('Specialization'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _specializationController,
              hintText: 'e.g. Search & Rescue, First Aid',
              suffixIcon: Icons.star_outline,
            ),
            const SizedBox(height: 40),

            // Save Changes Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E38),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5),
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
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
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