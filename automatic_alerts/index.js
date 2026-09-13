const {
  onDocumentWritten,
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");

const { onCall, HttpsError } =
  require("firebase-functions/v2/https");

const { initializeApp } =
  require("firebase-admin/app");

const { getAuth } =
  require("firebase-admin/auth");

const {
  getFirestore,
  FieldValue,
} = require("firebase-admin/firestore");

const { getMessaging } =
  require("firebase-admin/messaging");

const crypto = require("crypto");
const nodemailer = require("nodemailer");


// ==========================================================
// INITIALIZE FIREBASE ADMIN
// ==========================================================

initializeApp();

const db = getFirestore();
const messaging = getMessaging();


// ==========================================================
// PART 1
// ARCHIVE OPENWEATHER DATA
// ==========================================================

exports.archiveOpenWeatherData = onDocumentWritten(
  "openweathermap/{weatherId}",

  async (event) => {

    const afterData =
      event.data?.after?.data();

    if (!afterData) {

      console.log(
        "Weather document deleted. Nothing to archive."
      );

      return null;
    }

    try {

      await db.collection("alerts").add({

        sourceDocumentId:
          event.params.weatherId,

        source:
          "OpenWeather",

        district:
          afterData.district || "",

        humidity:
          afterData.humidity ?? null,

        pressure:
          afterData.pressure ?? null,

        rainfall:
          afterData.rainfall ?? null,

        temperature:
          afterData.temperature ?? null,

        wind_speed:
          afterData.wind_speed ?? null,

        time:
          afterData.time ||
          FieldValue.serverTimestamp(),

        archivedAt:
          FieldValue.serverTimestamp(),

        rawData:
          afterData,
      });

      console.log(
        `OpenWeather data archived successfully: ${event.params.weatherId}`
      );

      return null;

    } catch (error) {

      console.error(
        "Error archiving OpenWeather data:",
        error
      );

      return null;
    }
  }
);


// ==========================================================
// PART 2 + 3 + 4
// AUTOMATIC AFFECTED ZONE
// AUTOMATIC BROADCAST
// AUTOMATIC DISASTER FCM
// ==========================================================

exports.createAffectedZone = onDocumentWritten(
  "latest_alerts/{alertId}",

  async (event) => {

    const afterData =
      event.data?.after?.data();

    if (!afterData) {

      console.log(
        "Alert document deleted. Nothing to process."
      );

      return null;
    }

    try {

      // ====================================================
      // 1. READ DISASTER INFORMATION
      // ====================================================

      const disaster =
        String(
          afterData.disaster ||
          afterData.raw_disaster_type ||
          ""
        ).trim();

      const district =
        String(
          afterData.district ||
          afterData.city ||
          ""
        ).trim();

      const risk =
        String(
          afterData.risk ||
          afterData.raw_severity ||
          "Low"
        ).trim();

      const latitude =
        Number(afterData.latitude);

      const longitude =
        Number(afterData.longitude);

      console.log(
        "===================================="
      );

      console.log(
        "LATEST ALERT RECEIVED"
      );

      console.log(
        `Disaster: ${disaster}`
      );

      console.log(
        `District: ${district}`
      );

      console.log(
        `Risk: ${risk}`
      );

      console.log(
        `Latitude: ${latitude}`
      );

      console.log(
        `Longitude: ${longitude}`
      );

      console.log(
        "===================================="
      );


      // ====================================================
      // 2. NORMAL VALUES
      // ====================================================

      const normalValues = [

        "",

        "normal",

        "none",

        "no disaster",

        "no_disaster",

        "no disaster detected",

        "no disaster detected.",
      ];

      const isNormal =
        normalValues.includes(
          disaster.toLowerCase()
        );


      // ====================================================
      // 3. NORMAL = DELETE AFFECTED ZONES
      // ====================================================

      if (isNormal) {

        console.log(
          `NORMAL / NO DISASTER detected for ${district}`
        );

        if (!district) {

          console.log(
            "District is empty."
          );

          return null;
        }


        const zonesSnapshot =
          await db
            .collection("affected_zones")
            .where(
              "city",
              "==",
              district
            )
            .get();


        if (!zonesSnapshot.empty) {

          const batch =
            db.batch();

          for (
            const zoneDoc
            of zonesSnapshot.docs
          ) {

            batch.delete(
              zoneDoc.ref
            );

            console.log(
              `Deleting affected zone: ${zoneDoc.id}`
            );
          }

          await batch.commit();

          console.log(
            `Successfully deleted ${zonesSnapshot.size} affected zone(s) for ${district}.`
          );

        } else {

          console.log(
            `No affected zones found for ${district}.`
          );
        }


        // --------------------------------------------------
        // MARK DISASTER STATES INACTIVE
        // --------------------------------------------------

        const stateSnapshot =
          await db
            .collection("disaster_states")
            .where(
              "city",
              "==",
              district
            )
            .where(
              "status",
              "==",
              "Active"
            )
            .get();


        if (!stateSnapshot.empty) {

          const batch =
            db.batch();

          for (
            const stateDoc
            of stateSnapshot.docs
          ) {

            batch.update(
              stateDoc.ref,
              {

                status:
                  "Inactive",

                endedAt:
                  FieldValue.serverTimestamp(),
              }
            );
          }

          await batch.commit();

          console.log(
            `Marked ${stateSnapshot.size} disaster state(s) as Inactive.`
          );
        }


        console.log(
          "NORMAL PROCESSING COMPLETED"
        );

        console.log(
          "Affected zones removed."
        );

        console.log(
          "No broadcast alert created."
        );

        console.log(
          "No FCM notification sent."
        );

        return null;
      }


      // ====================================================
      // 4. VALIDATE DISTRICT
      // ====================================================

      if (!district) {

        console.log(
          "District/city is missing."
        );

        return null;
      }


      // ====================================================
      // 5. VALIDATE LOCATION
      // ====================================================

      if (
        !Number.isFinite(latitude) ||
        !Number.isFinite(longitude)
      ) {

        console.log(
          "Invalid latitude or longitude."
        );

        return null;
      }


      // ====================================================
      // 6. RADIUS
      // ====================================================

      const riskLower =
        risk.toLowerCase();

      let radiusMeters;

      if (riskLower === "low") {

        radiusMeters = 5000;

      } else if (riskLower === "medium") {

        radiusMeters = 10000;

      } else if (riskLower === "high") {

        radiusMeters = 20000;

      } else if (riskLower === "extreme") {

        radiusMeters = 40000;

      } else {

        radiusMeters = 5000;
      }


      console.log(
        `Affected radius: ${radiusMeters} meters`
      );


      // ====================================================
      // 7. DISASTER STATE ID
      // ====================================================

      const stateId =
        `${district}_${disaster}`
          .toLowerCase()
          .replace(
            /[^a-z0-9]+/g,
            "_"
          )
          .replace(
            /^_+|_+$/g,
            ""
          );

      const stateRef =
        db
          .collection("disaster_states")
          .doc(stateId);


      // ====================================================
      // 8. CHECK DISASTER STATE
      // ====================================================

      const stateDoc =
        await stateRef.get();

      let isNewDisaster =
        false;


      if (
        stateDoc.exists &&
        stateDoc.data()?.status === "Active"
      ) {

        isNewDisaster =
          false;

        await stateRef.update({

          lastSeenAt:
            FieldValue.serverTimestamp(),

          lastRisk:
            risk,

          lastLatitude:
            latitude,

          lastLongitude:
            longitude,
        });

        console.log(
          "Existing active disaster detected."
        );

      } else {

        isNewDisaster =
          true;

        await stateRef.set({

          city:
            district,

          disaster:
            disaster,

          status:
            "Active",

          startedAt:
            FieldValue.serverTimestamp(),

          lastSeenAt:
            FieldValue.serverTimestamp(),

          lastRisk:
            risk,

          lastLatitude:
            latitude,

          lastLongitude:
            longitude,

          alertId:
            event.params.alertId,
        });

        console.log(
          "NEW disaster event detected."
        );
      }


      // ====================================================
      // 9. FIND EXISTING ZONE
      // ====================================================

      const existingSnapshot =
        await db
          .collection("affected_zones")
          .where(
            "city",
            "==",
            district
          )
          .where(
            "disasterType",
            "==",
            disaster
          )
          .where(
            "status",
            "==",
            "Active"
          )
          .limit(1)
          .get();


      // ====================================================
      // 10. UPDATE EXISTING ZONE
      // ====================================================

      if (!existingSnapshot.empty) {

        const existingDoc =
          existingSnapshot.docs[0];

        await existingDoc.ref.update({

          city:
            district,

          description:
            `${disaster} reported in ${district}`,

          disasterType:
            disaster,

          latitude:
            latitude,

          longitude:
            longitude,

          riskLevel:
            risk,

          status:
            "Active",
        });

        console.log(
          `Affected zone already exists: ${existingDoc.id}`
        );

      } else {

        // ==================================================
        // 11. CREATE NEW ZONE
        // ==================================================

        const newZone = {

          assignedTeam:
            "Unassigned",

          city:
            district,

          createdAt:
            FieldValue.serverTimestamp(),

          description:
            `${disaster} reported in ${district}`,

          disasterType:
            disaster,

          latitude:
            latitude,

          longitude:
            longitude,

          population:
            0,

          riskLevel:
            risk,

          status:
            "Active",

          zoneName:
            `${district} Zone`,
        };


        const newZoneRef =
          await db
            .collection("affected_zones")
            .add(
              newZone
            );


        console.log(
          `Affected zone CREATED: ${newZoneRef.id}`
        );
      }


      // ====================================================
      // 12. EXISTING DISASTER
      // NO DUPLICATE ALERT
      // ====================================================

      if (!isNewDisaster) {

        console.log(
          "Disaster is still active."
        );

        console.log(
          "No duplicate broadcast alert."
        );

        console.log(
          "No duplicate FCM notification."
        );

        return null;
      }


      // ====================================================
      // 13. BROADCAST ALERT
      // ====================================================

      const title =
        `🚨 ${risk} ${disaster} Alert`;

      const body =
        `${risk} ${disaster} has been detected in ${district}. ` +
        `Please move to a safe location and follow emergency instructions.`;


      const broadcastAlertRef =
        await db
          .collection("broadcast_alerts")
          .add({

            title:
              title,

            message:
              body,

            disaster:
              disaster,

            riskLevel:
              risk,

            city:
              district,

            latitude:
              latitude,

            longitude:
              longitude,

            createdAt:
              FieldValue.serverTimestamp(),

            sourceAlertId:
              event.params.alertId,

            status:
              "Active",
          });


      console.log(
        `Broadcast alert created: ${broadcastAlertRef.id}`
      );


      // ====================================================
      // 14. GET CITIZENS
      //
      // IMPORTANT:
      // Actual collection = citizens
      // ====================================================

      const citizensSnapshot =
        await db
          .collection("citizens")
          .get();


      let sent =
        0;

      let skipped =
        0;

      let failed =
        0;


      // ====================================================
      // 15. DISTANCE FUNCTION
      // ====================================================

      function distanceInMeters(
        lat1,
        lon1,
        lat2,
        lon2
      ) {

        const earthRadius =
          6371000;

        const lat1Rad =
          (lat1 * Math.PI) /
          180;

        const lat2Rad =
          (lat2 * Math.PI) /
          180;

        const deltaLat =
          ((lat2 - lat1) *
            Math.PI) /
          180;

        const deltaLon =
          ((lon2 - lon1) *
            Math.PI) /
          180;

        const a =
          Math.sin(
            deltaLat / 2
          ) *
            Math.sin(
              deltaLat / 2
            ) +

          Math.cos(
            lat1Rad
          ) *
            Math.cos(
              lat2Rad
            ) *

          Math.sin(
            deltaLon / 2
          ) *
            Math.sin(
              deltaLon / 2
            );

        const c =
          2 *
          Math.atan2(
            Math.sqrt(a),
            Math.sqrt(1 - a)
          );

        return (
          earthRadius *
          c
        );
      }


      // ====================================================
      // 16. SEND DISASTER FCM
      // ====================================================

      for (
        const citizenDoc
        of citizensSnapshot.docs
      ) {

        const citizen =
          citizenDoc.data();


        if (
          citizen.latitude === undefined ||
          citizen.longitude === undefined ||
          !citizen.fcmToken
        ) {

          skipped++;

          continue;
        }


        const citizenLatitude =
          Number(
            citizen.latitude
          );

        const citizenLongitude =
          Number(
            citizen.longitude
          );


        if (
          !Number.isFinite(
            citizenLatitude
          ) ||
          !Number.isFinite(
            citizenLongitude
          )
        ) {

          skipped++;

          continue;
        }


        const distance =
          distanceInMeters(
            latitude,
            longitude,
            citizenLatitude,
            citizenLongitude
          );


        console.log(
          `Citizen ${citizenDoc.id}: ${Math.round(distance)} meters away`
        );


        if (
          distance <= radiusMeters
        ) {

          try {

            await messaging.send({

              notification: {

                title:
                  title,

                body:
                  body,
              },

              data: {

                disaster:
                  disaster,

                riskLevel:
                  risk,

                city:
                  district,

                alertId:
                  event.params.alertId,

                type:
                  "disaster_alert",
              },

              token:
                citizen.fcmToken,
            });


            sent++;

            console.log(
              `FCM sent to citizen: ${citizenDoc.id}`
            );

          } catch (error) {

            failed++;

            console.error(
              `FCM failed for citizen ${citizenDoc.id}:`,
              error.message
            );
          }

        } else {

          skipped++;
        }
      }


      console.log(
        "===================================="
      );

      console.log(
        "AUTOMATIC DISASTER PROCESS COMPLETED"
      );

      console.log(
        `Disaster: ${disaster}`
      );

      console.log(
        `District: ${district}`
      );

      console.log(
        `Risk: ${risk}`
      );

      console.log(
        `Radius: ${radiusMeters} meters`
      );

      console.log(
        `Notifications sent: ${sent}`
      );

      console.log(
        `Citizens skipped: ${skipped}`
      );

      console.log(
        `Notifications failed: ${failed}`
      );

      console.log(
        "===================================="
      );


      return null;

    } catch (error) {

      console.error(
        "Automatic disaster alert error:",
        error
      );

      return null;
    }
  }
);


// ==========================================================
// PART 5
// ADMIN TWO-FACTOR AUTHENTICATION
// ==========================================================

exports.sendAdminOtp = onCall(
  {
    secrets: [
      "OTP_EMAIL",
      "OTP_EMAIL_PASSWORD",
    ],
  },

  async (request) => {

    if (!request.auth) {

      throw new HttpsError(
        "unauthenticated",
        "You must be logged in."
      );
    }


    const uid =
      request.auth.uid;


    try {

      const adminRef =
        db
          .collection("admins")
          .doc(uid);

      const adminDoc =
        await adminRef.get();


      if (!adminDoc.exists) {

        throw new HttpsError(
          "permission-denied",
          "Admin account not found."
        );
      }


      const adminData =
        adminDoc.data();


      if (
        adminData.active !== true
      ) {

        throw new HttpsError(
          "permission-denied",
          "Admin account is disabled."
        );
      }


      if (
        adminData.twoFactorEnabled !== true
      ) {

        throw new HttpsError(
          "failed-precondition",
          "Two-Factor Authentication is not enabled."
        );
      }


      const adminUser =
        await getAuth().getUser(uid);

      const email =
        adminUser.email;


      if (!email) {

        throw new HttpsError(
          "failed-precondition",
          "No email is associated with this admin account."
        );
      }


      const otp =
        crypto
          .randomInt(
            100000,
            1000000
          )
          .toString();


      await db
        .collection("admin_2fa")
        .doc(uid)
        .set({

          otp:
            otp,

          email:
            email,

          createdAt:
            FieldValue.serverTimestamp(),

          expiresAt:
            new Date(
              Date.now() +
              5 * 60 * 1000
            ),
        });


      const transporter =
        nodemailer.createTransport({

          service:
            "gmail",

          auth: {

            user:
              process.env.OTP_EMAIL,

            pass:
              process.env.OTP_EMAIL_PASSWORD,
          },
        });


      await transporter.sendMail({

        from:
          process.env.OTP_EMAIL,

        to:
          email,

        subject:
          "Smart Disaster Management System - Admin OTP",

        text:
          `Your Smart Disaster Management System admin verification code is: ${otp}\n\n` +
          `This code will expire in 5 minutes.\n\n` +
          `If you did not try to log in, please ignore this email.`,
      });


      console.log(
        `Admin OTP sent successfully to ${email}`
      );


      return {

        success:
          true,

        message:
          "OTP sent successfully.",
      };


    } catch (error) {

      console.error(
        "Error sending admin OTP:",
        error
      );


      if (
        error instanceof HttpsError
      ) {

        throw error;
      }


      throw new HttpsError(
        "internal",
        "Could not send OTP email."
      );
    }
  }
);


// ==========================================================
// PART 6
// EXISTING USER NOTIFICATION SYSTEM
//
// Collection:
// Notifications
//
// User data:
// citizens/{userId}
//
// This remains compatible with your existing citizen app.
// ==========================================================

exports.sendUserNotification = onDocumentCreated(
  "Notifications/{notificationId}",

  async (event) => {

    const afterData =
      event.data?.data();


    if (!afterData) {

      console.log(
        "Notification data missing."
      );

      return null;
    }


    try {

      const userId =
        String(
          afterData.userId ||
          ""
        ).trim();


      const title =
        String(
          afterData.title ||
          "Notification"
        ).trim();


      const message =
        String(
          afterData.message ||
          ""
        ).trim();


      if (!userId) {

        console.log(
          "Notification userId is missing."
        );

        return null;
      }


      console.log(
        "===================================="
      );

      console.log(
        "USER NOTIFICATION RECEIVED"
      );

      console.log(
        `Notification ID: ${event.params.notificationId}`
      );

      console.log(
        `Citizen ID: ${userId}`
      );

      console.log(
        `Title: ${title}`
      );

      console.log(
        `Message: ${message}`
      );

      console.log(
        "===================================="
      );


      // ====================================================
      // GET CITIZEN
      // ====================================================

      const citizenRef =
        db
          .collection("citizens")
          .doc(userId);


      const citizenDoc =
        await citizenRef.get();


      if (!citizenDoc.exists) {

        console.log(
          `Citizen not found: ${userId}`
        );

        return null;
      }


      const citizen =
        citizenDoc.data();


      // ====================================================
      // GET FCM TOKEN
      // ====================================================

      const fcmToken =
        citizen.fcmToken;


      if (!fcmToken) {

        console.log(
          `No FCM token found for citizen: ${userId}`
        );

        return null;
      }


      // ====================================================
      // SEND FCM
      // ====================================================

      await messaging.send({

        notification: {

          title:
            title,

          body:
            message,
        },

        data: {

          notificationId:
            event.params.notificationId,

          type:
            "user_notification",
        },

        token:
          fcmToken,
      });


      console.log(
        "===================================="
      );

      console.log(
        "USER NOTIFICATION SENT"
      );

      console.log(
        `Citizen ID: ${userId}`
      );

      console.log(
        `Title: ${title}`
      );

      console.log(
        "===================================="
      );


      return null;


    } catch (error) {

      console.error(
        "User notification error:",
        error
      );

      return null;
    }
  }
);



// ==========================================================
// HELPER: RESOLVE CITIZEN ID FOR A TASK
//
// Tasks created via the dashboard's "Assign" flow copy
// citizenId from the report, but some reports only ever
// stored the citizen's UID under `reportedBy` (the field the
// original manual_reports-based notification code relied on),
// not under `citizenId`. If a task's own citizenId is empty,
// fall back to reading it off the linked manual_reports doc.
// ==========================================================

async function resolveCitizenId(after) {

  const directId =
    String(
      after.citizenId ||
      ""
    ).trim();

  if (directId) {
    return directId;
  }

  const reportId =
    String(
      after.reportId ||
      ""
    ).trim();

  if (!reportId) {
    return "";
  }

  try {

    const reportDoc =
      await db
        .collection("manual_reports")
        .doc(reportId)
        .get();

    if (!reportDoc.exists) {
      return "";
    }

    const reportData =
      reportDoc.data() ||
      {};

    const fallbackId =
      String(
        reportData.citizenId ||
        reportData.reportedBy ||
        reportData.userId ||
        ""
      ).trim();

    return fallbackId;

  } catch (error) {

    console.error(
      `Failed to resolve citizenId from manual_reports/${reportId}:`,
      error
    );

    return "";
  }
}


// ==========================================================
// PART 7
// RESCUE TEAM ASSIGNMENT NOTIFICATIONS
//
// Admin (web dashboard) assigns a rescue team to a task
//        ↓
// tasks/{taskId} written with a non-empty teamId
//        ↓
// Rescue leader gets an FCM push
//
// IMPORTANT:
// The dashboard's real central collection for an active
// rescue operation is `tasks` (NOT `manual_reports`).
// `manual_reports` only holds the original citizen report;
// team/leader assignment and live status (dispatched,
// accepted, enroute, in_progress, resolved) live on the
// `tasks` document, written either by the admin dashboard
// (assignment) or by the rescue team mobile app (status
// updates). We listen here instead of on manual_reports so
// this fires no matter which of those two flows created or
// assigned the task.
// ==========================================================

exports.onRescueTeamAssigned = onDocumentWritten(
  "tasks/{taskId}",

  async (event) => {

    const before =
      event.data?.before?.exists
        ? event.data.before.data()
        : null;

    const after =
      event.data?.after?.data();

    if (!after) {
      console.log(
        "Task deleted. Nothing to process."
      );

      return null;
    }

    const beforeTeamId =
      String(
        before?.teamId ||
        ""
      ).trim();

    const afterTeamId =
      String(
        after.teamId ||
        ""
      ).trim();

    // ------------------------------------------------------
    // Only fire when a team is newly attached to this task
    // (task just created with a team, or an existing
    // "Unassigned" task just got a team via the dashboard's
    // Assign Task button).
    // ------------------------------------------------------

    if (!afterTeamId || afterTeamId === beforeTeamId) {
      return null;
    }

    const leaderId =
      String(
        after.leaderId ||
        ""
      ).trim();

    const citizenId =
      String(
        after.citizenId ||
        ""
      ).trim();

    const teamName =
      String(
        after.teamName ||
        "Rescue Team"
      ).trim();

    const emergencyType =
      String(
        after.emergencyType ||
        "emergency"
      ).trim();

    const taskId =
      event.params.taskId;

    console.log(
      "===================================="
    );

    console.log(
      "RESCUE TEAM ASSIGNED"
    );

    console.log(
      `Task: ${taskId}`
    );

    console.log(
      `Team: ${teamName}`
    );

    console.log(
      `Leader ID: ${leaderId}`
    );

    console.log(
      `Citizen ID: ${citizenId}`
    );

    console.log(
      "===================================="
    );

    // ======================================================
    // RESCUE LEADER
    //
    // Leader accounts live in the `users` collection
    // (see add_edit_team_dialog.dart: leaderId is looked up
    // by phone number in `users`), NOT `citizens`.
    // ======================================================

    if (leaderId) {

      await sendAndSaveNotification({

        userId:
          leaderId,

        collection:
          "users",

        taskId:
          taskId,

        recipientType:
          "rescue_leader",

        title:
          "🚑 New Rescue Task Assigned",

        message:
          `A new ${emergencyType} report has been assigned to ${teamName}. Please check your rescue dashboard.`,
      });

    } else {

      console.log(
        "leaderId is empty on this task."
      );
    }

    return null;
  }
);


// ==========================================================
// PART 8
// RESCUE STATUS CHANGE NOTIFICATIONS (to citizen)
//
// Fires whenever tasks/{taskId}.status changes.
//
// Matches the status flow already used across the dashboard
// (RescueTasksScreen._buildTimeline):
//   dispatched -> accepted -> assigned -> enroute
//     -> in_progress -> resolved
//
// - "accepted"    -> rescue leader accepted the task ->
//                    tell the citizen help is on the way.
// - "enroute"     -> team is travelling to the location.
// - "in_progress" -> team is actively working the rescue.
// - "resolved"    -> rescue is complete.
// ==========================================================

exports.onRescueStatusChanged = onDocumentUpdated(
  "tasks/{taskId}",

  async (event) => {

    const before =
      event.data?.before?.data();

    const after =
      event.data?.after?.data();

    if (!before || !after) {
      return null;
    }

    const oldStatus =
      String(
        before.status ||
        ""
      ).trim().toLowerCase();

    const newStatus =
      String(
        after.status ||
        ""
      ).trim().toLowerCase();

    if (oldStatus === newStatus) {
      return null;
    }

    const citizenId =
      await resolveCitizenId(after);

    const taskId =
      event.params.taskId;

    let title =
      "";

    let message =
      "";

    if (newStatus === "accepted") {

      title =
        "🚑 Rescue Team Assigned";

      message =
        "Your report has been assigned. A rescue team is on the way.";

    } else if (newStatus === "enroute") {

      title =
        "🚑 Rescue Team En Route";

      message =
        "The rescue team is now en route to your location.";

    } else if (newStatus === "in_progress") {

      title =
        "📍 Rescue In Progress";

      message =
        "The rescue team has arrived and is responding to your emergency.";

    } else if (newStatus === "resolved") {

      title =
        "✅ Emergency Resolved";

      message =
        "Your emergency report has been resolved by the rescue team.";

    } else {

      return null;
    }

    console.log(
      "===================================="
    );

    console.log(
      "RESCUE STATUS CHANGED"
    );

    console.log(
      `Task: ${taskId}`
    );

    console.log(
      `Old status: ${oldStatus}`
    );

    console.log(
      `New status: ${newStatus}`
    );

    console.log(
      `Citizen: ${citizenId}`
    );

    console.log(
      "===================================="
    );

    // ------------------------------------------------------
    // MIRROR STATUS ONTO manual_reports
    //
    // This is the piece that was missing: task status moves
    // forward (accepted -> enroute -> in_progress -> resolved)
    // but nothing was reflecting that back onto the original
    // manual_reports/{reportId} doc, so the report screen's
    // status stayed stuck on "assigned" until someone changed
    // it manually.
    // ------------------------------------------------------

    const reportId =
      String(
        after.reportId ||
        ""
      ).trim();

    if (reportId) {

      const reportStatusMap = {

        accepted:
          "Assigned",

        enroute:
          "En Route",

        in_progress:
          "In Progress",

        resolved:
          "Resolved",
      };

      const reportStatus =
        reportStatusMap[newStatus];

      if (reportStatus) {

        try {

          await db
            .collection("manual_reports")
            .doc(reportId)
            .update({

              status:
                reportStatus,

              statusUpdatedAt:
                FieldValue.serverTimestamp(),
            });

          console.log(
            `manual_reports/${reportId}.status -> ${reportStatus}`
          );

        } catch (error) {

          console.error(
            `Failed to mirror status onto manual_reports/${reportId}:`,
            error
          );
        }

      }

    } else {

      console.log(
        "reportId is empty on this task - skipping manual_reports mirror."
      );
    }

    if (!citizenId) {

      console.log(
        "citizenId is empty on this task."
      );

      return null;
    }

    await sendAndSaveNotification({

      userId:
        citizenId,

      collection:
        "citizens",

      taskId:
        taskId,

      recipientType:
        "citizen",

      title:
        title,

      message:
        message,
    });

    return null;
  }
);


// ==========================================================
// PART 9
// RESCUE NOTIFICATION HELPER
//
// IMPORTANT:
// Notification history is saved in the EXISTING
// "Notifications" collection.
//
// `collection` selects where the recipient's fcmToken is
// looked up: "citizens" for citizens, "users" for rescue
// leaders / admins.
// ==========================================================

async function sendAndSaveNotification({
  userId,
  collection,
  taskId,
  recipientType,
  title,
  message,
}) {

  try {

    // ======================================================
    // GET RECIPIENT
    // ======================================================

    const userRef =
      db
        .collection(collection)
        .doc(userId);

    const userDoc =
      await userRef.get();

    // ======================================================
    // SAVE NOTIFICATION IN EXISTING COLLECTION
    // ======================================================

    const notificationRef =
      await db
        .collection("Notifications")
        .add({

          userId:
            userId,

          taskId:
            taskId,

          recipientType:
            recipientType,

          title:
            title,

          message:
            message,

          type:
            "rescue",

          read:
            false,

          createdAt:
            FieldValue.serverTimestamp(),
        });

    console.log(
      `Notification history saved: ${notificationRef.id}`
    );

    // ======================================================
    // RECIPIENT NOT FOUND
    // ======================================================

    if (!userDoc.exists) {

      console.log(
        `Recipient not found in ${collection}: ${userId}`
      );

      return;
    }

    const recipient =
      userDoc.data();

    // ======================================================
    // GET FCM TOKEN
    // ======================================================

    const fcmToken =
      recipient.fcmToken;

    if (!fcmToken) {

      console.log(
        `No FCM token for ${collection}/${userId}. Notification history saved.`
      );

      return;
    }

    // ======================================================
    // SEND PUSH
    // ======================================================

    await messaging.send({

      notification: {

        title:
          title,

        body:
          message,
      },

      data: {

        notificationId:
          notificationRef.id,

        taskId:
          taskId,

        type:
          "rescue_notification",
      },

      token:
        fcmToken,
    });

    console.log(
      `Rescue FCM sent successfully to ${collection}/${userId}`
    );

  } catch (error) {

    console.error(
      `Rescue notification error for ${collection}/${userId}:`,
      error
    );
  }
}
