// Shared helper: team ke leader ke FCM tokens dhoondna (index.js aur
// app_notifications.js dono use karte hain).
//
// Leader ka token alag alag jagah ho sakta hai, is liye sab dekhte hain:
//  1. rescueTeamUsers jinka teamId == task.teamId aur jo leader hon
//     (isLeader == true  YA  role == 'rescue_leader')
//  2. rescueTeams/{teamId} ke leaderUid / leaderId se rescueTeamUsers/{id}
//  3. wahi id `users/{id}` mein (purana admin-panel tareeqa)
const { getFirestore } = require("firebase-admin/firestore");

async function findLeaderTokens(teamId, extraIds = []) {
  const db = getFirestore(); // initializeApp() ke baad hi
  const tokens = new Set();
  const ids = new Set(extraIds.map(String).filter(Boolean));
  const tid = String(teamId || "").trim();

  try {
    if (tid) {
      const q = await db.collection("rescueTeamUsers")
        .where("teamId", "==", tid)
        .get();
      for (const d of q.docs) {
        const isLeader = d.get("isLeader") === true || d.get("role") === "rescue_leader";
        if (isLeader && d.get("fcmToken")) tokens.add(d.get("fcmToken"));
      }

      const team = await db.collection("rescueTeams").doc(tid).get();
      if (team.exists) {
        for (const f of ["leaderUid", "leaderId"]) {
          const v = String(team.get(f) || "").trim();
          if (v) ids.add(v);
        }
      }
    }

    for (const id of ids) {
      for (const col of ["rescueTeamUsers", "users"]) {
        const s = await db.collection(col).doc(id).get();
        if (s.exists && s.get("fcmToken")) tokens.add(s.get("fcmToken"));
      }
    }
  } catch (e) {
    console.error("findLeaderTokens failed:", e);
  }

  console.log(`findLeaderTokens(team=${tid}): ${tokens.size} token(s)`);
  return [...tokens];
}

module.exports = { findLeaderTokens };
