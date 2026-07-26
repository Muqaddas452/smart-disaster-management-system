import 'package:flutter/material.dart'; // Flutter's core UI toolkit
import 'package:firebase_auth/firebase_auth.dart'; // lets us create/manage Firebase Auth accounts
import 'package:cloud_firestore/cloud_firestore.dart'; // lets us read/write Firestore database
import 'package:geolocator/geolocator.dart'; // NEW: lets us get the device's GPS location
import 'create_password_screen.dart'; // screen we go to after verifying invite code (Tab 2)
import 'pending_approval_screen.dart'; // screen we go to after registering a new team (Tab 1)

class RescueRegistrationScreen extends StatefulWidget {
  // Stateful because this screen has tabs, loading spinners, and form data that change
  const RescueRegistrationScreen({super.key}); // constructor, key used internally by Flutter

  @override
  State<RescueRegistrationScreen> createState() =>
      _RescueRegistrationScreenState(); // links this widget to its state class below
}

class _RescueRegistrationScreenState extends State<RescueRegistrationScreen>
    with SingleTickerProviderStateMixin {
  // "with SingleTickerProviderStateMixin" is required because TabController needs
  // a "vsync" (a ticker) to animate the tab switch smoothly

  late TabController _tabController; // will control which of the 2 tabs is showing

  // ---- Colors, matching the rest of the app (dark green + white) ----
  static const MaterialColor _primaryGreen = Colors.green; // base green color for buttons/appbar

  // ============ FORM 1: Register New Team (Leader) fields ============
  final _registerFormKey = GlobalKey<FormState>(); // key used to validate Tab 1's form
  final TextEditingController _teamNameController = TextEditingController(); // holds Team Name text
  final TextEditingController _areaController = TextEditingController(); // holds Area text
  final TextEditingController _specializationController =
  TextEditingController(); // holds Specialization text
  // NEW: holds the leader's full name (e.g. "Ali Khan"), shown on admin dashboard
  final TextEditingController _leaderNameController = TextEditingController();
  final TextEditingController _leaderEmailController =
  TextEditingController(); // holds Leader's email text
  final TextEditingController _leaderPasswordController =
  TextEditingController(); // holds Leader's password text
  // NEW: holds the leader's contact phone number
  final TextEditingController _phoneController = TextEditingController();

  String _selectedTeamType = 'Fire'; // currently selected value in the dropdown, starts as 'Fire'
  // NEW: currently selected vehicle type, starts as 'Ambulance'
  String _selectedVehicle = 'Ambulance';
  bool _isRegistering = false; // true while we're waiting for Firebase, used to show a spinner

  // ============ FORM 2: Join Existing Team (Member) fields ============
  final _joinFormKey = GlobalKey<FormState>(); // key used to validate Tab 2's form
  final TextEditingController _memberEmailController =
  TextEditingController(); // holds member's email text
  final TextEditingController _teamCodeController =
  TextEditingController(); // holds invite code text
  bool _isJoining = false; // true while we're checking the invite code in Firestore

  @override
  void initState() {
    // initState runs once, when this screen first loads
    super.initState(); // always call the parent's initState first
    _tabController = TabController(length: 2, vsync: this); // create controller for 2 tabs
  }

  @override
  void dispose() {
    // dispose runs when this screen is closed/removed, to clean up memory
    _tabController.dispose(); // stop and free the tab controller
    _teamNameController.dispose(); // free the Team Name controller
    _areaController.dispose(); // free the Area controller
    _specializationController.dispose(); // free the Specialization controller
    _leaderNameController.dispose(); // NEW: free the Leader Name controller
    _leaderEmailController.dispose(); // free the Leader Email controller
    _leaderPasswordController.dispose(); // free the Leader Password controller
    _phoneController.dispose(); // NEW: free the Phone controller
    _memberEmailController.dispose(); // free the Member Email controller
    _teamCodeController.dispose(); // free the Team Code controller
    super.dispose(); // always call the parent's dispose last
  }

  // ---- Email format check (same rule used across the whole app) ----
  bool _isValidEmail(String email) {
    // returns true only if email looks like something@something.something
    return RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(email);
  }

  // ---- Password strength check (same rule used across the whole app) ----
  bool _isValidPassword(String password) {
    // requires: 1 number, 1 capital letter, 1 small letter, 1 special char, min 8 length
    final regex = RegExp(
      r'^(?=.*[0-9])(?=.*[A-Z])(?=.*[a-z])(?=.*[!@#\$&*~%^()_+=-]).{8,}$',
    );
    return regex.hasMatch(password); // true if password matches all those rules
  }

  // ======================================================
  // NEW: get the device's current GPS location (latitude & longitude)
  // ======================================================
  Future<Position?> _getCurrentLocation() async {
    // STEP 1: check if location services (GPS) are turned on at all
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showError('Please turn on location services and try again.');
      return null;
    }

    // STEP 2: check what permission level we currently have
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      // we don't have permission yet, so ask the user for it
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showError('Location permission is required to register your team.');
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // user permanently blocked location access from device settings
      _showError('Location permission permanently denied. Enable it from Settings.');
      return null;
    }

    // STEP 3: permission granted, now get the actual current position
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  // ======================================================
  // LOGIC: Register New Team (creates Firebase Auth account + Firestore documents)
  // ======================================================
  Future<void> _registerNewTeam() async {
    // Future<void> means this function runs in the background and returns nothing
    if (!_registerFormKey.currentState!.validate()) return; // stop here if any field is invalid

    setState(() => _isRegistering = true); // turn on the loading spinner

    try {
      // NEW: get GPS location BEFORE creating the account
      // (so if location fails, we don't create a half-finished account)
      final Position? position = await _getCurrentLocation();
      if (position == null) {
        // _getCurrentLocation already showed an error message, just stop here
        setState(() => _isRegistering = false);
        return;
      }

      // STEP 1: create the login account for the leader in Firebase Authentication
      final UserCredential userCredential =
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _leaderEmailController.text.trim(), // trim removes accidental spaces
        password: _leaderPasswordController.text.trim(),
      );

      final String uid = userCredential.user!.uid; // unique ID Firebase generated for this user

      // STEP 2: create a new document inside the "teams" collection
      final teamDocRef =
      FirebaseFirestore.instance.collection('rescueTeams').doc(); // auto-generates a new doc ID
      final String teamId = teamDocRef.id; // save that generated ID so we can reuse it below

      await teamDocRef.set({
        'teamId': teamId, // store the team's own ID inside its document too
        'teamName': _teamNameController.text.trim(), // team's name from the form
        'teamType': _selectedTeamType, // Fire/Medical/Flood/General from dropdown
        'specialization': _specializationController.text.trim(), // e.g. Search & Rescue
        'assignedArea': _areaController.text.trim(), // operating city/area
        'leaderUid': uid, // link this team to its leader's Firebase UID (for real authentication)
        'leaderName': _leaderNameController.text.trim(), // NEW: leader's display name (for admin dashboard)
        'phone': _phoneController.text.trim(), // NEW: leader's contact number
        'vehicle': _selectedVehicle, // NEW: Ambulance / Truck / Boat / None
        'latitude': position.latitude, // NEW: GPS latitude, captured automatically at registration
        'longitude': position.longitude, // NEW: GPS longitude, captured automatically
        'members': 0, // NEW: starts at 0, auto-increments each time a member joins later
        'availability': 'Available', // NEW: operational status (separate from approval status below)
        'status': 'pending', // approval status: team is not active until admin approves it
        'createdAt': FieldValue.serverTimestamp(), // Firestore fills in the exact server time
      });

      // STEP 3: create a document inside "rescueTeamUsers" collection, one per user (not per team)
      await FirebaseFirestore.instance
          .collection('rescueTeamUsers')
          .doc(uid) // use the same uid as the document ID, so it's easy to find later
          .set({
        'uid': uid, // this user's Firebase UID
        'email': _leaderEmailController.text.trim(), // leader's email
        'teamId': teamId, // which team this user belongs to
        'isLeader': true, // marks this user as the leader (not a normal member)
        'status': 'pending', // matches the team's pending status
        'createdAt': FieldValue.serverTimestamp(), // when this record was created
      });

      // STEP 4: create an entry in "authIndex" — a quick lookup table
      // so later, given just a uid, the app instantly knows "this is a rescue_team user"
      // without having to search both citizens AND rescueTeamUsers collections
      await FirebaseFirestore.instance.collection('authIndex').doc(uid).set({
        'uid': uid, // this user's Firebase UID
        'role': 'rescue_team', // tells the app what type of user this is
        'collection': 'rescueTeamUsers', // tells the app exactly where to find their full data
      });

      // STEP 5: move the leader to the Pending Approval screen
      if (mounted) {
        // "mounted" makes sure this screen is still open before we try to navigate
        Navigator.pushReplacement(
          // pushReplacement removes THIS screen from history (leader shouldn't come back here)
          context,
          MaterialPageRoute(
              builder: (context) => const PendingApprovalScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      // this catches errors specifically coming from Firebase Authentication
      String message = 'Something went wrong. Please try again.'; // default fallback message
      if (e.code == 'email-already-in-use') {
        message = 'This email is already registered.'; // specific message for this error code
      } else if (e.code == 'weak-password') {
        message = 'Password is too weak.'; // specific message for this error code
      }
      _showError(message); // show whichever message we decided above
    } catch (e) {
      // this catches any other unexpected error, like no internet connection
      _showError('Registration failed: $e');
    } finally {
      // finally always runs, whether it succeeded or failed
      if (mounted) setState(() => _isRegistering = false); // turn off the loading spinner
    }
  }

  // ======================================================
  // LOGIC: Join Existing Team (check invite code, then go to Create Password screen)
  // ======================================================
  Future<void> _joinExistingTeam() async {
    if (!_joinFormKey.currentState!.validate()) return; // stop if form fields are invalid

    setState(() => _isJoining = true); // turn on loading spinner for this tab

    try {
      final String email = _memberEmailController.text.trim(); // member's typed email
      final String code = _teamCodeController.text.trim(); // member's typed invite code

      // search "teamInvitations" collection for a document matching BOTH email and code,
      // and where status is still "pending" (meaning it hasn't been used yet)
      final querySnapshot = await FirebaseFirestore.instance
          .collection('teamInvitations')
          .where('email', isEqualTo: email) // must match this exact email
          .where('inviteCode', isEqualTo: code) // must match this exact code
          .where('status', isEqualTo: 'pending') // must not be already used
          .limit(1) // we only need one matching result
          .get(); // actually run the search

      if (querySnapshot.docs.isEmpty) {
        // no document matched all 3 conditions above
        _showError(
            'Invalid email or invite code. Please check with your team leader.');
        return; // stop here, don't continue further
      }

      final invitationDoc = querySnapshot.docs.first; // grab the matching invitation document
      final invitationData = invitationDoc.data(); // get its actual field values (a Map)

      if (mounted) {
        Navigator.push(
          // push (not replace) so member CAN go back if needed
          context,
          MaterialPageRoute(
            builder: (context) => CreatePasswordScreen(
              email: email, // pass the verified email forward
              teamId: invitationData['teamId'], // pass which team they're joining
              invitationId:
              invitationDoc.id, // pass invite doc ID, needed to mark it "used" later
            ),
          ),
        );
      }
    } catch (e) {
      // catches any unexpected error, e.g. no internet
      _showError('Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _isJoining = false); // turn off loading spinner either way
    }
  }

  // helper function: shows a small red popup message at the bottom of the screen
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    // build() draws this screen every time Flutter needs to refresh it
    return Scaffold(
      backgroundColor: Colors.white, // plain white background, matches app style
      appBar: AppBar(
        // explicit back button, so tapping it always goes back to Welcome Screen
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white), // white back arrow icon
          onPressed: () {
            Navigator.pop(context); // pop() removes this screen and returns to the previous one
          },
        ),
        title: const Text('Rescue Team'), // text shown in the top app bar
        backgroundColor: _primaryGreen.shade800, // dark green app bar background
        foregroundColor: Colors.white, // makes title/icons white by default
        bottom: TabBar(
          // this places the 2 tabs right under the app bar title
          controller: _tabController, // connects this TabBar to our controller
          indicatorColor: Colors.white, // color of the little line under the active tab
          labelColor: Colors.white, // text color of the currently selected tab
          unselectedLabelColor: Colors.white70, // text color of the non-selected tab
          tabs: const [
            Tab(text: 'Register New Team'), // Tab 1 label
            Tab(text: 'Join Existing Team'), // Tab 2 label
          ],
        ),
      ),
      body: TabBarView(
        // shows whichever tab's content matches the currently selected tab
        controller: _tabController, // connects this view to the same tab controller
        children: [
          _buildRegisterTeamForm(), // widget shown for Tab 1
          _buildJoinTeamForm(), // widget shown for Tab 2
        ],
      ),
    );
  }

  // ============ UI: Tab 1 - Register New Team Form ============
  Widget _buildRegisterTeamForm() {
    return SingleChildScrollView(
      // makes the form scrollable so the keyboard doesn't hide the fields
      padding: const EdgeInsets.all(20), // 20px space around the whole form
      child: Form(
        key: _registerFormKey, // links this Form widget to its validation key
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.stretch, // makes children fill the full width
          children: [
            // Team Name field
            TextFormField(
              controller: _teamNameController, // links this field to its controller
              decoration: const InputDecoration(
                labelText: 'Team Name', // floating label text
                border: OutlineInputBorder(), // gives the field a visible border box
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Team name is required' // error shown if field is empty
                  : null, // null means "this field is valid"
            ),
            const SizedBox(height: 16), // 16px gap below this field

            // Team Type dropdown
            DropdownButtonFormField<String>(
              initialValue: _selectedTeamType, // shows the currently selected value
              decoration: const InputDecoration(
                labelText: 'Team Type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                    value: 'Fire', child: Text('Fire Rescue')), // option 1
                DropdownMenuItem(
                    value: 'Medical', child: Text('Medical Rescue')), // option 2
                DropdownMenuItem(
                    value: 'Flood', child: Text('Flood Rescue')), // option 3
                DropdownMenuItem(
                    value: 'General', child: Text('General Rescue')), // option 4
              ],
              onChanged: (value) {
                setState(() => _selectedTeamType =
                value!); // update state when user picks a new option
              },
            ),
            const SizedBox(height: 16),

            // Specialization field
            TextFormField(
              controller: _specializationController,
              decoration: const InputDecoration(
                labelText: 'Specialization (e.g. Search & Rescue)',
                border: OutlineInputBorder(),
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Specialization is required'
                  : null,
            ),
            const SizedBox(height: 16),

            // Area field
            TextFormField(
              controller: _areaController,
              decoration: const InputDecoration(
                labelText: 'Operating Area / City',
                border: OutlineInputBorder(),
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Area is required'
                  : null,
            ),
            const SizedBox(height: 16),

            // NEW: Leader Full Name field
            TextFormField(
              controller: _leaderNameController,
              decoration: const InputDecoration(
                labelText: 'Leader Full Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Leader name is required'
                  : null,
            ),
            const SizedBox(height: 16),

            // Leader Email field
            TextFormField(
              controller: _leaderEmailController,
              keyboardType:
              TextInputType.emailAddress, // shows email-style keyboard on phone
              decoration: const InputDecoration(
                labelText: 'Leader Email',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty)
                  return 'Email is required'; // check 1: not empty
                if (!_isValidEmail(value.trim()))
                  return 'Enter a valid email address'; // check 2: correct format
                return null; // passed both checks
              },
            ),
            const SizedBox(height: 16),

            // NEW: Phone Number field
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone, // shows number keyboard on phone
              decoration: const InputDecoration(
                labelText: 'Contact Number',
                hintText: '03001234567',
                border: OutlineInputBorder(),
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Contact number is required'
                  : null,
            ),
            const SizedBox(height: 16),

            // NEW: Vehicle Type dropdown
            DropdownButtonFormField<String>(
              initialValue: _selectedVehicle,
              decoration: const InputDecoration(
                labelText: 'Vehicle Type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'Ambulance', child: Text('Ambulance')),
                DropdownMenuItem(value: 'Truck', child: Text('Truck')),
                DropdownMenuItem(value: 'Boat', child: Text('Boat')),
                DropdownMenuItem(value: 'None', child: Text('None')),
              ],
              onChanged: (value) {
                setState(() => _selectedVehicle = value!);
              },
            ),
            const SizedBox(height: 16),

            // Leader Password field
            TextFormField(
              controller: _leaderPasswordController,
              obscureText: true, // hides the typed characters (dots instead of letters)
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty)
                  return 'Password is required'; // check 1: not empty
                if (!_isValidPassword(value)) {
                  return 'Min 8 chars, with uppercase, lowercase, number & symbol'; // check 2: strength
                }
                return null; // passed both checks
              },
            ),
            const SizedBox(height: 8),

            // NEW: small hint telling the leader we'll use their GPS location
            const Text(
              'We will use your current location as your team\'s base coordinates.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 24),

            // Submit button for Tab 1
            SizedBox(
              height: 56, // fixed button height
              child: ElevatedButton(
                onPressed: _isRegistering
                    ? null // disables the button while registration is running
                    : _registerNewTeam, // otherwise runs the registration function
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryGreen.shade800, // button fill color
                  foregroundColor: Colors.white, // text color inside button
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16), // rounded corners
                  ),
                ),
                child: _isRegistering
                    ? const CircularProgressIndicator(
                    color: Colors.white) // spinner shown while loading
                    : const Text('Register Team',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600)), // normal button text
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============ UI: Tab 2 - Join Existing Team Form ============
  Widget _buildJoinTeamForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20), // same padding style as Tab 1
      child: Form(
        key: _joinFormKey, // links this Form to its own validation key
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12), // small gap at the top
            const Text(
              'Enter the email and invite code shared by your team leader.', // helper instruction text
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 20),

            // Member Email field
            TextFormField(
              controller: _memberEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Your Email',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty)
                  return 'Email is required';
                if (!_isValidEmail(value.trim()))
                  return 'Enter a valid email address';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Team Invite Code field
            TextFormField(
              controller: _teamCodeController,
              decoration: const InputDecoration(
                labelText: 'Team Invite Code',
                border: OutlineInputBorder(),
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Invite code is required'
                  : null,
            ),
            const SizedBox(height: 28),

            // Submit button for Tab 2
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isJoining
                    ? null // disables button while checking invite code
                    : _joinExistingTeam,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryGreen.shade800,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isJoining
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Verify & Continue',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}