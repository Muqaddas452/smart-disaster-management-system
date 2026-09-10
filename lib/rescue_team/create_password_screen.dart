import 'package:flutter/material.dart'; // Flutter's core UI toolkit
import 'package:firebase_auth/firebase_auth.dart'; // to create the Firebase Auth account
import 'package:cloud_firestore/cloud_firestore.dart'; // to save/update Firestore documents
import '../citizen_screens/login_screen.dart'; // Login screen is in lib/, one folder up from rescue_team/

class CreatePasswordScreen extends StatefulWidget {
  // this screen needs 3 pieces of data passed in from the previous screen
  final String email; // the member's verified email
  final String teamId; // which team this member is joining
  final String invitationId; // the invitation document's ID, so we can mark it as "used"

  const CreatePasswordScreen({
    super.key,
    required this.email, // required means this MUST be passed when creating this screen
    required this.teamId,
    required this.invitationId,
  });

  @override
  State<CreatePasswordScreen> createState() => _CreatePasswordScreenState();
}

class _CreatePasswordScreenState extends State<CreatePasswordScreen> {
  // ---- Colors, same dark green + white theme as rest of the app ----
  static const MaterialColor _primaryGreen = Colors.green;

  final _formKey = GlobalKey<FormState>(); // used to validate this form
  final TextEditingController _passwordController =
  TextEditingController(); // holds the typed password
  final TextEditingController _confirmPasswordController =
  TextEditingController(); // holds the re-typed password (to confirm they match)

  bool _obscurePassword = true; // true = password is hidden (dots), false = visible text
  bool _obscureConfirmPassword = true; // same, but for the confirm password field
  bool _isSubmitting = false; // true while Firebase is creating the account

  @override
  void dispose() {
    // clean up controllers when this screen is closed, to free memory
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ---- Password strength check (same rule used across the whole app) ----
  bool _isValidPassword(String password) {
    // requires: 1 number, 1 capital letter, 1 small letter, 1 special char, min 8 length
    final regex = RegExp(
      r'^(?=.*[0-9])(?=.*[A-Z])(?=.*[a-z])(?=.*[!@#\$&*~%^()_+=-]).{8,}$',
    );
    return regex.hasMatch(password);
  }

  // ======================================================
  // LOGIC: Create the member's Firebase Auth account and save their data
  // ======================================================
  Future<void> _createPasswordAndAccount() async {
    if (!_formKey.currentState!.validate()) return; // stop if form fields are invalid

    setState(() => _isSubmitting = true); // show loading spinner

    try {
      // STEP 1: create the Firebase Authentication account using the verified email
      // and the new password the member just typed
      final UserCredential userCredential =
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: widget.email, // "widget." lets us access data passed into this screen
        password: _passwordController.text.trim(),
      );

      final String uid = userCredential.user!.uid; // Firebase's unique ID for this new user

      // STEP 2: create this member's document in "rescueTeamUsers" collection
      await FirebaseFirestore.instance
          .collection('rescueTeams')
          .doc(uid) // use uid as the document ID, same pattern as the leader
          .set({
        'uid': uid,
        'email': widget.email,
        'teamId': widget.teamId, // links this member to the team they're joining
        'isLeader': false, // this user is a regular member, not the leader
        'status': 'approved',
        // members don't need separate admin approval — the team leader already
        // approved them by sending the invite, so we mark them approved right away
        'createdAt': FieldValue.serverTimestamp(), // Firestore fills in the current server time
      });

      // STEP 3: create an entry in "authIndex" so login logic knows this uid = rescue_team
      await FirebaseFirestore.instance.collection('authIndex').doc(uid).set({
        'uid': uid,
        'role': 'rescue_team',
        'collection': 'rescueTeamUsers',
      });

      // STEP 4 (NEW): increase the "members" count on the team's document by 1
      // this is how the admin dashboard's member count stays accurate automatically —
      // we never set this number manually, it just goes up each time someone joins
      await FirebaseFirestore.instance
          .collection('teams')
          .doc(widget.teamId)
          .update({
        'members': FieldValue.increment(1),
        // FieldValue.increment(1) tells Firestore "take whatever number is
        // already there, and add 1 to it" — safe even if two members join
        // at almost the same time, Firestore handles it correctly
      });

      // STEP 5: mark the invitation as "used" so nobody else can use this same code again
      await FirebaseFirestore.instance
          .collection('teamInvitations')
          .doc(widget.invitationId) // the specific invitation doc passed in from before
          .update({'status': 'used'});

      // STEP 6: send the member to Login screen, so they log in properly
      // (same reasoning as leader flow — login creates a fresh, verified session)
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          // removes all previous screens so back button can't return to this form
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false, // false means clear the entire navigation history
        );
      }
    } on FirebaseAuthException catch (e) {
      // catches errors specifically from Firebase Authentication
      String message = 'Something went wrong. Please try again.'; // default message
      if (e.code == 'email-already-in-use') {
        message = 'An account already exists for this email.';
      } else if (e.code == 'weak-password') {
        message = 'Password is too weak.';
      }
      _showError(message);
    } catch (e) {
      // catches any other unexpected error, e.g. no internet
      _showError('Something went wrong: $e');
    } finally {
      // runs whether it succeeded or failed
      if (mounted) setState(() => _isSubmitting = false); // turn off the spinner
    }
  }

  // helper function to show error messages in a small popup
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // plain white background
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white), // white back arrow
          onPressed: () {
            Navigator.pop(context); // goes back to the previous screen (Rescue Registration)
          },
        ),
        title: const Text('Create Password'), // top bar title
        backgroundColor: _primaryGreen.shade800, // dark green app bar
        foregroundColor: Colors.white, // white text/icons
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          // makes the form scrollable, so keyboard doesn't cover fields
          padding: const EdgeInsets.all(24), // spacing around the whole form
          child: Form(
            key: _formKey, // links this Form to its validation key
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12), // small gap at the top

                // heading text
                Text(
                  'Set Your Password',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _primaryGreen.shade800, // dark green heading
                  ),
                ),
                const SizedBox(height: 8),

                // subtitle showing which email this account is for
                Text(
                  'For ${widget.email}', // shows the verified email to reassure the user
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 32),

                // Password field
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword, // hides text if true
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      // eye icon to toggle showing/hiding the password
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_off // closed eye when hidden
                          : Icons.visibility), // open eye when visible
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                        // flips true/false every time the icon is tapped
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    if (!_isValidPassword(value)) {
                      return 'Min 8 chars, with uppercase, lowercase, number & symbol';
                    }
                    return null; // passed validation
                  },
                ),
                const SizedBox(height: 16),

                // Confirm Password field
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirmPassword
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () {
                        setState(() =>
                        _obscureConfirmPassword = !_obscureConfirmPassword);
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      // checks that this field matches exactly what was typed above
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // Submit button
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isSubmitting
                        ? null // disable button while submitting, to avoid double taps
                        : _createPasswordAndAccount,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryGreen.shade800,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isSubmitting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                      'Create Account',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600),
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