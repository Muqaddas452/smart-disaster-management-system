import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'profile_updated_screen.dart';

class EditPersonalDetailsScreen extends StatefulWidget {
  const EditPersonalDetailsScreen({super.key});

  @override
  State<EditPersonalDetailsScreen> createState() => _EditPersonalDetailsScreenState();
}

class _EditPersonalDetailsScreenState extends State<EditPersonalDetailsScreen> {
  final String _uid = FirebaseAuth.instance.currentUser!.uid;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  String _selectedGender = 'Male';

  bool _isLoadingData = true;
  bool _isSaving = false;

  // ---- Profile picture state ----
  File? _pickedImageFile;      // newly picked image, not yet uploaded
  String? _photoUrl;           // existing photo URL from Firestore
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentData() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('citizens').doc(_uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        _nameController.text = data['name'] ?? '';
        _phoneController.text = data['phone'] ?? '';
        _dobController.text = data['dob'] ?? data['birthday'] ?? '';
        _addressController.text = data['address'] ?? '';
        _photoUrl = data['photoUrl'];

        String dbGender = data['gender'] ?? 'Male';
        if (['Male', 'Female', 'Other'].contains(dbGender)) {
          _selectedGender = dbGender;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoadingData = false);
    }
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
        // Upload immediately after picking
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
    if (_pickedImageFile == null) return;

    setState(() => _isUploadingPhoto = true);

    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_pictures')
          .child('$_uid.jpg');

      await ref.putFile(_pickedImageFile!);
      final downloadUrl = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('citizens').doc(_uid).update({
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
        String message;
        if (e.code == 'unauthorized' || e.code == 'permission-denied') {
          message = 'Permission denied. Check Firebase Storage rules.';
        } else if (e.plugin == 'firebase_storage' && (e.code == 'object-not-found')) {
          message = 'Upload failed. Please make sure Firebase Storage is enabled for this project.';
        } else {
          message = e.message ?? 'Failed to upload picture.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
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
    if (_nameController.text.trim().isEmpty || _phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name and Phone are required.')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('citizens').doc(_uid).update({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'dob': _dobController.text.trim(),
        'gender': _selectedGender,
        'address': _addressController.text.trim(),
      });

      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ProfileUpdatedScreen()));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E38),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: const Text('Edit Personal Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1B5E38)))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Center(
              child: GestureDetector(
                onTap: _isUploadingPhoto ? null : _showImageSourceSheet,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey.shade300,
                      backgroundImage: _pickedImageFile != null
                          ? FileImage(_pickedImageFile!)
                          : (_photoUrl != null ? NetworkImage(_photoUrl!) : null) as ImageProvider?,
                      child: (_pickedImageFile == null && _photoUrl == null)
                          ? const Icon(Icons.person, size: 60, color: Colors.grey)
                          : null,
                    ),
                    if (_isUploadingPhoto)
                      const Positioned.fill(
                        child: CircleAvatar(
                          backgroundColor: Colors.black45,
                          child: SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          ),
                        ),
                      ),
                    const CircleAvatar(radius: 16, backgroundColor: Color(0xFF1B5E38), child: Icon(Icons.camera_alt, size: 16, color: Colors.white)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 2, blurRadius: 10, offset: const Offset(0, 3))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Full Name'),
                  const SizedBox(height: 6),
                  _buildTextField(controller: _nameController, hintText: 'Enter full name'),
                  const SizedBox(height: 16),
                  _buildLabel('Date of Birth'),
                  const SizedBox(height: 6),
                  _buildTextField(controller: _dobController, hintText: 'DD/MM/YYYY', suffixIcon: Icons.calendar_today),
                  const SizedBox(height: 16),
                  _buildLabel('Gender'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: ['Male', 'Female', 'Other'].contains(_selectedGender) ? _selectedGender : 'Male',
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                    ),
                    items: ['Male', 'Female', 'Other'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                    onChanged: (val) => setState(() => _selectedGender = val!),
                  ),
                  const SizedBox(height: 16),
                  _buildLabel('Phone Number'),
                  const SizedBox(height: 6),
                  _buildTextField(controller: _phoneController, hintText: '+92 300 1234567', keyboardType: TextInputType.phone),
                  const SizedBox(height: 16),
                  _buildLabel('Home Address'),
                  const SizedBox(height: 6),
                  _buildTextField(controller: _addressController, hintText: 'Enter home address', maxLines: 2),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveChanges,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B5E38), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('Save Changes', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String label) => Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87));

  Widget _buildTextField({required TextEditingController controller, required String hintText, TextInputType keyboardType = TextInputType.text, IconData? suffixIcon, int maxLines = 1}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hintText,
        filled: true,
        fillColor: Colors.grey.shade50,
        suffixIcon: suffixIcon != null ? Icon(suffixIcon, color: Colors.black38, size: 20) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      ),
    );
  }
}









