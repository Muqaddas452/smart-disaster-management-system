import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccountSettingsCard extends StatefulWidget {
  const AccountSettingsCard({super.key});

  @override
  State<AccountSettingsCard> createState() =>
      _AccountSettingsCardState();
}

class _AccountSettingsCardState
    extends State<AccountSettingsCard> {
  bool twoFactor = false;
  bool rememberLogin = true;

  bool _loadingPreferences = true;
  bool _sendingResetEmail = false;
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  // ============================================================
  // LOAD SAVED SETTINGS
  // ============================================================

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final savedTwoFactor =
          prefs.getBool('admin_two_factor') ?? false;

      final savedRememberLogin =
          prefs.getBool('admin_remember_login') ?? true;

      if (!mounted) return;

      setState(() {
        twoFactor = savedTwoFactor;
        rememberLogin = savedRememberLogin;
        _loadingPreferences = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingPreferences = false;
      });

      _showMessage(
        "Unable to load account settings.",
        isError: true,
      );
    }
  }

  // ============================================================
  // SAVE TWO FACTOR PREFERENCE
  // ============================================================

  Future<void> _updateTwoFactor(bool value) async {
    setState(() {
      twoFactor = value;
    });

    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool(
        'admin_two_factor',
        value,
      );

      if (!mounted) return;

      _showMessage(
        value
            ? "Two-factor security preference enabled."
            : "Two-factor security preference disabled.",
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        twoFactor = !value;
      });

      _showMessage(
        "Unable to save security setting.",
        isError: true,
      );
    }
  }

  // ============================================================
  // SAVE REMEMBER LOGIN
  // ============================================================

  Future<void> _updateRememberLogin(bool value) async {
    setState(() {
      rememberLogin = value;
    });

    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool(
        'admin_remember_login',
        value,
      );

      if (!mounted) return;

      _showMessage(
        value
            ? "Remember Login enabled."
            : "Remember Login disabled.",
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        rememberLogin = !value;
      });

      _showMessage(
        "Unable to save login preference.",
        isError: true,
      );
    }
  }

  // ============================================================
  // CHANGE PASSWORD
  // ============================================================

  Future<void> _changePassword() async {
    if (_sendingResetEmail) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage(
        "No admin account is currently signed in.",
        isError: true,
      );
      return;
    }

    final email = user.email;

    if (email == null || email.isEmpty) {
      _showMessage(
        "No email address is associated with this account.",
        isError: true,
      );
      return;
    }

    // Confirm before sending the reset email.
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            "Change Password",
          ),
          content: Text(
            "A password reset email will be sent to:\n\n$email\n\n"
                "Do you want to continue?",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text("Send Email"),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() {
      _sendingResetEmail = true;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email,
      );

      if (!mounted) return;

      _showMessage(
        "Password reset email sent to $email",
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'user-not-found':
          message = "Admin account was not found.";
          break;

        case 'invalid-email':
          message = "The account email address is invalid.";
          break;

        case 'too-many-requests':
          message =
          "Too many requests. Please try again later.";
          break;

        default:
          message =
              e.message ?? "Unable to send password reset email.";
      }

      _showMessage(
        message,
        isError: true,
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        "Something went wrong while sending the reset email.",
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _sendingResetEmail = false;
        });
      }
    }
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> _logout() async {
    if (_loggingOut) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            "Logout",
          ),
          content: const Text(
            "Are you sure you want to logout?",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text("Logout"),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() {
      _loggingOut = true;
    });

    try {
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        "/login",
            (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      _showMessage(
        e.message ?? "Unable to logout.",
        isError: true,
      );

      setState(() {
        _loggingOut = false;
      });
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        "Unable to logout. Please try again.",
        isError: true,
      );

      setState(() {
        _loggingOut = false;
      });
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
      String message, {
        bool isError = false,
      }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor:
        isError ? Colors.red : Colors.green,
        content: Text(message),
      ),
    );
  }

  // ============================================================
  // RESPONSIVE SETTING ROW
  // ============================================================

  Widget _responsiveSetting({
    required Widget icon,
    required String title,
    required String subtitle,
    required Widget action,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isSmall =
            constraints.maxWidth < 650;

        if (isSmall) {
          return Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              icon,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment:
                      Alignment.centerLeft,
                      child: action,
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        return Row(
          children: [
            icon,
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            action,
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingPreferences) {
      return Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Padding(
          padding: EdgeInsets.all(30),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            const Text(
              "Account Settings",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 5),

            Text(
              "Manage your account security and login preferences.",
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),

            const SizedBox(height: 20),

            // ==================================================
            // CHANGE PASSWORD
            // ==================================================

            _responsiveSetting(
              icon: const CircleAvatar(
                backgroundColor:
                Color(0xFFE3F2FD),
                child: Icon(
                  Icons.lock_outline,
                  color: Colors.blue,
                ),
              ),

              title: "Change Password",

              subtitle:
              "Send password reset email",

              action: ElevatedButton(
                onPressed: _sendingResetEmail
                    ? null
                    : _changePassword,
                child: _sendingResetEmail
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child:
                  CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
                    : const Text("Change"),
              ),
            ),

            const Divider(height: 30),

            // ==================================================
            // TWO FACTOR SECURITY
            // ==================================================

            _responsiveSetting(
              icon: const CircleAvatar(
                backgroundColor:
                Color(0xFFFFF3E0),
                child: Icon(
                  Icons.security,
                  color: Colors.orange,
                ),
              ),

              title:
              "Two-Factor Authentication",

              subtitle:
              "Security preference saved on this device",

              action: Switch(
                value: twoFactor,
                onChanged: _updateTwoFactor,
              ),
            ),

            const Divider(height: 30),

            // ==================================================
            // REMEMBER LOGIN
            // ==================================================

            _responsiveSetting(
              icon: const CircleAvatar(
                backgroundColor:
                Color(0xFFE8F5E9),
                child: Icon(
                  Icons.login,
                  color: Colors.green,
                ),
              ),

              title: "Remember Login",

              subtitle:
              "Save your login preference on this device",

              action: Switch(
                value: rememberLogin,
                onChanged: _updateRememberLogin,
              ),
            ),

            const Divider(height: 30),

            // ==================================================
            // LOGOUT
            // ==================================================

            _responsiveSetting(
              icon: const CircleAvatar(
                backgroundColor:
                Color(0xFFFFEBEE),
                child: Icon(
                  Icons.logout,
                  color: Colors.red,
                ),
              ),

              title: "Logout",

              subtitle:
              "Sign out from this account",

              action: OutlinedButton(
                style:
                OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                ),

                onPressed:
                _loggingOut ? null : _logout,

                child: _loggingOut
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child:
                  CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
                    : const Text("Logout"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}