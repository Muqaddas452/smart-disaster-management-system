import 'package:flutter/material.dart';
import 'package:smart_disaster_management_system/profile%20_screen.dart';
import 'package:smart_disaster_management_system/splashscreen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'welcomescreen.dart';
import 'signupscreen.dart';
import 'login_screen.dart';
import 'forgotpassword.dart';
import 'home_screen.dart';
import 'report_screen.dart';
import 'safety_tips_screen.dart';
import 'alert_screen.dart';
import 'alert_details_screen.dart';
import 'gps_access_screen.dart';

// TODO: user ka selected city/district yahan se ya profile se lena hai.
// Ye topic naam backend ke notification_service.py ke _topic_for_district()
// function ke exact same format mein hona chahiye: "district_<name lowercase>"
const String kUserDistrictTopic = "district_karachi";

// Background messages ke liye top-level function hona ZAROORI hai
// (class ke andar nahi ho sakta, warna Firebase isko call nahi kar payega)
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

  // Background/terminated state ke liye handler register karo
  FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

  // User se notification permission maango (Android 13+ aur iOS dono ke liye zaroori)
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // Apne district ke topic ko subscribe karo — bas isi topic ke alerts aayenge
  await FirebaseMessaging.instance.subscribeToTopic(kUserDistrictTopic);

  // App foreground mein khuli ho aur notification aaye to yahan handle hota hai
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('[FCM foreground] ${message.notification?.title}: ${message.notification?.body}');
    // TODO: chahen to yahan flutter_local_notifications se in-app banner dikha sakte hain,
    // ya phir seedha app ke andar ek SnackBar/dialog dikha dein.
  });

  // Notification tap karke app open ki gayi ho to yahan detect hota hai
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('[FCM tapped] district=${message.data['district']} disaster=${message.data['disaster']}');
    // TODO: seedha AlertsScreen ya AlertDetailsScreen par navigate karayen
    // navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const AlertsScreen()));
  });

  runApp(const SmartDisasterApp());
}

class SmartDisasterApp extends StatelessWidget {
  const SmartDisasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
























