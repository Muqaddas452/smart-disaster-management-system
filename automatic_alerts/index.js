const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");

initializeApp();

const db = getFirestore();

/*
==========================================================
PART 1
Archive OpenWeather data into the alerts collection
==========================================================
*/

exports.archiveOpenWeatherData = onDocumentWritten(
  "openweathermap/{weatherId}",
  async (event) => {
    const afterData = event.data?.after?.data();

    // If document was deleted
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
PART 2
Create affected zone automatically from latest_alerts
==========================================================
*/

exports.createAffectedZone = onDocumentWritten(
  "latest_alerts/{alertId}",
  async (event) => {
    const afterData = event.data?.after?.data();

    // If latest alert was deleted
    if (!afterData) {
      console.log("Alert document deleted. Nothing to create.");
      return null;
    }

    try {
      // --------------------------------------------------
      // Get alert data
      // --------------------------------------------------

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

      // --------------------------------------------------
      // Validate coordinates
      // --------------------------------------------------

      if (
        !Number.isFinite(latitude) ||
        !Number.isFinite(longitude)
      ) {
        console.log(
          "Invalid latitude or longitude. Affected zone was not created."
        );

        return null;
      }

      // --------------------------------------------------
      // Ignore normal / no-disaster alerts
      // --------------------------------------------------

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
          `Normal alert detected. No affected zone created for ${district}.`
        );

        return null;
      }

      // --------------------------------------------------
      // Correct collection
      // --------------------------------------------------

      const affectedZonesRef = db.collection("affected_zones");

      // --------------------------------------------------
      // Data that will be stored
      //
      // ONLY these 11 fields:
      //
      // assignedTeam
      // city
      // createdAt
      // description
      // disasterType
      // latitude
      // longitude
      // population
      // riskLevel
      // status
      // zoneName
      // --------------------------------------------------

      const zoneName = district
        ? `${district} Zone`
        : "Affected Zone";

      const description = district
        ? `${disaster} reported in ${district}`
        : `${disaster} reported`;

      // --------------------------------------------------
      // Check if an active zone already exists
      // for the same city and disaster
      // --------------------------------------------------

      const existingSnapshot = await affectedZonesRef
        .where("city", "==", district)
        .where("disasterType", "==", disaster)
        .where("status", "==", "Active")
        .limit(1)
        .get();

      // --------------------------------------------------
      // If zone already exists, update it
      // --------------------------------------------------

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
          `Affected zone already exists. Updated zone: ${existingDoc.id}`
        );

        return null;
      }

      // --------------------------------------------------
      // Create NEW affected zone
      // --------------------------------------------------

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
        `Affected zone created successfully: ${newZoneRef.id}`
      );

      console.log(`City: ${district}`);
      console.log(`Disaster: ${disaster}`);
      console.log(`Risk: ${risk}`);
      console.log(`Latitude: ${latitude}`);
      console.log(`Longitude: ${longitude}`);

      return null;
    } catch (error) {
      console.error("Error creating affected zone:", error);
      return null;
    }
  }
);