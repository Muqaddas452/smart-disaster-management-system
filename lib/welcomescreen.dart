import 'package:flutter/material.dart';
import 'signupscreen.dart';
import 'login_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const Color _primaryGreen = Color(0xFF1B6B1B);
  static const Color _buttonGreen = Color(0xFF1E7A1E);
  static const Color _subtitleColor = Color(0xFF2E7D32);
  static const Color _loginBorderColor = Color(0xFF1565C0);
  static const Color _loginTextColor = Color(0xFF1565C0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFD6EAF8),
              Color(0xFFEBF5FB),
              Colors.white,
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Spacer(flex: 3),
                _buildTitleSection(),
                const Spacer(flex: 4),
                _buildButtonsSection(context),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitleSection() {
    return const Column(
      children: [
        Text(
          'Smart Disaster\nManagement System',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w900,
            color: _primaryGreen,
            height: 1.2,
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Stay Safe',
                style: TextStyle(
                    fontSize: 16,
                    color: _subtitleColor,
                    fontWeight: FontWeight.w500)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: Text('•',
                  style: TextStyle(fontSize: 16, color: _subtitleColor)),
            ),
            Text('Stay Alert',
                style: TextStyle(
                    fontSize: 16,
                    color: _subtitleColor,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }

  Widget _buildButtonsSection(BuildContext context) {
    return Column(
      children: [
        // Sign Up Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SignUpScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _buttonGreen,
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Sign Up',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Login Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },


            style: OutlinedButton.styleFrom(
              foregroundColor: _loginTextColor,
              side: const BorderSide(color: _loginBorderColor, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Login',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}