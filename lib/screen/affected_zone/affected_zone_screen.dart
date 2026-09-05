import 'package:flutter/material.dart';

import '../../model/affected_zone_model.dart';
import '../../services/affected_zone_service.dart';
import '../../widget/affected_zone_statistics.dart';
import '../../widget/affected_zone_table.dart';
import '../../widget/affected_zone_form_dialog.dart';

class AffectedZoneScreen extends StatefulWidget {
  const AffectedZoneScreen({
    super.key,
  });

  @override
  State<AffectedZoneScreen> createState() =>
      _AffectedZoneScreenState();
}

class _AffectedZoneScreenState
    extends State<AffectedZoneScreen> {

  final AffectedZoneService _service =
  AffectedZoneService();

  String search = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,

      body: StreamBuilder<List<AffectedZone>>(
        stream: _service.getAffectedZones(),

        builder: (context, snapshot) {

          // ==========================
          // LOADING
          // ==========================
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // ==========================
          // ERROR
          // ==========================
          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error loading affected zones:\n"
                    "${snapshot.error}",
              ),
            );
          }

          // ==========================
          // DATA
          // ==========================
          final affectedZones =
              snapshot.data ?? [];

          // ==========================
          // SEARCH
          // ==========================
          final searchText =
          search.toLowerCase().trim();

          final filteredZones =
          affectedZones.where((zone) {

            return zone.zoneName
                .toLowerCase()
                .contains(searchText) ||
                zone.city
                    .toLowerCase()
                    .contains(searchText) ||
                zone.disasterType
                    .toLowerCase()
                    .contains(searchText);
          }).toList();

          return Padding(
            padding: const EdgeInsets.all(20),

            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [

                // ==========================
                // HEADER
                // ==========================
                Row(
                  mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,

                  children: [

                    const Text(
                      "Affected Zones",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    ElevatedButton.icon(
                      icon: const Icon(
                        Icons.add,
                      ),

                      label: const Text(
                        "Add Zone",
                      ),

                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) =>
                          const AffectedZoneFormDialog(),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ==========================
                // STATISTICS
                // ==========================
                AffectedZoneStatistics(
                  affectedZones: affectedZones,
                ),

                const SizedBox(height: 25),

                // ==========================
                // SEARCH
                // ==========================
                TextField(
                  decoration: InputDecoration(
                    hintText:
                    "Search by Zone, City or Disaster",

                    prefixIcon: const Icon(
                      Icons.search,
                    ),

                    border: OutlineInputBorder(
                      borderRadius:
                      BorderRadius.circular(12),
                    ),

                    filled: true,
                    fillColor: Colors.white,
                  ),

                  onChanged: (value) {
                    setState(() {
                      search = value;
                    });
                  },
                ),

                const SizedBox(height: 25),

                // ==========================
                // TABLE
                // ==========================
                Expanded(
                  child: Card(
                    elevation: 3,

                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(12),
                    ),

                    child: Padding(
                      padding:
                      const EdgeInsets.all(16),

                      child: AffectedZoneTable(
                        affectedZones:
                        filteredZones,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}