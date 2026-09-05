const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const {
  getFirestore,
  FieldValue,
} = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

const db = getFirestore();
const messaging = getMessaging();

/*
==========================================================
PART 1
Archive OpenWeather data into alerts collection
==========================================================
*/

exports.archiveOpenWeatherData = onDocumentWritten(
  "openweathermap/{weatherId}",
  async (event) => {
    const afterData = event.data?.after?.data();

    if (!afterData) {
      console.log("Weather document deleted. Nothing to archive.");
      return null;
    }

    try {
      await db.collection("alerts").add({
        sourceDocumentId: event.params.weatherId,
        source: "OpenWeather",

        district: afterData.district || "",

        humidity: afterData.humidity ?? null,
        pressure: afterData.pressure ?? null,
        rainfall: afterData.rainfall ?? null,
        temperature: afterData.temperature ?? null,
        wind_speed: afterData.wind_speed ?? null,

        time: afterData.time || FieldValue.serverTimestamp(),

        archivedAt: FieldValue.serverTimestamp(),

        rawData: afterData,
      });

      console.log(
        `OpenWeather data archived successfully: ${event.params.weatherId}`
      );

      return null;
    } catch (error) {
      console.error("Error archiving OpenWeather data:", error);
      return null;
    }
  }
);


/*
==========================================================
PART 2 + PART 3 + PART 4
Automatic affected zone + automatic FCM alert

IMPORTANT:
A new notification is sent ONLY when a disaster becomes
ACTIVE for a city.

If the same disaster continues:
- No duplicate broadcast alert
- No duplicate FCM notification

If the disaster becomes NORMAL:
- Existing active zone becomes INACTIVE

If another disaster happens later:
- A new alert can be generated
==========================================================
*/

exports.createAffectedZone = onDocumentWritten(
  "latest_alerts/{alertId}",
  async (event) => {
    const afterData = event.data?.after?.data();

    if (!afterData) {
      console.log("Alert document deleted. Nothing to process.");
      return null;
    }

    try {
      /*
      ----------------------------------------------------
      1. Read latest alert
      ----------------------------------------------------
      */

      const disaster = String(
        afterData.disaster ||
        afterData.raw_disaster_type ||
        ""
      ).trim();

      const district = String(
        afterData.district ||
        afterData.city ||
        ""
      ).trim();

      const risk = String(
        afterData.risk ||
        afterData.raw_severity ||
        "Low"
      ).trim();

      const latitude = Number(afterData.latitude);
      const longitude = Number(afterData.longitude);

      /*
      ----------------------------------------------------
      2. Check whether this is a normal/no-disaster result
      ----------------------------------------------------
      */

      const normalValues = [
        "",
        "normal",
        "none",
        "no disaster",
        "no_disaster",
        "no disaster detected",
      ];

      const isNormal =
        normalValues.includes(disaster.toLowerCase());

      /*
      ----------------------------------------------------
      3. NORMAL / NO DISASTER
      ----------------------------------------------------

      If there is no disaster, close active zones for
      this city.

      This allows a future disaster to generate a NEW alert.
      ----------------------------------------------------
      */

      if (isNormal) {
        console.log(
          `No disaster detected for ${district}.`
        );

        if (district) {
          const activeZonesSnapshot = await db
            .collection("affected_zones")
            .where("city", "==", district)
            .where("status", "==", "Active")
            .get();

          if (!activeZonesSnapshot.empty) {
            const batch = db.batch();

            for (const zoneDoc of activeZonesSnapshot.docs) {
              batch.update(zoneDoc.ref, {
                status: "Inactive",
              });
            }

            await batch.commit();

            console.log(
              `Closed ${activeZonesSnapshot.size} active zone(s) for ${district}.`
            );
          }

          /*
          --------------------------------------------------
          Mark all active disaster states for this city
          as inactive.
          --------------------------------------------------
          */

          const stateSnapshot = await db
            .collection("disaster_states")
            .where("city", "==", district)
            .where("status", "==", "Active")
            .get();

          if (!stateSnapshot.empty) {
            const batch = db.batch();

            for (const stateDoc of stateSnapshot.docs) {
              batch.update(stateDoc.ref, {
                status: "Inactive",
                endedAt: FieldValue.serverTimestamp(),
              });
            }

            await batch.commit();

            console.log(
              `Closed ${stateSnapshot.size} active disaster state(s).`
            );
          }
        }

        console.log(
          "Normal result processed. No notification sent."
        );

        return null;
      }

      /*
      ----------------------------------------------------
      4. Validate disaster information
      ----------------------------------------------------
      */

      if (!district) {
        console.log(
          "District/city is missing. Disaster alert ignored."
        );

        return null;
      }

      if (
        !Number.isFinite(latitude) ||
        !Number.isFinite(longitude)
      ) {
        console.log(
          "Invalid latitude or longitude. Alert ignored."
        );

        return null;
      }

      /*
      ----------------------------------------------------
      5. Calculate affected radius
      ----------------------------------------------------
      */

      const riskLower = risk.toLowerCase();

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

      console.log(`Disaster: ${disaster}`);
      console.log(`District: ${district}`);
      console.log(`Risk: ${risk}`);
      console.log(`Radius: ${radiusMeters} meters`);
      console.log(`Latitude: ${latitude}`);
      console.log(`Longitude: ${longitude}`);


      /*
      ====================================================
      DUPLICATE PROTECTION
      ====================================================

      One state document represents:

      City + Disaster Type

      Example:

      mandi_bahauddin_flood

      If the state is already ACTIVE:
      - Do not create another broadcast alert
      - Do not send another FCM

      This also protects against two Cloud Function
      executions happening at almost the same time.
      ====================================================
      */

      const stateId =
        `${district}_${disaster}`
          .toLowerCase()
          .replace(/[^a-z0-9]+/g, "_")
          .replace(/^_+|_+$/g, "");

      const stateRef = db
        .collection("disaster_states")
        .doc(stateId);

      let isNewDisaster = false;

      /*
      ----------------------------------------------------
      Atomically check/create disaster state
      ----------------------------------------------------
      */

      await db.runTransaction(async (transaction) => {
        const stateDoc = await transaction.get(stateRef);

        if (
          stateDoc.exists &&
          stateDoc.data()?.status === "Active"
        ) {
          /*
          Same disaster is already active.
          Therefore no new notification.
          */

          isNewDisaster = false;

          transaction.update(stateRef, {
            lastSeenAt: FieldValue.serverTimestamp(),
            lastRisk: risk,
            lastLatitude: latitude,
            lastLongitude: longitude,
          });

          return;
        }

        /*
        --------------------------------------------------
        This is a NEW disaster event.
        --------------------------------------------------
        */

        isNewDisaster = true;

        transaction.set(
          stateRef,
          {
            city: district,
            disaster: disaster,
            status: "Active",
            startedAt: FieldValue.serverTimestamp(),
            lastSeenAt: FieldValue.serverTimestamp(),
            lastRisk: risk,
            lastLatitude: latitude,
            lastLongitude: longitude,
            alertId: event.params.alertId,
          },
          {
            merge: true,
          }
        );
      });


      /*
      ====================================================
      PART 2
      Create/update affected zone
      ====================================================
      */

      const affectedZonesRef =
        db.collection("affected_zones");

      const zoneName = `${district} Zone`;

      const description =
        `${disaster} reported in ${district}`;


      /*
      ----------------------------------------------------
      Check existing active zone
      ----------------------------------------------------
      */

      const existingSnapshot = await affectedZonesRef
        .where("city", "==", district)
        .where("disasterType", "==", disaster)
        .where("status", "==", "Active")
        .limit(1)
        .get();


      if (!existingSnapshot.empty) {
        /*
        --------------------------------------------------
        Existing zone found.
        Update its information.

        IMPORTANT:
        We do NOT create another zone.
        --------------------------------------------------
        */

        const existingDoc =
          existingSnapshot.docs[0];

        await existingDoc.ref.update({
          city: district,
          description: description,
          disasterType: disaster,
          latitude: latitude,
          longitude: longitude,
          riskLevel: risk,
          status: "Active",
        });

        console.log(
          `Affected zone already exists: ${existingDoc.id}`
        );
      } else {
        /*
        --------------------------------------------------
        Create new affected zone.

        ONLY these 11 fields are stored.
        --------------------------------------------------
        */

        const newZone = {
          assignedTeam: "Unassigned",
          city: district,
          createdAt: FieldValue.serverTimestamp(),
          description: description,
          disasterType: disaster,
          latitude: latitude,
          longitude: longitude,
          population: 0,
          riskLevel: risk,
          status: "Active",
          zoneName: zoneName,
        };

        const newZoneRef =
          await affectedZonesRef.add(newZone);

        console.log(
          `Affected zone created: ${newZoneRef.id}`
        );
      }


      /*
      ====================================================
      IMPORTANT DUPLICATE CHECK
      ====================================================

      If this disaster was already active, STOP here.

      We already updated the affected zone above, but
      we DO NOT create another broadcast alert and
      DO NOT send another FCM.
      ====================================================
      */

      if (!isNewDisaster) {
        console.log(
          "Existing active disaster detected."
        );

        console.log(
          "No duplicate broadcast alert created."
        );

        console.log(
          "No duplicate FCM notification sent."
        );

        return null;
      }


      /*
      ====================================================
      PART 3
      Automatically create ONE broadcast alert
      ====================================================
      */

      const title =
        `🚨 ${risk} ${disaster} Alert`;

      let body;

      if (district) {
        body =
          `${risk} ${disaster} has been detected in ${district}. ` +
          `Please move to a safe location and follow emergency instructions.`;
      } else {
        body =
          `${risk} ${disaster} has been detected. ` +
          `Please move to a safe location and follow emergency instructions.`;
      }


      /*
      ----------------------------------------------------
      Save generated alert
      ----------------------------------------------------
      */

      const broadcastAlertRef =
        await db.collection("broadcast_alerts").add({
          title: title,
          message: body,
          disaster: disaster,
          riskLevel: risk,
          city: district,
          latitude: latitude,
          longitude: longitude,
          createdAt: FieldValue.serverTimestamp(),
          sourceAlertId: event.params.alertId,
          status: "Active",
        });

      console.log(
        `NEW broadcast alert created: ${broadcastAlertRef.id}`
      );


      /*
      ====================================================
      PART 4
      Find affected citizens and send FCM
      ====================================================
      */

      const citizensSnapshot =
        await db.collection("citizens").get();

      let sent = 0;
      let skipped = 0;
      let failed = 0;


      /*
      ----------------------------------------------------
      Distance calculation
      Haversine formula
      ----------------------------------------------------
      */

      function distanceInMeters(
        lat1,
        lon1,
        lat2,
        lon2
      ) {
        const earthRadius = 6371000;

        const lat1Rad =
          (lat1 * Math.PI) / 180;

        const lat2Rad =
          (lat2 * Math.PI) / 180;

        const deltaLat =
          ((lat2 - lat1) * Math.PI) / 180;

        const deltaLon =
          ((lon2 - lon1) * Math.PI) / 180;

        const a =
          Math.sin(deltaLat / 2) *
            Math.sin(deltaLat / 2) +
          Math.cos(lat1Rad) *
            Math.cos(lat2Rad) *
            Math.sin(deltaLon / 2) *
            Math.sin(deltaLon / 2);

        const c =
          2 *
          Math.atan2(
            Math.sqrt(a),
            Math.sqrt(1 - a)
          );

        return earthRadius * c;
      }


      /*
      ----------------------------------------------------
      Loop through citizens
      ----------------------------------------------------
      */

      for (const citizenDoc of citizensSnapshot.docs) {
        const citizen = citizenDoc.data();


        /*
        --------------------------------------------------
        Missing information
        --------------------------------------------------
        */

        if (
          citizen.latitude === undefined ||
          citizen.longitude === undefined ||
          !citizen.fcmToken
        ) {
          skipped++;
          continue;
        }


        const citizenLatitude =
          Number(citizen.latitude);

        const citizenLongitude =
          Number(citizen.longitude);


        if (
          !Number.isFinite(citizenLatitude) ||
          !Number.isFinite(citizenLongitude)
        ) {
          skipped++;
          continue;
        }


        /*
        --------------------------------------------------
        Calculate distance
        --------------------------------------------------
        */

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


        /*
        --------------------------------------------------
        Send ONLY if inside affected radius
        --------------------------------------------------
        */

        if (distance <= radiusMeters) {
          try {
            const message = {
              notification: {
                title: title,
                body: body,
              },

              data: {
                disaster: disaster,
                riskLevel: risk,
                city: district,
                alertId: event.params.alertId,
                type: "disaster_alert",
              },

              token: citizen.fcmToken,
            };


            await messaging.send(message);

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


      /*
      ====================================================
      FINAL RESULT
      ====================================================
      */

      console.log("====================================");
      console.log("NEW AUTOMATIC DISASTER ALERT COMPLETED");
      console.log(`Disaster: ${disaster}`);
      console.log(`Risk: ${risk}`);
      console.log(`Affected area: ${district}`);
      console.log(`Radius: ${radiusMeters} meters`);
      console.log(
        `Notifications sent: ${sent}`
      );
      console.log(
        `Citizens skipped: ${skipped}`
      );
      console.log(
        `Notifications failed: ${failed}`
      );
      console.log("====================================");


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