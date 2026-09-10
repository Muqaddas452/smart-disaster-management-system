import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth_service.dart';
import '../services/fcm_token_service.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // State variables
  final AuthService _authService = AuthService();
  bool isLoading = false;
  bool _passwordVisible = false;
  String? _selectedGender;

  void _onSignUpPressed() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final dob = _dobController.text.trim();
    final password = _passwordController.text;
    final gender = _selectedGender;

    if (name.isEmpty || email.isEmpty || password.isEmpty || dob.isEmpty || gender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields.'), backgroundColor: Colors.red),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() { isLoading = true; });

    // 1. Pass all form fields to AuthService
    bool isSuccess = await _authService.registerCitizen(
      email: email,
      password: password,
      name: name,
      dob: dob,
      gender: gender,
      context: context,
    );

    // 2. Save FCM Token & Navigate ONLY if Registration Succeeded
    if (isSuccess) {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await FcmTokenService.saveFCMToken(currentUser.uid);
        FcmTokenService.listenForTokenRefresh(currentUser.uid);
      }

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/profileCompletion');
      }
    }

    if (mounted) { setState(() { isLoading = false; }); }
  }

  // Color constants
  static const Color _primaryGreen = Color(0xFF2ECC40);
  static const Color _darkGreen = Color(0xFF1B8C1B);
  static const Color _fieldBg = Color(0xFFF0F4F0);
  static const Color _iconColor = Color(0xFF9E9E9E);
  static const Color _hintColor = Color(0xFFAAAAAA);
  static const Color _borderColor = Color(0xFFDDDDDD);

  final List<String> _genderOptions = ['Male', 'Female', 'Other'];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _dobController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Date picker
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: _darkGreen),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dobController.text =
        '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),

                    // Back Button
                    _buildBackButton(context),

                    const SizedBox(height: 20),

                    // Title & Subtitle
                    _buildHeader(),

                    const SizedBox(height: 28),

                    // Full Name Field
                    _buildTextField(
                      controller: _nameController,
                      hint: 'Full Name',
                      icon: Icons.person_outline,
                    ),

                    const SizedBox(height: 14),

                    // Email Field
                    _buildTextField(
                      controller: _emailController,
                      hint: 'Email Address',
                      icon: Icons.mail_outline,
                      keyboardType: TextInputType.emailAddress,
                    ),

                    const SizedBox(height: 14),

                    // Date of Birth Field
                    _buildDateField(context),

                    const SizedBox(height: 14),

                    // Gender Dropdown
                    _buildGenderDropdown(),

                    const SizedBox(height: 14),

                    // Password Field
                    _buildPasswordField(),

                    const SizedBox(height: 20),

                    // Terms & Privacy
                    _buildTermsText(),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            // Bottom Buttons (fixed)
            _buildBottomSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: const Icon(
        Icons.arrow_back_ios,
        size: 22,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: double.infinity),
        Text(
          'Create Account',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: _primaryGreen,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Join the emergency response network',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _fieldBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 15, color: Colors.black87),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: _iconColor, size: 22),
          hintText: hint,
          hintStyle: const TextStyle(color: _hintColor, fontSize: 15),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }

  Widget _buildDateField(BuildContext context) {
    return GestureDetector(
      onTap: () => _selectDate(context),
      child: Container(
        decoration: BoxDecoration(
          color: _fieldBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _borderColor),
        ),
        child: TextField(
          controller: _dobController,
          enabled: false,
          style: const TextStyle(fontSize: 15, color: Colors.black87),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.calendar_today_outlined,
                color: _iconColor, size: 22),
            hintText: 'Date of Birth',
            hintStyle: TextStyle(color: _hintColor, fontSize: 15),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 18),
            disabledBorder: InputBorder.none,
          ),
        ),
      ),
    );
  }

  Widget _buildGenderDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: _fieldBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedGender,
          hint: const Row(
            children: [
              SizedBox(width: 8),
              Icon(Icons.people_outline, color: _iconColor, size: 22),
              SizedBox(width: 12),
              Text(
                'Select Gender',
                style: TextStyle(color: _hintColor, fontSize: 15),
              ),
            ],
          ),
          isExpanded: true,
          icon: const Padding(
            padding: EdgeInsets.only(right: 8.0),
            child: Icon(Icons.keyboard_arrow_down, color: Colors.black54),
          ),
          items: _genderOptions.map((String gender) {
            return DropdownMenuItem<String>(
              value: gender,
              child: Padding(
                padding: const EdgeInsets.only(left: 20.0),
                child: Text(gender,
                    style: const TextStyle(
                        fontSize: 15, color: Colors.black87)),
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() => _selectedGender = newValue);
          },
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return Container(
      decoration: BoxDecoration(
        color: _fieldBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: TextField(
        controller: _passwordController,
        obscureText: !_passwordVisible,
        style: const TextStyle(fontSize: 15, color: Colors.black87),
        decoration: InputDecoration(
          prefixIcon:
          const Icon(Icons.lock_outline, color: _iconColor, size: 22),
          hintText: 'Password',
          hintStyle: const TextStyle(color: _hintColor, fontSize: 15),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
          suffixIcon: GestureDetector(
            onTap: () {
              setState(() => _passwordVisible = !_passwordVisible);
            },
            child: Icon(
              _passwordVisible
                  ? Icons.visibility_outlined
                  : Icons.remove_red_eye_outlined,
              color: _iconColor,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTermsText() {
    return RichText(
      textAlign: TextAlign.center,
      text: const TextSpan(
        style: TextStyle(fontSize: 13, color: Colors.black54),
        children: [
          TextSpan(text: 'By signing up, you agree to our '),
          TextSpan(
            text: 'Terms of Service',
            style: TextStyle(
                color: _primaryGreen, fontWeight: FontWeight.w600),
          ),
          TextSpan(text: ' and\n'),
          TextSpan(
            text: 'Privacy Policy',
            style: TextStyle(
                color: _primaryGreen, fontWeight: FontWeight.w600),
          ),
          TextSpan(text: '.'),
        ],
      ),
    );
  }

  Widget _buildBottomSection(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: isLoading ? null : _onSignUpPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryGreen,
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
                  : const Text(
                'Sign Up',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Already have an account? ',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                },
                child: const Text(
                  'Log In',
                  style: TextStyle(
                    fontSize: 14,
                    color: _primaryGreen,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}