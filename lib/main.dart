import 'package:flutter/material.dart';
import 'package:smart_disaster_management_system/splashscreen.dart';
import 'welcomescreen.dart';
import 'signupscreen.dart';
import 'login_screen.dart';
import 'forgotpassword.dart';
import 'home_screen.dart';
import 'report_screen.dart';
import 'alert_screen.dart';
import 'alert_details_screen.dart';
import 'gps_access_screen.dart';

void main() {
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
    );
  }
}