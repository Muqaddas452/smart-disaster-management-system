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
      2. Validate location
      ----------------------------------------------------
      */

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
      3. Ignore normal alerts
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

      if (normalValues.includes(disaster.toLowerCase())) {
        console.log(
          `Normal alert detected for ${district}. No notification sent.`
        );

        return null;
      }

      /*
      ----------------------------------------------------
      4. Calculate affected radius
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
      PART 2
      Create/update affected zone
      ====================================================
      */

      const affectedZonesRef = db.collection("affected_zones");

      const zoneName = district
        ? `${district} Zone`
        : "Affected Zone";

      const description = district
        ? `${disaster} reported in ${district}`
        : `${disaster} reported`;

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
        const existingDoc = existingSnapshot.docs[0];

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

        const newZoneRef = await affectedZonesRef.add(newZone);

        console.log(
          `Affected zone created: ${newZoneRef.id}`
        );
      }


      /*
      ====================================================
      PART 3
      Automatically create broadcast alert
      ====================================================
      */

      const title = `🚨 ${risk} ${disaster} Alert`;

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
        `Broadcast alert created: ${broadcastAlertRef.id}`
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

        const lat1Rad = (lat1 * Math.PI) / 180;
        const lat2Rad = (lat2 * Math.PI) / 180;

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
        Missing information
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

        const distance = distanceInMeters(
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
        Send only if inside affected radius
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
      ----------------------------------------------------
      Final result
      ----------------------------------------------------
      */

      console.log("====================================");
      console.log("AUTOMATIC ALERT COMPLETED");
      console.log(`Disaster: ${disaster}`);
      console.log(`Risk: ${risk}`);
      console.log(`Affected area: ${district}`);
      console.log(`Radius: ${radiusMeters} meters`);
      console.log(`Notifications sent: ${sent}`);
      console.log(`Citizens skipped: ${skipped}`);
      console.log(`Notifications failed: ${failed}`);
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

