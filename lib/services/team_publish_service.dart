import 'package:cloud_firestore/cloud_firestore.dart';

/// Leader ki team ki request admin ko TAB dikhao jab uski email verify ho jaye.
///
/// Registration ke waqt (agar email verify karwani ho) team ka data
/// `rescueTeamUsers/{uid}.pendingTeam` mein ruka rehta hai — `rescueTeams`
/// mein nahi, is liye admin panel ko request nazar nahi aati. Email verify
/// hote hi (login / verify screen ke baad) yeh function us data ko
/// `rescueTeams/{teamId}` mein likh deta hai, aur admin ko "Pending" request
/// dikhne lagti hai.
///
/// Dobara chalane par koi nuqsaan nahi (agar pendingTeam na ho to kuch nahi
/// karta).
Future<void> publishPendingTeam(String uid) async {
  try {
    final userRef =
        FirebaseFirestore.instance.collection('rescueTeamUsers').doc(uid);
    final snap = await userRef.get();
    final data = snap.data();
    if (data == null) return;

    final pending = data['pendingTeam'];
    if (pending is! Map) return;

    final String teamId = (data['teamId'] ?? '').toString();
    if (teamId.isEmpty) return;

    final teamData = Map<String, dynamic>.from(pending);
    teamData['createdAt'] = FieldValue.serverTimestamp();

    final batch = FirebaseFirestore.instance.batch();
    batch.set(
        FirebaseFirestore.instance.collection('rescueTeams').doc(teamId),
        teamData);
    batch.update(userRef, {'pendingTeam': FieldValue.delete()});
    await batch.commit();
  } catch (_) {
    // Agle login / app khulne par dobara koshish ho jayegi.
  }
}
