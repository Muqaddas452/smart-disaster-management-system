import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smartdisaster/services/email_verification.dart';

/// "Apni email verify karein" screen.
/// Inbox mein aaya link kholne ke baad yeh screen khud (har 4 second mein)
/// check karti hai aur [onVerified] call karti hai.
class VerifyEmailScreen extends StatefulWidget {
  final VoidCallback onVerified;
  const VerifyEmailScreen({super.key, required this.onVerified});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  static const Color kGreen = Color(0xFF1B5E20);

  Timer? _timer;
  bool _checking = false;
  bool _sending = false;
  int _cooldown = 0; // resend ke beech intezaar (seconds)
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    // Link kholne ke baad user ko kuch dabana na pade.
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _check(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _check({bool silent = false}) async {
    if (_checking) return;
    _checking = true;
    if (!silent && mounted) setState(() {});
    try {
      final user = FirebaseAuth.instance.currentUser;
      await user?.reload();
      final fresh = FirebaseAuth.instance.currentUser;
      if (fresh != null && fresh.emailVerified) {
        _timer?.cancel();
        widget.onVerified();
        return;
      }
      if (!silent) _snack('Email abhi verify nahi hui. Inbox (aur Spam) mein link kholein.');
    } catch (e) {
      if (!silent) _snack('Check nahi ho saka: $e');
    } finally {
      _checking = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _resend() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _sending || _cooldown > 0) return;
    setState(() => _sending = true);
    final ok = await sendVerificationEmail(user);
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) {
      _snack('Verification link dobara bhej diya gaya.');
      setState(() => _cooldown = 60);
      _cooldownTimer?.cancel();
      _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return t.cancel();
        setState(() => _cooldown = _cooldown - 1);
        if (_cooldown <= 0) t.cancel();
      });
    } else {
      _snack('Abhi dobara nahi bheja ja sakta. Thori dair baad try karein.');
    }
  }

  Future<void> _signOut() async {
    _timer?.cancel();
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                child: const Icon(Icons.mark_email_unread_outlined, size: 44, color: kGreen),
              ),
              const SizedBox(height: 24),
              const Text('Verify your email',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(
                'We sent a verification link to\n$email\n\nOpen it from your inbox (check Spam too) to continue. '
                    'This confirms the email really belongs to you.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54, height: 1.4),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _checking ? null : () => _check(),
                  child: _checking
                      ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text("I've verified my email",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: (_sending || _cooldown > 0) ? null : _resend,
                child: Text(_cooldown > 0 ? 'Resend link in ${_cooldown}s' : 'Resend verification link'),
              ),
              TextButton(
                onPressed: _signOut,
                child: const Text('Use a different account / Sign out',
                    style: TextStyle(color: Colors.black54)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
