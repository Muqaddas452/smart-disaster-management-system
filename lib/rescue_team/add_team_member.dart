import 'package:flutter/material.dart'; // Flutter's core UI toolkit
import 'dart:math'; // needed to generate a random invite code
import 'dart:convert'; // needed to convert data to JSON format for the API call
import 'package:http/http.dart' as http; // needed to call the EmailJS API over the internet
import 'package:cloud_firestore/cloud_firestore.dart'; // to save the invitation in Firestore
import 'package:firebase_auth/firebase_auth.dart'; // to get the current logged-in leader's info

class AddMemberScreen extends StatefulWidget {
  final String teamId; // which team this new member is joining
  final String teamName; // NEW: team's name, needed to show inside the email

  const AddMemberScreen({
    super.key,
    required this.teamId,
    required this.teamName, // now required, since our email template needs {{team_name}}
  });

  @override
  State<AddMemberScreen> createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends State<AddMemberScreen> {
  static const MaterialColor _primaryGreen = Colors.green; // theme color, same as rest of app

  final _formKey = GlobalKey<FormState>(); // used to validate the email field
  final TextEditingController _emailController = TextEditingController();

  bool _isSending = false; // true while we're saving invite + sending email
  bool _emailSentSuccessfully = false; // true once the email is confirmed sent

  // ---- EmailJS credentials (from your EmailJS account) ----
  static const String _emailJsServiceId = 'service_zajzr6t';
  static const String _emailJsTemplateId = 'template_0lk52dp';
  static const String _emailJsPublicKey = '14-5avHHyg1Gzsbv9';

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(email);
  }

  // generates a random 6-digit code, like "483920"
  String _generateInviteCode() {
    final random = Random();
    final code = 100000 + random.nextInt(900000); // always exactly 6 digits
    return code.toString();
  }

  // ======================================================
  // LOGIC: Save invite in Firestore, then send the code via email
  // ======================================================
  Future<void> _sendInvite() async {
    if (!_formKey.currentState!.validate()) return; // stop if email is invalid

    setState(() => _isSending = true);

    try {
      final String email = _emailController.text.trim();
      final String code = _generateInviteCode();

      // STEP 1: save the invitation in Firestore (same as before)
      await FirebaseFirestore.instance.collection('teamInvitations').add({
        'email': email,
        'inviteCode': code,
        'teamId': widget.teamId,
        'status': 'pending',
        'invitedBy': FirebaseAuth.instance.currentUser?.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // STEP 2: send the actual email using EmailJS's API
      final response = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {
          'origin': 'http://localhost', // EmailJS requires this header to accept the request
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'service_id': _emailJsServiceId,
          'template_id': _emailJsTemplateId,
          'user_id': _emailJsPublicKey, // this is your Public Key
          'template_params': {
            // these keys MUST match exactly what you wrote inside {{ }} in your EmailJS template
            'to_email': email,
            'team_name': widget.teamName,
            'invite_code': code,
          },
        }),
      );

      if (response.statusCode == 200) {
        // 200 means EmailJS successfully accepted and sent the email
        setState(() => _emailSentSuccessfully = true);
        _showMessage('Invite sent successfully to $email');
        _emailController.clear(); // clear the field so leader can invite another member
      } else {
        // something went wrong on EmailJS's side
        _showMessage('Invite saved, but email failed to send. Please share code manually: $code');
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
      body: SafeArea(
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
                        : const Text('Send Invite',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  ),
                ),

                const SizedBox(height: 24),

                // Success confirmation shown after email is sent
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
    );
  }
}