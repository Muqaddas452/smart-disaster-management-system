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
// PART 7
// RESCUE REPORT ASSIGNMENT NOTIFICATIONS
//
// Admin assigns team
//        ↓
// manual_reports updated
//        ↓
// Rescue leader notification
//        ↓
// Citizen notification
// ==========================================================

exports.onRescueReportAssigned = onDocumentUpdated(
  "manual_reports/{reportId}",

  async (event) => {

    const before =
      event.data?.before?.data();

    const after =
      event.data?.after?.data();


    if (!before || !after) {
      return null;
    }


    const oldTeamId =
      String(
        before.assignedTeamId ||
        ""
      ).trim();


    const newTeamId =
      String(
        after.assignedTeamId ||
        ""
      ).trim();


    const status =
      String(
        after.status ||
        ""
      ).trim();


    // ------------------------------------------------------
    // Only process NEW team assignment
    // ------------------------------------------------------

    if (
      !newTeamId ||
      oldTeamId === newTeamId ||
      status !== "Assigned"
    ) {

      return null;
    }


    const leaderId =
      String(
        after.assignedLeaderId ||
        ""
      ).trim();


    const citizenId =
      String(
        after.reportedBy ||
        ""
      ).trim();


    const teamName =
      String(
        after.assignedTeamName ||
        "Rescue Team"
      ).trim();


    const reportId =
      event.params.reportId;


    console.log(
      "===================================="
    );

    console.log(
      "RESCUE TEAM ASSIGNED"
    );

    console.log(
      `Report: ${reportId}`
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
    // ======================================================

    if (leaderId) {

      await sendAndSaveNotification({

        userId:
          leaderId,

        reportId:
          reportId,

        recipientType:
          "rescue_leader",

        title:
          "🚑 New Rescue Task Assigned",

        message:
          `A new emergency report has been assigned to ${teamName}. Please check your rescue dashboard.`,
      });

    } else {

      console.log(
        "assignedLeaderId is empty."
      );
    }


    // ======================================================
    // CITIZEN
    // ======================================================

    if (citizenId) {

      await sendAndSaveNotification({

        userId:
          citizenId,

        reportId:
          reportId,

        recipientType:
          "citizen",

        title:
          "🚑 Rescue Team Assigned",

        message:
          `${teamName} has been assigned to your emergency report. Help is on the way.`,
      });

    } else {

      console.log(
        "reportedBy is empty."
      );
    }


    return null;
  }
);


// ==========================================================
// PART 8
// RESCUE STATUS CHANGE
//
// In Progress
// Arrived
// Resolved
// ==========================================================

exports.onRescueStatusChanged = onDocumentUpdated(
  "manual_reports/{reportId}",

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
      ).trim();


    const newStatus =
      String(
        after.status ||
        ""
      ).trim();


    if (
      oldStatus === newStatus
    ) {

      return null;
    }


    const citizenId =
      String(
        after.reportedBy ||
        ""
      ).trim();


    const reportId =
      event.params.reportId;


    let title =
      "";

    let message =
      "";


    if (
      newStatus === "In Progress"
    ) {

      title =
        "🚑 Rescue Team Responding";

      message =
        "The rescue team is now responding to your emergency report.";

    } else if (
      newStatus === "Arrived"
    ) {

      title =
        "📍 Rescue Team Has Arrived";

      message =
        "The rescue team has arrived at the reported emergency location.";

    } else if (
      newStatus === "Resolved"
    ) {

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
      `Report: ${reportId}`
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


    if (!citizenId) {

      console.log(
        "reportedBy is empty."
      );

      return null;
    }


    await sendAndSaveNotification({

      userId:
        citizenId,

      reportId:
        reportId,

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
// Notification history is saved in EXISTING
// "Notifications" collection.
//
// We do NOT create a lowercase notifications collection.
// ==========================================================

async function sendAndSaveNotification({
  userId,
  reportId,
  recipientType,
  title,
  message,
}) {

  try {

    // ======================================================
    // GET CITIZEN / RESCUE USER
    // ======================================================

    const citizenRef =
      db
        .collection("citizens")
        .doc(userId);


    const citizenDoc =
      await citizenRef.get();


    // ======================================================
    // SAVE NOTIFICATION IN EXISTING COLLECTION
    // ======================================================

    const notificationRef =
      await db
        .collection("Notifications")
        .add({

          userId:
            userId,

          reportId:
            reportId,

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
    // CITIZEN NOT FOUND
    // ======================================================

    if (!citizenDoc.exists) {

      console.log(
        `Citizen/rescue user not found: ${userId}`
      );

      return;
    }


    const citizen =
      citizenDoc.data();


    // ======================================================
    // GET FCM TOKEN
    // ======================================================

    const fcmToken =
      citizen.fcmToken;


    if (!fcmToken) {

      console.log(
        `No FCM token for user: ${userId}. Notification history saved.`
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

        reportId:
          reportId,

        type:
          "rescue_notification",
      },

      token:
        fcmToken,
    });


    console.log(
      `Rescue FCM sent successfully to: ${userId}`
    );


  } catch (error) {

    console.error(
      `Rescue notification error for ${userId}:`,
      error
    );
  }
}