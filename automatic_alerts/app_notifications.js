// ==========================================================
// APP NOTIFICATIONS  (Citizen + Rescue Leader + Rescue Member)
//
// Is file ke functions index.js ke aakhir mein
//   Object.assign(exports, require("./app_notifications"));
// se load hote hain. Pehle se maujood functions (automatic alerts,
// onRescueTeamAssigned, onRescueStatusChanged, sendUserNotification)
// ko yeh nahi chhedta - yeh sirf WOH notifications add karta hai jo
// pehle nahi thin:
//
//  1. Leader task mein member assign kare      -> member ko push
//  2. Member task se hata diya jaye             -> member ko push
//  3. Member ka status badle (Enroute...)       -> leader ko "Ali is now Enroute"
//  4. Pehla member Enroute / In Progress jaye   -> citizen ko push
//  5. Task resolve ho                           -> leader + members ko push
//  6. Admin ka manual alert (broadcast_alerts)  -> SAB ko (topic)
//  7. Automatic alert                           -> SAB rescue leaders + members ko
//     (citizens ko automatic alert pehle se radius ke hisaab se jata hai)
//  8. Citizen ki report ka status admin badle   -> us citizen ko
//
// Push server se jata hai, is liye app BAND ho tab bhi aata hai.
// ==========================================================

const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");

const { getApps, initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

if (!getApps().length) {
  initializeApp();
}

const { findLeaderTokens } = require("./push_helpers");

const db = getFirestore();
const messaging = getMessaging();

// App ke main.dart mein kUserDistrictTopic yahi hai. Har user (citizen,
// leader, member) is topic par subscribe hota hai.
const ALERT_TOPIC = "district_karachi";

// Admin panel ka manual alert (Flask wala) real phone tak nahi pahunchta,
// is liye yahan se topic par bheja jata hai. Agar kabhi dobara double aaye
// to isay false kar dein.
const SEND_MANUAL_ALERT_TO_TOPIC = true;


// ----------------------------------------------------------
// helpers
// ----------------------------------------------------------

const STATUS_LABEL = {
  assigned: "Assigned",
  enroute: "Enroute",
  in_progress: "In Progress",
  completed: "Completed",
};

// App ke utils/priority_helper.dart jaisa hi: sab jagah 'high' | 'medium' | 'low'.
function normalizePriority(raw) {
  const v = String(raw == null ? "" : raw).trim().toLowerCase();
  if (!v) return "";
  if (/high|critical|severe|urgent/.test(v) || v === "red" || v === "3") return "high";
  if (/med|moderate/.test(v) || v === "orange" || v === "yellow" || v === "2") return "medium";
  if (/low|minor/.test(v) || v === "green" || v === "1") return "low";
  return "";
}

const PRIORITY_FIELDS = [
  "priority", "severity_level", "severityLevel", "severity",
  "riskLevel", "risk_level", "risk", "alertPriority",
];

function priorityOf(data) {
  for (const f of PRIORITY_FIELDS) {
    const p = normalizePriority(data[f]);
    if (p) return p;
  }
  for (const n of ["report", "alert", "source"]) {
    if (data[n] && typeof data[n] === "object") {
      for (const f of PRIORITY_FIELDS) {
        const p = normalizePriority(data[n][f]);
        if (p) return p;
      }
    }
  }
  return "medium";
}

function cap(s) {
  return s ? s[0].toUpperCase() + s.slice(1) : s;
}

function taskLabel(t) {
  return String(t.emergencyType || t.type || t.title || "Emergency").trim();
}

async function tokensForUids(collection, uids) {
  const ids = [...new Set((uids || []).map(String).filter(Boolean))];
  if (ids.length === 0) return [];
  const snaps = await db.getAll(...ids.map((id) => db.collection(collection).doc(id)));
  return snaps.map((s) => (s.exists ? s.get("fcmToken") : null)).filter(Boolean);
}

async function leaderTokens(teamId, extraIds = []) {
  return findLeaderTokens(teamId, extraIds);
}

// Citizen id: task par ho to wahi, warna manual_reports se.
async function resolveCitizenId(task) {
  const direct = String(task.citizenId || "").trim();
  if (direct) return direct;
  const reportId = String(task.reportId || "").trim();
  if (!reportId) return "";
  try {
    const r = await db.collection("manual_reports").doc(reportId).get();
    if (!r.exists) return "";
    const d = r.data() || {};
    return String(d.citizenId || d.reportedBy || d.userId || "").trim();
  } catch (e) {
    console.error("resolveCitizenId failed:", e);
    return "";
  }
}

async function sendToTokens(tokens, title, body, data = {}) {
  const unique = [...new Set((tokens || []).filter(Boolean))];
  if (unique.length === 0) {
    console.log(`push skipped (no tokens): ${title}`);
    return;
  }

  // FCM data mein sirf string values hoti hain.
  const strData = {};
  Object.keys(data).forEach((k) => {
    strData[k] = String(data[k]);
  });

  for (let i = 0; i < unique.length; i += 500) {
    const chunk = unique.slice(i, i + 500);
    const res = await messaging.sendEachForMulticast({
      tokens: chunk,
      notification: { title, body },
      data: strData,
      android: { priority: "high", notification: { sound: "default" } },
      apns: { payload: { aps: { sound: "default" } } },
    });
    console.log(`push "${title}": ${res.successCount} ok, ${res.failureCount} failed`);
  }
}

// Citizen ko notification: sirf "Notifications" collection mein likhte hain.
// Push index.js ka sendUserNotification (Notifications/{id} onCreate) bhejta hai,
// is liye yahan se direct push NAHI bhejte (warna do dafa aati).
async function notifyCitizen(citizenId, taskId, title, message) {
  if (!citizenId) return;
  try {
    await db.collection("Notifications").add({
      userId: citizenId,
      taskId,
      recipientType: "citizen",
      title,
      message,
      type: "rescue",
      read: false,
      createdAt: FieldValue.serverTimestamp(),
    });
  } catch (e) {
    console.error(`notifyCitizen failed (${citizenId}):`, e);
  }
}

// Sab rescue users (leaders + members) jinke paas token hai.
async function allRescueTokens() {
  const snap = await db.collection("rescueTeamUsers").get();
  const tokens = [];
  for (const d of snap.docs) {
    const st = String(d.get("status") || "").toLowerCase();
    if (st === "rejected" || st === "blocked" || st === "suspended") continue;
    const t = d.get("fcmToken");
    if (t) tokens.push(t);
  }
  return tokens;
}

// "Aap" jaisa member ka naam task ke assignedMembers se.
function memberName(task, uid) {
  const list = Array.isArray(task.assignedMembers) ? task.assignedMembers : [];
  const m = list.find((x) => x && (x.uid === uid || x.id === uid));
  return (m && (m.name || m.fullName)) || "A member";
}


// ==========================================================
// TASK UPDATE  (tasks/{taskId})
// ==========================================================

exports.notifyTaskChanges = onDocumentUpdated(
  "tasks/{taskId}",
  async (event) => {
    const before = event.data?.before?.data() || {};
    const after = event.data?.after?.data() || {};
    const taskId = event.params.taskId;
    const label = taskLabel(after);
    const taskData = { type: "task", taskId };

    try {
      const beforeIds = (before.assignedMemberIds || []).map(String);
      const afterIds = (after.assignedMemberIds || []).map(String);

      // ---- 1. Naye assign hue members ------------------------------
      const added = afterIds.filter((id) => !beforeIds.includes(id));
      if (added.length) {
        const pr = priorityOf(after);
        const tokens = await tokensForUids("rescueTeamUsers", added);
        await sendToTokens(
          tokens,
          `${pr === "high" ? "HIGH PRIORITY: " : ""}New task assigned to you`,
          `${label}${after.address ? " • " + after.address : ""} (${cap(pr)} priority)`,
          taskData,
        );
      }

      // ---- 2. Task se hata diye gaye members -----------------------
      const removed = beforeIds.filter((id) => !afterIds.includes(id));
      if (removed.length) {
        const tokens = await tokensForUids("rescueTeamUsers", removed);
        await sendToTokens(
          tokens,
          "Removed from task",
          `You are no longer assigned to: ${label}`,
          taskData,
        );
      }

      // ---- 3. Member ka status badla => leader ko ------------------
      const bMs = before.memberStatuses || {};
      const aMs = after.memberStatuses || {};

      const ms = (v) => (v && typeof v.toMillis === "function" ? v.toMillis() : "");
      const leaderOverrode = ms(before.statusOverriddenAt) !== ms(after.statusOverriddenAt);

      const changedUids = Object.keys(aMs).filter((u) => aMs[u] && aMs[u] !== bMs[u]);

      if (changedUids.length && !leaderOverrode) {
        const lines = changedUids.map(
          (u) => `${memberName(after, u)} is now ${STATUS_LABEL[aMs[u]] || aMs[u]}`,
        );
        const tokens = await leaderTokens(after.teamId);
        await sendToTokens(tokens, label, lines.join("\n"), taskData);
      }

      // ---- 4. Citizen ko: pehla member Enroute / In Progress -------
      const rank = { assigned: 0, enroute: 1, in_progress: 2, completed: 3 };
      const maxRank = (m) =>
        Object.values(m).reduce((mx, s) => Math.max(mx, rank[s] ?? 0), 0);
      const bRank = maxRank(bMs);
      const aRank = maxRank(aMs);

      if (after.status !== "resolved" && aRank > bRank && !leaderOverrode) {
        const citizenId = await resolveCitizenId(after);
        if (aRank === 1 && bRank < 1) {
          await notifyCitizen(
            citizenId, taskId,
            "🚑 Rescue Team En Route",
            "A rescue member is now on the way to your location.",
          );
        } else if (aRank >= 2 && bRank < 2) {
          await notifyCitizen(
            citizenId, taskId,
            "📍 Rescue In Progress",
            "The rescue team has arrived and is responding to your emergency.",
          );
        }
      }

      // ---- 5. Task resolve => leader + members ---------------------
      if (before.status !== "resolved" && after.status === "resolved") {
        const tokens = [
          ...(await leaderTokens(after.teamId)),
          ...(await tokensForUids("rescueTeamUsers", afterIds)),
        ];
        await sendToTokens(tokens, "Task resolved", `${label} has been completed.`, taskData);
      }
    } catch (e) {
      console.error("notifyTaskChanges error:", e);
    }
    return null;
  },
);


// ==========================================================
// ALERTS  (broadcast_alerts/{alertId})
// ==========================================================

exports.notifyBroadcastAlert = onDocumentCreated(
  "broadcast_alerts/{alertId}",
  async (event) => {
    const a = event.data?.data();
    if (!a) return null;

    try {
      const alertId = event.params.alertId;
      const pr = priorityOf(a);
      const high = pr === "high";
      const base = String(a.title || a.disaster || a.disasterType || "Emergency Alert");
      const area = String(a.targetArea || a.city || a.district || "");
      const text = String(a.message || "Emergency alert issued.");
      const title = `${high && !/high/i.test(base) ? "HIGH ALERT: " : ""}${base}`;
      const body = `${area ? area + " — " : ""}${text}`;
      const data = { type: "alert", alertId, priority: pr };

      const isAutomatic = !!a.sourceAlertId;

      if (isAutomatic) {
        // Citizens ko createAffectedZone pehle hi radius ke hisaab se bhej chuka.
        // Yahan SAB leaders + members ko bhejte hain.
        const tokens = await allRescueTokens();
        await sendToTokens(tokens, title, body, data);
      } else if (SEND_MANUAL_ALERT_TO_TOPIC) {
        // Admin ka manual alert => citizen + leader + member (sab topic par hain).
        await messaging.send({
          topic: ALERT_TOPIC,
          notification: { title, body },
          data,
          android: { priority: "high", notification: { sound: "default" } },
          apns: { payload: { aps: { sound: "default" } } },
        });
        console.log(`manual alert sent to topic ${ALERT_TOPIC}: ${alertId}`);
      }
    } catch (e) {
      console.error("notifyBroadcastAlert error:", e);
    }
    return null;
  },
);


// ==========================================================
// REPORT STATUS  (manual_reports/{reportId})
//
// Jab admin report screen se status badle to citizen ko batao.
// Agar status task ke status se mirror hua (statusUpdatedAt badla),
// to citizen ko onRescueStatusChanged pehle hi bata chuka - skip.
// ==========================================================

exports.notifyReportStatus = onDocumentUpdated(
  "manual_reports/{reportId}",
  async (event) => {
    const before = event.data?.before?.data() || {};
    const after = event.data?.after?.data() || {};

    if (before.status === after.status) return null;

    const ms = (v) => (v && typeof v.toMillis === "function" ? v.toMillis() : "");
    if (ms(before.statusUpdatedAt) !== ms(after.statusUpdatedAt)) return null;

    const citizenId = String(
      after.citizenId || after.reportedBy || after.userId || "",
    ).trim();
    if (!citizenId || citizenId === "anonymous") return null;

    try {
      await notifyCitizen(
        citizenId,
        "",
        "Your report was updated",
        `${after.incident_type || after.emergencyType || "Emergency report"}: ${after.status}`,
      );
    } catch (e) {
      console.error("notifyReportStatus error:", e);
    }
    return null;
  },
);


// ==========================================================
// ADMIN APPROVE / REJECT  (rescueTeamUsers/{uid}.status)
//
// Admin "Approve" dabaye to approveTeam() rescueTeamUsers ke status ko
// 'approved' (ya 'rejected') kar deta hai - us user ko batao.
// ==========================================================

exports.notifyRescueApproval = onDocumentUpdated(
  "rescueTeamUsers/{uid}",
  async (event) => {
    const before = event.data?.before?.data() || {};
    const after = event.data?.after?.data() || {};

    const b = String(before.status || "").toLowerCase();
    const a = String(after.status || "").toLowerCase();
    if (a === b || !after.fcmToken) return null;

    let title = "";
    let body = "";
    if (a === "approved" || (a === "active" && b === "pending")) {
      title = "Account approved";
      body = "Your rescue team account has been approved by the admin. You can now log in and start.";
    } else if (a === "rejected") {
      title = "Account rejected";
      body = "Your rescue team registration was rejected by the admin.";
    } else {
      return null;
    }

    try {
      await sendToTokens([after.fcmToken], title, body, {
        type: "approval",
        status: a,
      });
    } catch (e) {
      console.error("notifyRescueApproval error:", e);
    }
    return null;
  },
);


// ==========================================================
// TEAM APPROVE / REJECT  ->  leader ka login status
//
// Admin "Approve" dabata hai to admin panel rescueTeams.status badalta hai
// aur rescueTeamUsers.status ko 'approved' karne ki koshish karta hai. Lekin
// Firestore Rules rescueTeamUsers par sirf us user ko write dene deti hain,
// is liye admin ka wo write permission-denied ho jata tha aur leader app mein
// "Under review / Pending" par atka rehta tha.
//
// Server (Admin SDK) par rules lagu nahi hote, is liye yahan se sync hota hai:
//   rescueTeams.status  Available / On Mission / ...  => users 'approved'
//   rescueTeams.status  Rejected                      => users 'rejected'
// Sirf un users ko badalta hai jo abhi 'pending' hain. Dobara chalne par
// koi nuqsaan nahi.
// ==========================================================

exports.syncTeamApproval = onDocumentUpdated(
  "rescueTeams/{teamId}",
  async (event) => {
    const after = event.data?.after?.data() || {};
    const st = String(after.status || "").trim().toLowerCase();
    const teamId = event.params.teamId;

    let target = "";
    if (st === "rejected") {
      target = "rejected";
    } else if (st && st !== "pending" && st !== "unverified") {
      target = "approved";
    } else {
      return null;
    }

    try {
      const q = await db.collection("rescueTeamUsers")
        .where("teamId", "==", teamId)
        .where("status", "==", "pending")
        .get();

      if (q.empty) return null;

      const batch = db.batch();
      q.docs.forEach((d) => batch.update(d.ref, { status: target }));
      await batch.commit();
      console.log(`syncTeamApproval: ${q.size} user(s) of team ${teamId} -> ${target}`);
    } catch (e) {
      console.error("syncTeamApproval error:", e);
    }
    return null;
  },
);


// ==========================================================
// TASK KHATAM  ->  TEAM DOBARA "Available"
//
// Rescue app (leader / member) task ko seedha tasks/{id}.status = 'resolved'
// (ya leader 'rejected') kar deti hai, lekin rescueTeams ka status "On Mission"
// hi rehta tha - sirf admin panel ke apne "complete" button par team free hoti
// thi. Ab jab bhi task resolved / rejected ho, chahe kisi ne bhi kiya ho,
// server team ko Available kar deta hai (admin panel jaisa hi).
//
// Safety: team tabhi free hoti hai jab uski assignedTaskId yehi task ho -
// agar team ko is dauran kisi doosre task par bhej diya gaya ho to usay nahi
// chhoota.
// ==========================================================

exports.releaseTeamOnTaskEnd = onDocumentUpdated(
  "tasks/{taskId}",
  async (event) => {
    const before = event.data?.before?.data() || {};
    const after = event.data?.after?.data() || {};
    const taskId = event.params.taskId;

    const bs = String(before.status || "").trim().toLowerCase();
    const as = String(after.status || "").trim().toLowerCase();
    if (bs === as) return null;
    if (as !== "resolved" && as !== "rejected") return null;

    const teamId = String(after.teamId || "").trim();
    if (!teamId) return null;

    try {
      const teamRef = db.collection("rescueTeams").doc(teamId);
      const team = await teamRef.get();
      if (!team.exists) return null;

      const assigned = String(team.get("assignedTaskId") || "").trim();
      if (assigned && assigned !== taskId) {
        console.log(`releaseTeam: team ${teamId} ab doosre task (${assigned}) par hai - nahi chhoota.`);
        return null;
      }

      await teamRef.update({
        status: "Available",
        assignedTaskId: FieldValue.delete(),
        assignedReportId: FieldValue.delete(),
        lastUpdated: FieldValue.serverTimestamp(),
      });
      console.log(`releaseTeam: team ${teamId} -> Available (task ${taskId} ${as})`);
    } catch (e) {
      console.error("releaseTeamOnTaskEnd error:", e);
    }
    return null;
  },
);
