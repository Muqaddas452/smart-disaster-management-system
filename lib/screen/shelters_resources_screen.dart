import 'package:flutter/material.dart';

import '../model/resource_model.dart';
import '../model/shelter_model.dart';

import '../services/resource_service.dart';
import '../services/shelter_service.dart';

import '../widget/resource_table.dart';
import '../widget/shelter_stat_cards.dart';
import '../widget/shelter_table.dart';

import '../widget/add_shelter_dialog.dart';
import '../widget/add_resource_dialog.dart';

class SheltersResourcesScreen extends StatefulWidget {
  const SheltersResourcesScreen({super.key});

  @override
  State<SheltersResourcesScreen> createState() =>
      _SheltersResourcesScreenState();
}

class _SheltersResourcesScreenState
    extends State<SheltersResourcesScreen> {
  final ShelterService _shelterService = ShelterService();
  final ResourceService _resourceService = ResourceService();

  String search = "";

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ShelterModel>>(
      stream: _shelterService.getShelters(),
      builder: (context, shelterSnapshot) {
        if (shelterSnapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (!shelterSnapshot.hasData) {
          return const Center(
            child: Text("No Shelters Found"),
          );
        }

        return StreamBuilder<List<ResourceModel>>(
          stream: _resourceService.getResources(),
          builder: (context, resourceSnapshot) {
            if (resourceSnapshot.connectionState ==
                ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (!resourceSnapshot.hasData) {
              return const Center(
                child: Text("No Resources Found"),
              );
            }

            final shelters = shelterSnapshot.data!;
            final resources = resourceSnapshot.data!;

            final filteredShelters =
            shelters.where((shelter) {
              return shelter.name
                  .toLowerCase()
                  .contains(search.toLowerCase()) ||
                  shelter.city
                      .toLowerCase()
                      .contains(search.toLowerCase());
            }).toList();

            final filteredResources =
            resources.where((resource) {
              return resource.name
                  .toLowerCase()
                  .contains(search.toLowerCase()) ||
                  resource.location
                      .toLowerCase()
                      .contains(search.toLowerCase());
            }).toList();

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [

                  ShelterStatCards(
                    shelters: shelters,
                    resources: resources,
                  ),

                  const SizedBox(height: 20),

                  TextField(
                    decoration: InputDecoration(
                      hintText:
                      "Search shelters/resources",
                      prefixIcon:
                      const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius:
                        BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        search = value;
                      });
                    },
                  ),

                  const SizedBox(height: 25),

                  /// Shelters Header
                  Row(
                    mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Shelters",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),

                      ElevatedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) =>
                            const AddShelterDialog(),
                          );
                        },
                        icon: const Icon(Icons.add),
                        label:
                        const Text("Add Shelter"),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  ShelterTable(
                    shelters: filteredShelters,
                  ),

                  const SizedBox(height: 30),

                  /// Resources Header
                  Row(
                    mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Resources",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),

                      ElevatedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) =>
                            const AddResourceDialog(),
                          );
                        },
                        icon: const Icon(Icons.add),
                        label:
                        const Text("Add Resource"),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  ResourceTable(
                    resources: filteredResources,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}