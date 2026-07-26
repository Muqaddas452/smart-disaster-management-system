import 'package:flutter/material.dart'; // import Flutter's basic UI toolkit
import '/../../citizen_screens/signupscreen.dart'; // import the Sign Up screen file
import 'citizen_screens/login_screen.dart'; // import the Login screen file
import 'rescue_team/rescue_registration_screen.dart'; // import the Rescue Registration screen file

class WelcomeScreen extends StatelessWidget {
  // this screen never changes on its own (no setState needed), so it's Stateless
  const WelcomeScreen({super.key}); // constructor, key is used by Flutter internally

  // ---- Colors for this screen ----
  // using Flutter's built-in named colors instead of hex codes
  // "shade" number controls how dark/light the color is (bigger number = darker)
  static const MaterialColor _primaryGreen = Colors.green; // base green color for the title text
  static const Color _titleShade = Color.fromARGB(255, 27, 94, 32); // backup exact color, not used directly right now
  static const MaterialColor _buttonGreen = Colors.green; // base green color for Sign Up button
  static const MaterialColor _subtitleColor = Colors.green; // base green color for subtitle text
  static const MaterialColor _loginColor = Colors.blue; // base blue color for Login button
  static const MaterialColor _rescueColor = Colors.deepOrange; // base orange color for Rescue Team link

  @override
  Widget build(BuildContext context) {
    // build() runs every time Flutter needs to draw this screen
    return Scaffold(
      // Scaffold gives the basic screen structure (background, body area, etc.)
      body: Container(
        width: double.infinity, // take full width of the phone screen
        height: double.infinity, // take full height of the phone screen
        decoration: const BoxDecoration(
          // BoxDecoration lets us add a background gradient
          gradient: LinearGradient(
            begin: Alignment.topCenter, // gradient starts from the top
            end: Alignment.bottomCenter, // gradient ends at the bottom
            // Background stays as light blue shades
            colors: [
              Color(0xFFD6EAF8), // very light blue at the top
              Color(0xFFEBF5FB), // slightly lighter blue in the middle
              Colors.white, // white at the bottom
            ],
            stops: [0.0, 0.5, 1.0], // where each color starts/ends (0% , 50%, 100%)
          ),
        ),
        child: SafeArea(
          // SafeArea keeps content away from notches, status bar, etc.
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0), // add 24px space on left and right
            child: Column(
              // Column stacks things vertically (top to bottom)
              mainAxisAlignment: MainAxisAlignment.spaceBetween, // spread children evenly top to bottom
              children: [
                const Spacer(flex: 3), // empty flexible space at the top (pushes title down a bit)
                _buildTitleSection(), // call the function that builds the title text
                const Spacer(flex: 4), // empty flexible space between title and buttons
                _buildButtonsSection(context), // call the function that builds all the buttons
                const SizedBox(height: 32), // fixed 32px gap at the very bottom
              ],
            ),
          ),
        ),
      ),
    );
  }

  // this function only builds the title + subtitle part of the screen
  Widget _buildTitleSection() {
    return Column(
      // stack the title and subtitle vertically
      children: [
        Text(
          'Smart Disaster\nManagement System', // \n makes it break into 2 lines
          textAlign: TextAlign.center, // center the text horizontally
          style: TextStyle(
            fontSize: 36, // big text size for the main title
            fontWeight: FontWeight.w900, // very bold
            color: _primaryGreen.shade900, // dark green shade for strong title look
            height: 1.2, // space between the two lines of text
            letterSpacing: -0.5, // slightly tighter spacing between letters
          ),
        ),
        const SizedBox(height: 16), // 16px gap between title and subtitle row
        Row(
          // Row stacks things side by side (left to right)
          mainAxisAlignment: MainAxisAlignment.center, // center the row horizontally
          children: [
            Text('Stay Safe', // first part of the subtitle
                style: TextStyle(
                    fontSize: 16, // smaller text size for subtitle
                    color: _subtitleColor.shade800, // medium green shade
                    fontWeight: FontWeight.w500)), // medium bold
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0), // small gap around the dot
              child: Text('•', style: TextStyle(fontSize: 16)), // the dot separator between the two phrases
            ),
            Text('Stay Alert', // second part of the subtitle
                style: TextStyle(
                    fontSize: 16,
                    color: _subtitleColor.shade800,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }

  // this function builds all 3 buttons/links: Sign Up, Login, and Rescue Team
  Widget _buildButtonsSection(BuildContext context) {
    return Column(
      // stack all buttons vertically, one after another
      children: [
        // ---------------- Sign Up Button ----------------
        SizedBox(
          width: double.infinity, // button takes the full width available
          height: 56, // fixed height for the button
          child: ElevatedButton(
            // ElevatedButton = solid filled button (used for the main action)
            onPressed: () {
              // this code runs when user taps the Sign Up button
              Navigator.push(
                // Navigator.push moves to a new screen and keeps this one in memory
                context, // tells Flutter which screen we are moving from
                MaterialPageRoute(builder: (context) => const SignUpScreen()), // the new screen to open
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _buttonGreen.shade800, // fill color of the button
              foregroundColor: Colors.white, // text color inside the button
              elevation: 2, // small shadow under the button
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16), // rounded corners
              ),
            ),
            child: const Text(
              'Sign Up', // text shown on the button
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600), // text size and boldness
            ),
          ),
        ),

        const SizedBox(height: 16), // 16px gap between Sign Up and Login buttons

        // ---------------- Login Button ----------------
        SizedBox(
          width: double.infinity, // full width like Sign Up
          height: 56, // same height as Sign Up
          child: OutlinedButton(
            // OutlinedButton = button with just a border, no fill (used for secondary action)
            onPressed: () {
              // this code runs when user taps the Login button
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()), // open Login screen
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: _loginColor.shade800, // text color
              side: BorderSide(color: _loginColor.shade800, width: 1.5), // border color and thickness
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16), // rounded corners, same as Sign Up
              ),
            ),
            child: const Text(
              'Login', // text shown on the button
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
        ),

        // ---------------- Rescue Team - small link style ----------------
        // instead of a big button, this is just a small clickable text
        // it's placed below Login because rescue team registration is not the main action
        const SizedBox(height: 20), // gap before the rescue team link

        Center(
          // Center makes sure this small link stays in the middle of the screen
          child: TextButton(
            // TextButton = looks like plain text but is still clickable
            onPressed: () {
              // this code runs when user taps "Register here"
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RescueRegistrationScreen(), // open Rescue Registration screen
                ),
              );
            },
            child: RichText(
              // RichText lets us style different parts of the same sentence differently
              text: TextSpan(
                style: const TextStyle(fontSize: 14, color: Colors.black54), // default style for normal part
                children: [
                  const TextSpan(text: 'Are you a rescue team? '), // plain grey text part
                  TextSpan(
                    text: 'Register here', // this part looks like a clickable link
                    style: TextStyle(
                      color: _rescueColor.shade800, // orange color to stand out
                      fontWeight: FontWeight.w700, // bold
                      decoration: TextDecoration.underline, // underline to look like a link
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}