import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  // ========================================================
  // BACKEND LOGIC: PROFILE DATA KO ALAG COLLECTION MIEN SAVE KRNA
  // ========================================================
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
    });

    try {
      // Current user ki UID nikalna
      String uid = FirebaseAuth.instance.currentUser!.uid;
      String? email = FirebaseAuth.instance.currentUser!.email;

      // STEP 1: 'Profiles' naam ki alag collection mien data save krna
      // Agar yeh collection nahi bani hui, to Firebase isay khud bana de ga
      await FirebaseFirestore.instance.collection('Profiles').doc(uid).set({
        'uid': uid,
        'full_name': name,
        'residential_address': address,
        'contact_number': phone,
        'email': email, // Reference k liye auth se email b save krwa di
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // STEP 2: Main 'Users' collection mien verification status true krna
      await FirebaseFirestore.instance.collection('Users').doc(uid).update({
        'isProfileComplete': true,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile verified and completed successfully!'), backgroundColor: Colors.green),
        );
        // Direct Citizen Home Screen pr navigate krna
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
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
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

                        const Spacer(),

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
                                ? const CircularProgressIndicator(color: Colors.white)
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
              ),
            );
          },
        ),
      ),
    );
  }

  // Label UI Helper
  Widget _buildInputLabel(String labelText, {required bool isRequired}) {
    return RichText(
      text: TextSpan(
        text: labelText,
        style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w600),
        children: isRequired ? [const TextSpan(text: ' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))] : [],
      ),
    );
  }

  // TextField UI Helper
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

  // Email Disabled UI Helper
  Widget _buildDisabledEmailField() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(color: const Color(0xFFF0F2F5), borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: const [
          Text('Enter your email', style: TextStyle(color: Colors.grey, fontSize: 15)),
          Icon(Icons.lock, color: Colors.grey, size: 20),
        ],
      ),
    );
  }
}