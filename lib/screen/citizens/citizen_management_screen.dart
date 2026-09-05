import 'package:flutter/material.dart';

import '../../model/citizen_model.dart';
import '../../services/citizen_service.dart';

class CitizenManagementScreen extends StatefulWidget {
  const CitizenManagementScreen({super.key});

  @override
  State<CitizenManagementScreen> createState() =>
      _CitizenManagementScreenState();
}

class _CitizenManagementScreenState
    extends State<CitizenManagementScreen> {
  final CitizenService _service = CitizenService();

  String search = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Registered Citizens"),
      ),

      body: StreamBuilder<List<Citizen>>(
        stream: _service.getCitizens(),

        builder: (context, snapshot) {
          // Loading
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // Get citizens
          final citizens = snapshot.data ?? [];

          // Search/filter citizens
          final filteredCitizens = citizens.where((citizen) {
            return citizen.name
                .toLowerCase()
                .contains(search.toLowerCase()) ||
                citizen.email
                    .toLowerCase()
                    .contains(search.toLowerCase());
          }).toList();

          return Column(
            children: [
              // =========================
              // SEARCH BOX
              // =========================
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: "Search citizen...",
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      search = value;
                    });
                  },
                ),
              ),

              // =========================
              // CITIZEN LIST
              // =========================
              Expanded(
                child: Card(
                  margin: const EdgeInsets.all(16),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),

                  // IMPORTANT:
                  // ListView makes the citizen area scrollable.
                  child: Scrollbar(
                    thumbVisibility: true,

                    child: ListView.separated(
                      padding: EdgeInsets.zero,

                      // Number of citizens
                      itemCount: filteredCitizens.length,

                      // Citizen row
                      itemBuilder: (context, index) {
                        final citizen = filteredCitizens[index];

                        return ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.person),
                          ),

                          title: Text(
                            citizen.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          subtitle: Text(
                            citizen.email,
                          ),

                          trailing: IconButton(
                            icon: const Icon(
                              Icons.visibility,
                            ),

                            onPressed: () {
                              _showCitizenDetails(
                                context,
                                citizen,
                              );
                            },
                          ),
                        );
                      },

                      // Divider between citizens
                      separatorBuilder: (context, index) {
                        return const Divider(
                          height: 1,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ==========================================
  // CITIZEN DETAILS DIALOG
  // ==========================================

  void _showCitizenDetails(
      BuildContext context,
      Citizen citizen,
      ) {
    showDialog(
      context: context,

      builder: (context) {
        return AlertDialog(
          title: Text(
            citizen.name,
          ),

          content: Column(
            mainAxisSize: MainAxisSize.min,

            crossAxisAlignment:
            CrossAxisAlignment.start,

            children: [
              Text(
                "Email: ${citizen.email}",
              ),

              const SizedBox(height: 10),

              Text(
                "Phone: ${citizen.phone}",
              ),

              const SizedBox(height: 10),

              Text(
                "ID: ${citizen.id}",
              ),
            ],
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },

              child: const Text(
                "Close",
              ),
            ),
          ],
        );
      },
    );
  }
}