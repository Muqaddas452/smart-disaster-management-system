import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'firebase_options.dart';
import 'package:sqflite/sqflite.dart';

// --- Screen Imports ---
import 'package:smartdisaster/citizen_screens/profile_completion_screen.dart';
import 'splashscreen.dart';
import 'welcomescreen.dart';
import 'citizen_screens/notification_settings_screen.dart';
import 'package:smartdisaster/citizen_screens/all_reports_screen.dart';
import 'role_selection_screen.dart';
import 'package:smartdisaster/citizen_screens/signupscreen.dart';
import 'package:smartdisaster/citizen_screens/login_screen.dart';
import 'package:smartdisaster/citizen_screens/forgotpassword.dart';
import 'package:smartdisaster/citizen_screens/citizen_home_screen.dart';
import 'package:smartdisaster/citizen_screens/report_screen.dart';
import 'package:smartdisaster/citizen_screens/safety_tips_screen.dart';
import 'package:smartdisaster/citizen_screens/alert_screen.dart';
import 'package:smartdisaster/citizen_screens/alert_details_screen.dart';
import 'package:smartdisaster/citizen_screens/gps_access_screen.dart';
import 'package:smartdisaster/rescue_team_screens/rescue_home_screen.dart'; // Rescue Team Home Screen Import
// NEW — needed so AuthWrapper can route pending/rejected rescue accounts
// to the same screen the login flow already uses, instead of letting
// them fall through to the dashboard on app reopen.
import 'package:smartdisaster/rescue_team_screens/pending_approval_screen.dart';
import 'package:smartdisaster/services/email_verification.dart';
import 'package:smartdisaster/services/team_publish_service.dart';
import 'package:smartdisaster/rescue_team_screens/view_task_screen.dart';
import 'package:smartdisaster/verify_email_screen.dart';

// Notification se screen kholne (aur foreground mein banner dikhane) ke liye.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();

// Notification ke data se sahi screen kholo (abhi: task notification => task details).
void _openFromNotification(Map<String, dynamic> data) {
  if (FirebaseAuth.instance.currentUser == null) return;
  final String? taskId = data['taskId']?.toString();
  if (taskId != null && taskId.isNotEmpty) {
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => ViewTaskScreen(taskId: taskId)),
    );
  }
}

// FCM topic configuration for specific district alerts
const String kUserDistrictTopic = "district_karachi";

// Top-level background message handler for Firebase Cloud Messaging
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('[FCM background] ${message.notification?.title}: ${message.notification?.body}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Register background message handler — this is just registering a
  // callback, no network call, so it's safe to keep here.
  FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);


  runApp(const SmartDisasterApp());

  // Fire-and-forget FCM setup — runs in the background after the UI is
  // already showing. Wrapped in try/catch so a failure (e.g. no internet)
  // is silently ignored instead of throwing an unhandled exception; the
  // person can just use the app normally and FCM setup will succeed
  // automatically next time there's a connection (permission +
  // subscribeToTopic are safe to call again).
  _setupFcm();
}

Future<void> _setupFcm() async {
  try {
    // Request notification permissions for iOS and Android 13+
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Subscribe user to target district notification topic
    await FirebaseMessaging.instance.subscribeToTopic(kUserDistrictTopic);
  } catch (e) {
    // Offline or FCM unavailable — safe to ignore, this just means push
    // notifications won't be set up until the next time there's internet.
    print('[FCM setup] skipped: $e');
  }
  //show snackbar .
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    final n = message.notification;
    if (n == null) return;
    final bool hasTask = message.data['taskId'] != null;
    messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 7),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(n.title ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
              if ((n.body ?? '').isNotEmpty) Text(n.body!),
            ],
          ),
          action: hasTask
              ? SnackBarAction(
            label: 'VIEW',
            onPressed: () => _openFromNotification(message.data),
          )
              : null,
        ),
      );
  });

  // Notification tap -- app in background
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    _openFromNotification(message.data);
  });

  // Notification par tap — app was terminated
  try {
    final RemoteMessage? initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      // chance for AuthWrapper to resolve login/role
      Future.delayed(const Duration(seconds: 2), () => _openFromNotification(initial.data));
    }
  } catch (_) {}
}

class SmartDisasterApp extends StatelessWidget {
  const SmartDisasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: messengerKey,
      title: 'Smart Disaster Management System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B5E20)),
        useMaterial3: true,
      ),

      home: const SplashScreen(),
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const SignUpScreen(),
        '/profileCompletion': (context) => const ProfileCompletionScreen(),
        '/citizenHome': (context) => const HomeScreen(),
      },
    );
  }
}

// ── MULTI-ROLE AUTHENTICATION WRAPPER ──
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {

  // Checks both authIndex and rescueTeamUsers to determine exact role
  // AND approval status — this is what runs every time the app opens
  // while a session is still signed in.
  Future<Map<String, dynamic>> _getUserRoleAndDetails(String uid) async {
    try {
      String role = '';
      String teamId = '';
      String teamName = 'Rescue Team';
      // Citizens have no approval gate at all, so default to 'approved'
      // for them — this only matters once `role` turns out to be a
      // rescue leader/member below.
      String status = 'approved';

      // 1. Fetch role from 'authIndex'
      final authIndexDoc = await FirebaseFirestore.instance
          .collection('authIndex')
          .doc(uid)
          .get();

      if (authIndexDoc.exists && authIndexDoc.data() != null) {
        role = (authIndexDoc.data()!['role'] ?? '').toString().trim().toLowerCase();
      }

      // 2. Fetch specific profile details from 'rescueTeamUsers'
      final rescueDoc = await FirebaseFirestore.instance
          .collection('rescueTeamUsers')
          .doc(uid)
          .get();

      if (rescueDoc.exists && rescueDoc.data() != null) {
        final rescueData = rescueDoc.data()!;

        // Detailed role from rescueTeamUsers (e.g. 'rescue_leader', 'leader', 'member', etc.)
        final String detailedRole = (rescueData['role'] ?? '').toString().trim().toLowerCase();

        if (detailedRole.isNotEmpty) {
          role = detailedRole;
        }

        teamId = (rescueData['teamId'] ?? rescueData['team_id'] ?? '').toString();
        teamName = (rescueData['teamName'] ?? rescueData['team_name'] ?? 'Rescue Team').toString();

        // FIXED: this field was never being read before, so AuthWrapper
        // had no idea whether a rescue account was actually approved —
        // it only looked at `role`, which gets set at registration time
        // regardless of approval status. That let a pending/rejected
        // account reach the dashboard just by staying signed in and
        // reopening the app, even while the Login screen and Pending
        // Approval screen correctly still treated it as unapproved.
        status = (rescueData['status'] ?? 'pending').toString().trim().toLowerCase();
      }

      // Citizens: check whether profile completion was actually finished,
      // otherwise reopening the app mid-signup skipped the profile screen.
      bool profileComplete = true;
      if (role == 'citizen') {
        final citizenDoc = await FirebaseFirestore.instance
            .collection('citizens')
            .doc(uid)
            .get();
        profileComplete = citizenDoc.data()?['isProfileComplete'] ?? false;
      }

      return {
        'role': role,
        'teamId': teamId,
        'teamName': teamName,
        'status': status,
        'profileComplete': profileComplete,
      };
    } catch (e) {
      print('Error checking role: $e');
      return {'role': 'citizen', 'status': 'approved'};
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        if (snapshot.hasData && snapshot.data != null) {
          // reload() ke baad snapshot.data purana ho sakta hai — currentUser lo.
          final User user = FirebaseAuth.instance.currentUser ?? snapshot.data!;
          final String uid = user.uid;

          // Email verify hone tak (citizen / leader / member) andar nahi.
          if (needsEmailVerification(user)) {
            return VerifyEmailScreen(onVerified: () {
              if (mounted) setState(() {});
            });
          }

          return FutureBuilder<Map<String, dynamic>>(
            // Verify ho chuki: if leader's team request is pending send to admin then resolve role
            future: publishPendingTeam(uid)
                .then((_) => _getUserRoleAndDetails(uid)),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(color: Color(0xFF1B5E20)),
                  ),
                );
              }

              if (userSnapshot.hasData) {
                final userData = userSnapshot.data!;
                final String role = userData['role'] ?? 'citizen';
                final String teamId = userData['teamId'] ?? '';
                final String teamName = userData['teamName'] ?? 'Rescue Team';
                final String status = userData['status'] ?? 'approved';

                // Check Leader (Matches 'rescue_team', 'rescue_leader', 'leader', 'team_leader')
                final bool isLeader = role == 'rescue_team' ||
                    role.contains('leader') ||
                    role == 'rescue_leader' ||
                    role == 'team_leader';

                // Check Member
                final bool isMember = role.contains('member') ||
                    role == 'rescue_member' ||
                    role == 'team_member';

                if (!(isLeader || isMember) &&
                    userData['profileComplete'] == false) {
                  return const ProfileCompletionScreen();
                }

                if (isLeader || isMember) {

                  // pending or rejected account is sent to
                  // PendingApprovalScreen, which keeps listening
                  // live and will move them on automatically once (and
                  // only once) an admin actually approves the team.
                  // Leaders are 'approved' by admin; members join via an
                  // invitation and are saved with status 'active' (no admin
                  // approval step), so both must be allowed through.
                  if (status == 'approved' || status == 'active') {
                    return RescueTeamHomeScreen(
                      isLeader: isLeader,
                      teamId: teamId,
                      teamName: teamName,
                    );
                  } else {
                    return const PendingApprovalScreen();
                  }
                }
              }

              // Fallback to Citizen Home
              return const HomeScreen();
            },
          );
        }
        return const WelcomeScreen();
      },
    );
  }
}
