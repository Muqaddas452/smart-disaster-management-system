import 'package:firebase_auth/firebase_auth.dart';

// ─────────────────────────────────────────────────────────────
// Email verification ka niyam (citizen, rescue leader, rescue member — sab).
//
// Naya account banne par Firebase ek link inbox mein bhejta hai. Jab tak
// banda us link par click na kare (yani sabit na ho ke email usi ki hai),
// app use andar nahi jaane deti.
//
// PURANE ACCOUNTS: jo is cutoff se PEHLE bane the (testing wale), unhein
// verify karne par majboor nahi kiya jata, warna wo lock ho jate. Agar sab
// purane accounts bhi verify karwane hon to cutoff ko 2000-01-01 kar dein.
// ─────────────────────────────────────────────────────────────
final DateTime kEmailVerificationEnforcedFrom = DateTime.utc(2026, 10, 1, 11, 0);

/// true => is user ko verify screen dikhani hai.
bool needsEmailVerification(User? user) {
  if (user == null) return false;
  if (user.emailVerified) return false;
  final created = user.metadata.creationTime;
  if (created == null) return true; // ghair-yaqeeni => verify karwao
  return created.toUtc().isAfter(kEmailVerificationEnforcedFrom);
}

/// Verification mail bhejta hai. Firebase kuch dair mein dobara bhejne par
/// 'too-many-requests' deta hai — us surat mein false.
Future<bool> sendVerificationEmail(User user) async {
  try {
    await user.sendEmailVerification();
    return true;
  } on FirebaseAuthException catch (_) {
    return false;
  } catch (_) {
    return false;
  }
}
