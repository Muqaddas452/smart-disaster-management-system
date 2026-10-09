import 'package:flutter/material.dart';

import '../model/shelter_model.dart';
import '../services/shelter_service.dart';

import '../widget/shelter_stat_cards.dart';
import '../widget/shelter_table.dart';
import '../widget/add_shelter_dialog.dart';

class SheltersResourcesScreen extends StatefulWidget {
  const SheltersResourcesScreen({super.key});

  @override
  State<SheltersResourcesScreen> createState() =>
      _SheltersResourcesScreenState();
}

class _SheltersResourcesScreenState
    extends State<SheltersResourcesScreen> {
  final ShelterService _shelterService = ShelterService();

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

        if (shelterSnapshot.hasError) {
          return const Center(
            child: Text("Error loading shelters"),
          );
        }

        if (!shelterSnapshot.hasData) {
          return const Center(
            child: Text("No Shelters Found"),
          );
        }

        final shelters = shelterSnapshot.data!;

        final filteredShelters = shelters.where((shelter) {
          return shelter.name
              .toLowerCase()
              .contains(search.toLowerCase()) ||
              shelter.city
                  .toLowerCase()
                  .contains(search.toLowerCase());
        }).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Existing shelter statistics
              ShelterStatCards(
                shelters: shelters,
              ),

              const SizedBox(height: 20),

              // Search
              TextField(
                decoration: InputDecoration(
                  hintText: "Search shelters",
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    search = value;
                  });
                },
              ),

              const SizedBox(height: 25),

              // Shelters Header
              Row(
                mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Shelters",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
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
                    label: const Text("Add Shelter"),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Shelter Table
              ShelterTable(
                shelters: filteredShelters,
              ),
            ],
          ),
        );
      },
    );
  }
}