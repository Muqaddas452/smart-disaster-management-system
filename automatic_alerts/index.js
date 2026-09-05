const { onDocumentWritten } = require("firebase-functions/v2/firestore");

const { initializeApp } = require("firebase-admin/app");

const {
  getFirestore,
  FieldValue,
} = require("firebase-admin/firestore");

const { getMessaging } = require("firebase-admin/messaging");


// ==========================================================
// INITIALIZE FIREBASE ADMIN
// ==========================================================

initializeApp();

const db = getFirestore();

const messaging = getMessaging();


// ==========================================================
// PART 1
// Archive OpenWeather data into alerts collection
// ==========================================================

exports.archiveOpenWeatherData = onDocumentWritten(
  "openweathermap/{weatherId}",

  async (event) => {

    const afterData =
      event.data?.after?.data();


    // If weather document was deleted
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
// PART 2 + PART 3 + PART 4
//
// Automatic affected zone
// Automatic broadcast alert
// Automatic FCM notification
//
// IMPORTANT:
//
// Disaster occurs
//      ↓
// affected_zones created
//
// Disaster continues
//      ↓
// Existing zone remains
//
// Disaster becomes Normal
//      ↓
// affected_zones automatically deleted
// ==========================================================

exports.createAffectedZone = onDocumentWritten(
  "latest_alerts/{alertId}",

  async (event) => {

    const afterData =
      event.data?.after?.data();


    // ======================================================
    // ALERT DOCUMENT DELETED
    // ======================================================

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
      // 2. CHECK NORMAL / NO DISASTER
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
      // 3. NORMAL / NO DISASTER
      //
      // DELETE AFFECTED ZONE AUTOMATICALLY
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


        // --------------------------------------------------
        // Find ALL affected zones belonging to this city
        // --------------------------------------------------

        const zonesSnapshot =
          await db
            .collection("affected_zones")
            .where(
              "city",
              "==",
              district
            )
            .get();


        // --------------------------------------------------
        // Delete affected zones
        // --------------------------------------------------

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
        // Mark active disaster states as INACTIVE
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
          "===================================="
        );

        console.log(
          "NORMAL PROCESSING COMPLETED"
        );

        console.log(
          "Affected zone removed."
        );

        console.log(
          "No broadcast alert created."
        );

        console.log(
          "No FCM notification sent."
        );

        console.log(
          "===================================="
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
      // 6. CALCULATE AFFECTED RADIUS
      // ====================================================

      const riskLower =
        risk.toLowerCase();


      let radiusMeters;


      if (riskLower === "low") {

        radiusMeters =
          5000;

      } else if (riskLower === "medium") {

        radiusMeters =
          10000;

      } else if (riskLower === "high") {

        radiusMeters =
          20000;

      } else if (riskLower === "extreme") {

        radiusMeters =
          40000;

      } else {

        radiusMeters =
          5000;
      }


      console.log(
        `Affected radius: ${radiusMeters} meters`
      );


      // ====================================================
      // 7. CREATE UNIQUE DISASTER STATE ID
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

        // --------------------------------------------------
        // Disaster is already active
        // --------------------------------------------------

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

        // --------------------------------------------------
        // NEW disaster
        // --------------------------------------------------

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
      // 9. FIND EXISTING AFFECTED ZONE
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

      }


      // ====================================================
      // 11. CREATE NEW AFFECTED ZONE
      // ====================================================

      else {

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
      //
      // Do NOT send duplicate notification
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
      // 13. CREATE BROADCAST ALERT
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
      // 15. DISTANCE CALCULATION
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
      // 16. SEND FCM
      // ====================================================

      for (
        const citizenDoc
        of citizensSnapshot.docs
      ) {

        const citizen =
          citizenDoc.data();


        // --------------------------------------------------
        // Missing location or FCM token
        // --------------------------------------------------

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


        // --------------------------------------------------
        // Calculate distance
        // --------------------------------------------------

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


        // --------------------------------------------------
        // Citizen is inside affected radius
        // --------------------------------------------------

        if (
          distance <= radiusMeters
        ) {

          try {

            const message = {

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
            };


            await messaging.send(
              message
            );


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


      // ====================================================
      // 17. FINAL LOG
      // ====================================================

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