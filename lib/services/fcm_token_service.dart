import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Ye service FCM token generate karke Firestore ke 'citizens' collection
// mein save karta hai. Isse Admin Panel har citizen ko individually
// (ya area-wise) notification bhej sakega.
class FcmTokenService {
  // Firestore aur FCM ke instances — dono baar baar use honge is class mein
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // Ye function login/signup ke turant baad call hota hai.
  // uid = current logged-in user ka Firebase Auth UID
  static Future<void> saveFCMToken(String uid) async {
    try {
      // Device ka current FCM token generate karo
      final String? token = await _messaging.getToken();

      // Agar token null aaya (rare case, jaise permission na mili ho)
      // to kuch mat karo, warna Firestore mein null save ho jayega
      if (token == null) {
        print('[FCM] Token null aaya, save nahi hua.');
        return;
      }

      // Firestore ke 'citizens' collection mein uid wali document mein token daalo.
      // set() with merge:true isliye use kiya hai taake:
      // - agar document abhi naya bana hi hai (signup ke waqt), error na aaye
      // - agar document pehle se exist karta hai, sirf fcmToken field update ho,
      //   baaki fields (name, email, phone) safe rahen
      await _firestore.collection('citizens').doc(uid).set(
        {'fcmToken': token},
        SetOptions(merge: true),
      );

      print('[FCM] Token save ho gaya citizens/$uid ke liye.');
    } catch (e) {
      // Agar kuch bhi fail ho (network, permission etc) to app crash na ho,
      // sirf error print ho jaye — login/signup flow rukna nahi chahiye
      print('[FCM] Token save karte waqt error: $e');
    }
  }

  // Ye function ek listener set karta hai jo tab automatically trigger hota
  // hai jab FCM apna token refresh kar de (kabhi kabhi hota hai — app
  // reinstall, ya purana token expire hone par). Isse Firestore mein
  // hamesha latest token rehta hai.
  //
  // Isko app start hone par call karo (main.dart mein), sirf agar user
  // already logged in ho.
  static void listenForTokenRefresh(String uid) {
    _messaging.onTokenRefresh.listen((String newToken) async {
      try {
        await _firestore.collection('citizens').doc(uid).set(
          {'fcmToken': newToken},
          SetOptions(merge: true),
        );
        print('[FCM] Refreshed token save ho gaya citizens/$uid ke liye.');
      } catch (e) {
        print('[FCM] Token refresh save karte waqt error: $e');
      }
    });
  }
}