import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../screen/main_layout.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;

  const OtpVerificationScreen({
    super.key,
    required this.email,
  });

  @override
  State<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState
    extends State<OtpVerificationScreen> {
  final _otpController = TextEditingController();

  bool _loading = false;

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();

    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter the 6-digit OTP"),
        ),
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final callable =
      FirebaseFunctions.instance.httpsCallable('verifyAdminOtp');

      final result = await callable.call({
        'otp': otp,
      });

      if (!mounted) return;

      if (result.data['success'] == true) {
        // OTP verified successfully.
        // Now open the existing Admin Dashboard.
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const MainLayout(),
          ),
              (route) => false,
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'not-found':
          message = "OTP not found. Please request a new OTP.";
          break;

        case 'deadline-exceeded':
          message = "OTP has expired. Please request a new OTP.";
          break;

        case 'permission-denied':
          message = "Invalid OTP. Please try again.";
          break;

        case 'invalid-argument':
          message = "Please enter a valid 6-digit OTP.";
          break;

        default:
          message = e.message ?? "OTP verification failed.";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Something went wrong. Please try again."),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F7FA),
      body: Center(
        child: Card(
          elevation: 8,
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.security,
                  size: 70,
                  color: Colors.green,
                ),

                const SizedBox(height: 20),

                const Text(
                  "Two-Factor Authentication",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 15),

                Text(
                  "Enter the 6-digit code sent to\n${widget.email}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.grey,
                  ),
                ),

                const SizedBox(height: 25),

                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    labelText: "Enter OTP",
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                    counterText: "",
                  ),
                ),

                const SizedBox(height: 25),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _verifyOtp,
                    child: _loading
                        ? const CircularProgressIndicator()
                        : const Text(
                      "Verify OTP",
                      style: TextStyle(fontSize: 18),
                    ),
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