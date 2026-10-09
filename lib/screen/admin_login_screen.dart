import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'main_layout.dart';
import '../admin/otp_verification_screen.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  bool _resetLoading = false;
  bool _obscurePassword = true;

  // =========================
  // FORGOT PASSWORD
  // =========================
  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter your admin email first."),
        ),
      );
      return;
    }

    setState(() {
      _resetLoading = true;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Password reset email sent. Please check your inbox.",
          ),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message = "Could not send password reset email.";

      switch (e.code) {
        case "invalid-email":
          message = "Please enter a valid email address.";
          break;

        case "user-not-found":
          message = "No account found with this email.";
          break;

        case "too-many-requests":
          message = "Too many requests. Please try again later.";
          break;

        default:
          message = e.message ?? message;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Could not send reset email: $e",
          ),
        ),
      );
    }

    if (mounted) {
      setState(() {
        _resetLoading = false;
      });
    }
  }

  // =========================
  // LOGIN
  // =========================
  Future<void> _login() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Enter email and password"),
        ),
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      // Firebase Authentication
      final credential =
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final uid = credential.user!.uid;

      // Check Admin Document
      final adminDoc = await FirebaseFirestore.instance
          .collection("admins")
          .doc(uid)
          .get();

      if (!adminDoc.exists) {
        throw Exception("Admin account not found.");
      }

      final data = adminDoc.data()!;

      if (data["active"] != true) {
        throw Exception("Admin account is disabled.");
      }

      // Check Two-Factor Authentication
      final twoFactorEnabled =
          data["twoFactorEnabled"] == true;

      if (twoFactorEnabled) {
        try {
          final callable =
          FirebaseFunctions.instance.httpsCallable(
            'sendAdminOtp',
          );

          await callable.call();

          if (!mounted) return;

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => OtpVerificationScreen(
                email: credential.user!.email!,
              ),
            ),
          );

          return;
        } on FirebaseFunctionsException catch (e) {
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                e.message ?? "Could not send OTP.",
              ),
            ),
          );

          await FirebaseAuth.instance.signOut();
          return;
        } catch (e) {
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Could not send OTP: $e",
              ),
            ),
          );

          await FirebaseAuth.instance.signOut();
          return;
        }
      }

      // If 2FA is disabled, go directly to dashboard
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const MainLayout(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      String message = "Login Failed";

      switch (e.code) {
        case "user-not-found":
          message = "User not found";
          break;

        case "wrong-password":
          message = "Wrong password";
          break;

        case "invalid-email":
          message = "Invalid email";
          break;

        case "invalid-credential":
          message = "Invalid email or password";
          break;

        default:
          message = e.message ?? "Authentication failed";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceAll("Exception: ", ""),
          ),
        ),
      );
    }

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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
                  Icons.admin_panel_settings,
                  size: 70,
                  color: Colors.green,
                ),

                const SizedBox(height: 20),

                const Text(
                  "Admin Login",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 30),

                // EMAIL
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: "Email",
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 20),

                // PASSWORD
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: "Password",
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword =
                          !_obscurePassword;
                        });
                      },
                    ),
                  ),
                ),

                // FORGOT PASSWORD
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _resetLoading ? null : _forgotPassword,
                    child: _resetLoading
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                        : const Text(
                      "Forgot Password?",
                      style: TextStyle(
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // LOGIN BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    child: _loading
                        ? const CircularProgressIndicator()
                        : const Text(
                      "Login",
                      style: TextStyle(
                        fontSize: 18,
                      ),
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