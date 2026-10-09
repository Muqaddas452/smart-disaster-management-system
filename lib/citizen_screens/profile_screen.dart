import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smartdisaster/services/fcm_token_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'notification_settings_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'edit_emergency_contacts.dart';
import 'edit_personal_details.dart';
import 'login_screen.dart';
import 'feedback_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/services.dart'; //for clipboard
// ── AUTH WRAPPER ──────────────────────────────────────────────────
import 'package:smartdisaster/main.dart';
// ── OFFLINE SUPPORT ────────────────────────────────────────────────
import 'package:smartdisaster/database//db_helper.dart';
import 'package:smartdisaster/database/citizen_dao.dart';

class ViewProfileScreen extends StatefulWidget {
  const ViewProfileScreen({super.key});

  @override
  State<ViewProfileScreen> createState() => _ViewProfileScreenState();
}

class _ViewProfileScreenState extends State<ViewProfileScreen> {
  final String _uid = FirebaseAuth.instance.currentUser!.uid;

  bool _isOffline = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    _initConnectivity();
  }

  Future<void> _initConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() => _isOffline = result.contains(ConnectivityResult.none));
    }
    _connectivitySub = Connectivity().onConnectivityChanged.listen((result) {
      if (mounted) {
        setState(() => _isOffline = result.contains(ConnectivityResult.none));
      }
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  // ── LOGOUT (confirmation dialog + clean navigation) ──────────────
  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout from your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        // Citizen side: token 'citizens' collection se clear hoga
        await FcmTokenService.clearFCMToken(uid, collection: 'citizens');
      }
      await FirebaseAuth.instance.signOut();

      // Poora stack clear karke fresh AuthWrapper push karte hain.
      // AuthWrapper signed-out user dekh kar WelcomeScreen dikha dega,
      // chahe is screen tak kisi bhi raaste se aaye hon.
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthWrapper()),
              (route) => false,
        );
      }
    }
  }

  void _showShareOptionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Share SDMS',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              ListTile(
                leading: const Icon(Icons.chat, color: Colors.green),
                title: const Text('WhatsApp'),
                onTap: () {
                  Navigator.pop(context);
                  Share.share('Stay safe with Smart Disaster Management System (SDMS)! Download now.');
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy, color: Colors.blue),
                title: const Text('Copy Link'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Link copied to clipboard!')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.more_horiz, color: Colors.grey),
                title: const Text('More Options...'),
                onTap: () {
                  Navigator.pop(context);
                  Share.share('Stay safe with Smart Disaster Management System (SDMS)!');
                },
              ),
            ],
          ),
        );
      },
    );
  }
  String shareMessage =
      'Stay safe and report disasters instantly with Smart Disaster Management System (SDMS)! Download the app now.';
// 1. WhatsApp par share karne ke liye
  Future<void> _shareToWhatsApp() async {
    await Share.share('Check out SDMS app: $shareMessage');
  }

// 2. Link / Text Copy karne ke liye
  void _copyLinkToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: shareMessage));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied to clipboard!')),
    );
  }

// 3. More Options (System Share Sheet)
  Future<void> _shareViaSystem() async {
    await Share.share(
      shareMessage,
      subject: 'Smart Disaster Management System',
    );
  }

  // Cached profile map ko StreamBuilder wale `data` map jaisi hi shape
  // mein la kar deta hai, taake neeche ka UI aur navigation bilkul
  // waisa hi kaam kare jaisa online snapshot ke sath karta hai.
  Map<String, dynamic> _cachedToDataMap(Map<String, dynamic> cached) {
    return {
      'name': cached['name'] ?? '',
      'email': cached['email'] ?? '',
      'phone': cached['phone'] ?? '',
      'address': cached['address'] ?? '',
      'emergencyContactName': cached['emergencyContactName'] ?? '',
      'emergencyContactPhone': cached['emergencyContactPhone'] ?? '',
      'emergencyContactRelation': cached['emergencyContactRelation'] ?? '',
      // Note: gender aur birthday/dob DBHelper ke cached_citizen_profile
      // table mein cache nahi hote (wo columns table mein nahi hain), is
      // liye offline mode mein PersonalDetailsScreen inke liye apne
      // already-existing defaults ('Male' / '01/01/2000') dikhayega.
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E38),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: _isOffline ? _buildOfflineBody(context) : _buildOnlineBody(context),
    );
  }

  Widget _buildOfflineBody(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: CitizenDao.getCachedProfile(_uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF1B5E38)),
          );
        }

        final cached = snapshot.data;
        if (cached == null) {
          return const Center(child: Text('Unable to load profile.'));
        }

        final data = _cachedToDataMap(cached);
        final String name = data['name']!.isNotEmpty ? data['name']! : 'User Name';
        final String email = data['email']!.isNotEmpty ? data['email']! : 'user@gmail.com';

        return SingleChildScrollView(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                color: const Color(0xFFFFF3E0),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: const Text(
                  'Offline — showing last saved profile',
                  style: TextStyle(fontSize: 11, color: Color(0xFFE65100), fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              ),
              _buildProfileBody(context, data, name, email),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOnlineBody(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('citizens')
          .doc(_uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF1B5E38)),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: Text('Unable to load profile.'));
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final String name = data['name'] ?? 'User Name';
        final String email = data['email'] ?? 'user@gmail.com';

        // Cache silently for offline use — fire and forget, UI unaffected.
        CitizenDao.cacheProfile(
          uid: _uid,
          name: name,
          email: email,
          phone: data['phone'] ?? '',
          address: data['address'] ?? '',
          emergencyContactName: data['emergencyContactName'] ?? '',
          emergencyContactPhone: data['emergencyContactPhone'] ?? '',
          emergencyContactRelation: data['emergencyContactRelation'] ?? '',
        );

        return SingleChildScrollView(
          child: _buildProfileBody(context, data, name, email),
        );
      },
    );
  }

  Widget _buildProfileBody(
      BuildContext context, Map<String, dynamic> data, String name, String email) {
    return Column(
      children: [
        // Top Header Section
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Color(0xFF1B5E38),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
          padding: const EdgeInsets.only(bottom: 30, top: 10),
          child: Column(
            children: [
              CircleAvatar(
                radius: 46,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor: Colors.grey.shade300,
                  child: const Icon(Icons.person, size: 50, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                email,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Options List Section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 2,
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                // 1. Personal Details Card
                _buildProfileOption(
                  icon: Icons.person_outline,
                  title: 'Personal Details',
                  subtitle: 'View your profile information',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PersonalDetailsScreen(userData: data),
                      ),
                    );
                  },
                ),
                _buildDivider(),

                // 2. Emergency Contacts Card
                _buildProfileOption(
                  icon: Icons.emergency_outlined,
                  title: 'Emergency Contacts',
                  subtitle: 'Personal emergency & rescue helplines',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EmergencyContactsScreen(userData: data),
                      ),
                    );
                  },
                ),
                _buildDivider(),

                // 3. Settings Card
                _buildProfileOption(
                  icon: Icons.settings_outlined,
                  title: 'Settings',
                  subtitle: 'Edit profile & notification preferences',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SettingsMainScreen(),
                      ),
                    );
                  },
                ),
                _buildDivider(),

                // 4. Feedback Card
                _buildProfileOption(
                  icon: Icons.feedback_outlined,
                  title: 'Feedback',
                  subtitle: 'Send your valuable feedback',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const FeedbackScreen(),
                      ),
                    );
                  },
                ),
                _buildDivider(),

                // ── Share SDMS Card ──
                _buildProfileOption(
                  icon: Icons.share_outlined,
                  title: 'Share SDMS',
                  subtitle: 'Share app with friends and emergency contacts',
                  onTap: () {
                    _showShareOptionsSheet(context);
                  },
                ),
                _buildDivider(),

                // 5. Logout Card
                _buildProfileOption(
                  icon: Icons.logout,
                  title: 'Logout',
                  subtitle: 'Sign out from your account',
                  textColor: Colors.red,
                  iconColor: Colors.red,
                  onTap: () => _confirmLogout(context),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildProfileOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color textColor = Colors.black87,
    Color iconColor = const Color(0xFF1B5E38),
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 15,
          color: textColor,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: Colors.black54,
          fontSize: 12,
        ),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 14,
        color: Colors.grey,
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.grey.shade100,
      indent: 60,
      endIndent: 16,
    );
  }
}
// ==========================================================
// PERSONAL DETAILS SCREEN
// ==========================================================
class PersonalDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> userData;

  const PersonalDetailsScreen({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    final String name = userData['name'] ?? 'Not set';
    final String gender = userData['gender'] ?? 'Male';
    final String email = userData['email'] ?? 'Not set';
    final String phone = userData['phone'] ?? 'Not set';
    final String dob = userData['birthday'] ?? userData['dob'] ?? '01/01/2000';
    final String address = userData['address'] ?? 'Not set';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E38),
        title: const Text('Personal Details', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Center(
            child: CircleAvatar(
              radius: 45,
              backgroundColor: Color(0xFF1B5E38),
              child: CircleAvatar(
                radius: 43,
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 50, color: Color(0xFF1B5E38)),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildDetailCard(Icons.person, 'Full Name', name),
          _buildDetailCard(Icons.transgender, 'Gender', gender),
          _buildDetailCard(Icons.email, 'Email Address', email),
          _buildDetailCard(Icons.phone, 'Phone Number', phone),
          _buildDetailCard(Icons.cake, 'Birthday / DOB', dob),
          _buildDetailCard(Icons.home, 'Home Address', address),
        ],
      ),
    );
  }

  Widget _buildDetailCard(IconData icon, String title, String value) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF1B5E38)),
        title: Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
        subtitle: Text(value, style: const TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
// EMERGENCY CONTACTS SCREEN
class EmergencyContactsScreen extends StatelessWidget {
  final Map<String, dynamic> userData;

  const EmergencyContactsScreen({super.key, required this.userData});

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    await launchUrl(launchUri);
  }

  @override
  Widget build(BuildContext context) {
    final String emName = userData['emergencyContactName'] ?? '';
    final String emPhone = userData['emergencyContactPhone'] ?? '';
    final String emRelation = userData['emergencyContactRelation'] ?? '';
    final bool hasEmergencyContact = emPhone.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E38),
        title: const Text('Emergency Contacts', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Personal Emergency Contact',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1B5E38)),
          ),
          const SizedBox(height: 10),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.redAccent,
                child: Icon(Icons.warning, color: Colors.white),
              ),
              title: Text(
                hasEmergencyContact ? emName : 'No Contact Added',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                hasEmergencyContact
                    ? 'Relation: $emRelation\nPhone: $emPhone'
                    : 'No emergency contact registered.',
              ),
              trailing: hasEmergencyContact
                  ? IconButton(
                icon: const Icon(Icons.call, color: Colors.green, size: 26),
                onPressed: () => _makePhoneCall(emPhone),
              )
                  : null,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Rescue Team Helplines',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1B5E38)),
          ),
          const SizedBox(height: 10),
          _buildRescueTile('Disaster Management Helpline', '03107227957'),
          _buildRescueTile('Rescue 1122', '1122'),
          _buildRescueTile('Police Helpline', '15'),
          _buildRescueTile('Edhi Ambulance', '115'),
          _buildRescueTile('Emergency Helpline(punjab)', '1129'),
          _buildRescueTile('National Emergency Helpline', '911'),
        ],
      ),
    );
  }

  Widget _buildRescueTile(String title, String number) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: const Icon(Icons.local_hospital, color: Color(0xFF1B5E38)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(number),
        trailing: IconButton(
          icon: const Icon(Icons.call, color: Colors.green, size: 26),
          onPressed: () => _makePhoneCall(number),
        ),
      ),
    );
  }
}

// ==========================================================
// 1. SETTINGS MAIN SCREEN
// ==========================================================
class SettingsMainScreen extends StatelessWidget {
  const SettingsMainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E38),
        title: const Text('Settings', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSettingCard(
            context,
            icon: Icons.person_outline,
            title: 'Edit Personal Details',
            subtitle: 'Update your name, phone, address & DOB',
            destination: const EditPersonalDetailsScreen(),
          ),
          const SizedBox(height: 12),
          _buildSettingCard(
            context,
            icon: Icons.emergency_outlined,
            title: 'Edit Emergency Contacts',
            subtitle: 'Manage your family and emergency contacts',
            destination: const EditEmergencyContactsScreen(),
          ),
          const SizedBox(height: 12),
          _buildSettingCard(
            context,
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'App Notifications',
            destination: const NotificationSettingsScreen(),
          ),
          const SizedBox(height: 12),
          _buildSettingCard(
            context,
            icon: Icons.lock_outline,
            title: 'Change Password',
            subtitle: 'Update your account security password',
            destination: const ChangePasswordScreen(),
          ),
          const SizedBox(height: 12),
          _buildSettingCard(
            context,
            icon: Icons.info_outline,
            title: 'About App',
            subtitle: 'Learn more about Smart Disaster Management',
            destination: const AboutAppScreen(),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingCard(BuildContext context, {required IconData icon, required String title, required String subtitle, required Widget destination}) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: const Color(0xFF1B5E38).withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: const Color(0xFF1B5E38)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => destination));
        },
      ),
    );
  }
}

// ==========================================================
// 3. CHANGE PASSWORD SCREEN
// ==========================================================
class ChangePasswordScreen extends StatelessWidget {
  const ChangePasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E38),
        title: const Text('Change Password', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(obscureText: true, decoration: InputDecoration(labelText: 'Current Password', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            const SizedBox(height: 14),
            TextField(obscureText: true, decoration: InputDecoration(labelText: 'New Password', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            const SizedBox(height: 14),
            TextField(obscureText: true, decoration: InputDecoration(labelText: 'Confirm New Password', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B5E38), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated successfully!')));
                  Navigator.pop(context);
                },
                child: const Text('Update Password', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================================
// 4. ABOUT APP SCREEN
// ==========================================================
class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  Future<String> _getVersion() async {
    final info = await PackageInfo.fromPlatform();
    return 'Version ${info.version} (Build ${info.buildNumber})';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E38),
        title: const Text('About App', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            const CircleAvatar(
              radius: 50,
              backgroundColor: Color(0xFF1B5E38),
              child: Icon(Icons.security, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 16),
            const Text(
              'Smart Disaster Management System',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1B5E38)),
            ),
            const SizedBox(height: 8),
            FutureBuilder<String>(
              future: _getVersion(),
              builder: (context, snapshot) {
                final versionText = snapshot.data ?? 'Loading...';
                return Text(
                  '$versionText (Citizen App)',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'This application is designed to help citizens stay safe and alert during natural disasters or emergencies. Users can view affected disaster zones on a live map, locate nearby shelters and hospitals, manage emergency contacts, and receive critical broadcast alerts directly from rescue authorities.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
            ),
            const Spacer(),
            const Text(
              'Developed for Public Safety | SDMS',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}