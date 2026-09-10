import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'member_register_screen.dart';

class MemberVerificationScreen extends StatefulWidget {
  const MemberVerificationScreen({super.key});

  @override
  State<MemberVerificationScreen> createState() => _MemberVerificationScreenState();
}

class _MemberVerificationScreenState extends State<MemberVerificationScreen> {
  static const Color primaryGreen = Color(0xFF1B5E20);

  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verifyCode() async {
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();

    if (email.isEmpty || code.isEmpty) {
      _showMessage('Please enter both Email and 6-Digit Code');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('teamInvitations')
          .where('email', isEqualTo: email)
          .where('inviteCode', isEqualTo: code)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final inviteDoc = querySnapshot.docs.first;
        final inviteData = inviteDoc.data();

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MemberRegisterScreen(
                email: email,
                teamId: inviteData['teamId'] ?? '',
                teamName: inviteData['teamName'] ?? 'Rescue Team',
                invitationId: inviteDoc.id,
              ),
            ),
          );
        }
      } else {
        _showMessage('Invalid code or email. Please check and try again.');
      }
    } catch (e) {
      _showMessage('Verification error: $e');
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
        title: const Text('Member Verification'),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Icon(Icons.verified_user_outlined, size: 64, color: primaryGreen),
            const SizedBox(height: 12),
            const Text(
              'Verify Invitation Code',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryGreen),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter your email address and 6-digit code provided by your Team Leader.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: '6-Digit Invite Code',
                prefixIcon: Icon(Icons.pin),
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _verifyCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Verify Code & Proceed', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}