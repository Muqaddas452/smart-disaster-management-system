import 'package:flutter/material.dart'; // Flutter's core UI toolkit
import 'dart:math'; // Needed to generate a random invite code
import 'dart:convert'; // Needed to convert data to JSON format for the API call
import 'package:http/http.dart' as http; // Needed to call the EmailJS API over the internet
import 'package:cloud_firestore/cloud_firestore.dart'; // To save the invitation in Firestore
import 'package:firebase_auth/firebase_auth.dart'; // To get the current logged-in leader's info

class AddMemberScreen extends StatefulWidget {
  final String teamId; // Which team this new member is joining
  final String teamName; // Team's name, needed to show inside the email

  const AddMemberScreen({
    super.key,
    required this.teamId,
    required this.teamName,
  });

  @override
  State<AddMemberScreen> createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends State<AddMemberScreen> {
  static const MaterialColor _primaryGreen = Colors.green; // Theme color

  final _formKey = GlobalKey<FormState>(); // Used to validate the email field
  final TextEditingController _emailController = TextEditingController();

  bool _isSending = false; // True while saving invite + sending email
  bool _emailSentSuccessfully = false; // True once the email is confirmed sent

  // ---- EmailJS credentials (Replace with your actual keys from EmailJS Dashboard) ----
  static const String _emailJsServiceId = 'service_aa63b5q';
  static const String _emailJsTemplateId = 'template_0tnl799'; // Update if you created a new template
  static const String _emailJsPublicKey = 'YIqaYXbMdQUs3ZeL_'; // Copy from EmailJS Account > API Keys

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  // Helper method to validate email address format using standard Regex
  bool _isValidEmail(String email) {
    return RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(email);
  }

  // Generates a random 6-digit invitation code (e.g., "483920")
  String _generateInviteCode() {
    final random = Random();
    final code = 100000 + random.nextInt(900000); // Always exactly 6 digits
    return code.toString();
  }

  // ======================================================
  // LOGIC: Save invite in Firestore, then send code via EmailJS
  // ======================================================
  Future<void> _sendInvite() async {
    if (!_formKey.currentState!.validate()) return; // Stop if form validation fails

    setState(() => _isSending = true);

    try {
      final String email = _emailController.text.trim();
      final String code = _generateInviteCode();

      // STEP 1: Save the invitation record in Firestore
      await FirebaseFirestore.instance.collection('teamInvitations').add({
        'email': email,
        'inviteCode': code,
        'teamId': widget.teamId,
        'status': 'pending',
        'invitedBy': FirebaseAuth.instance.currentUser?.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Fetch leader's display name or email if name isn't set
      final User? currentUser = FirebaseAuth.instance.currentUser;
      final String leaderName = currentUser?.displayName ?? currentUser?.email ?? 'Team Leader';

      // STEP 2: Send the email notification via EmailJS REST API
      final response = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {
          'origin': 'http://localhost', // EmailJS requires this origin header for CORS
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'service_id': _emailJsServiceId,
          'template_id': _emailJsTemplateId,
          'user_id': _emailJsPublicKey, // EmailJS Public Key
          'template_params': {
            // These keys MUST match the {{variable_name}} used in your EmailJS template
            'to_email': email,
            'team_name': widget.teamName,
            'invite_code': code,
            'leader_name': leaderName,
            'app_name': 'Smart Disaster Management System',
          },
        }),
      );

      // Print debug log in Debug Console
      print('EmailJS Status Code: ${response.statusCode}');
      print('EmailJS Response Body: ${response.body}');

      if (response.statusCode == 200) {
        // HTTP 200 indicates successful email dispatch
        setState(() => _emailSentSuccessfully = true);
        _showMessage('Invite sent successfully to $email');
        _emailController.clear(); // Clear input for the next member
      } else {
        // Handle EmailJS processing error
        _showMessage('Invite saved, but email failed (${response.statusCode}). Share code manually: $code');
      }
    } catch (e) {
      _showMessage('Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Add Member'),
        backgroundColor: _primaryGreen.shade800,
        foregroundColor: Colors.white,
      ),
      // Wrapped body with SingleChildScrollView to fix screen bottom overflow when keyboard opens
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),

                  Text(
                    'Invite a Team Member',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _primaryGreen.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),

                  const Text(
                    'Enter their email — an invite code will be sent to them automatically.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                  const SizedBox(height: 28),

                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Member Email',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Email is required';
                      if (!_isValidEmail(value.trim())) return 'Enter a valid email address';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isSending ? null : _sendInvite,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryGreen.shade800,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isSending
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                        'Send Invite',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Success confirmation container
                  if (_emailSentSuccessfully)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _primaryGreen.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _primaryGreen.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: _primaryGreen.shade800),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Invite email sent. You can add another member below.',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}