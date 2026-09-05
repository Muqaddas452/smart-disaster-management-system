import 'package:flutter/material.dart';

import '../model/shelter_model.dart';
import '../services/shelter_service.dart';

import '../widget/shelter_details_dialog.dart';
import '../widget/add_shelter_dialog.dart';

class ShelterTable extends StatelessWidget {
  final List<ShelterModel> shelters;

  ShelterTable({
    super.key,
    required this.shelters,
  });

  final ShelterService _service = ShelterService();

  @override
  Widget build(BuildContext context) {
    final bool hasMoreThan10 = shelters.length > 10;

    final Widget table = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(
            label: Text("Shelter"),
          ),
          DataColumn(
            label: Text("City"),
          ),
          DataColumn(
            label: Text("Capacity"),
          ),
          DataColumn(
            label: Text("Occupied"),
          ),
          DataColumn(
            label: Text("Available"),
          ),
          DataColumn(
            label: Text("Status"),
          ),
          DataColumn(
            label: Text("Actions"),
          ),
        ],

        rows: shelters.map((e) {
          return DataRow(
            onSelectChanged: (_) {
              showDialog(
                context: context,
                builder: (_) => ShelterDetailsDialog(
                  shelter: e,
                ),
              );
            },

            cells: [
              DataCell(
                Text(e.name),
              ),

              DataCell(
                Text(e.city),
              ),

              DataCell(
                Text(e.capacity.toString()),
              ),

              DataCell(
                Text(e.occupied.toString()),
              ),

              DataCell(
                Text(e.available.toString()),
              ),

              DataCell(
                Text(e.status),
              ),

              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // VIEW
                    IconButton(
                      tooltip: "View",
                      icon: const Icon(
                        Icons.visibility,
                        color: Colors.blue,
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) =>
                              ShelterDetailsDialog(
                                shelter: e,
                              ),
                        );
                      },
                    ),

                    // EDIT
                    IconButton(
                      tooltip: "Edit",
                      icon: const Icon(
                        Icons.edit,
                        color: Colors.orange,
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) =>
                              AddShelterDialog(
                                shelter: e,
                              ),
                        );
                      },
                    ),

                    // DELETE
                    IconButton(
                      tooltip: "Delete",
                      icon: const Icon(
                        Icons.delete,
                        color: Colors.red,
                      ),
                      onPressed: () async {
                        final confirm =
                        await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text(
                              "Delete Shelter",
                            ),

                            content: const Text(
                              "Are you sure you want to delete this shelter?",
                            ),

                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(
                                    context,
                                    false,
                                  );
                                },
                                child:
                                const Text("Cancel"),
                              ),

                              ElevatedButton(
                                style:
                                ElevatedButton.styleFrom(
                                  backgroundColor:
                                  Colors.red,
                                ),
                                onPressed: () {
                                  Navigator.pop(
                                    context,
                                    true,
                                  );
                                },
                                child:
                                const Text("Delete"),
                              ),
                            ],
                          ),
                        );

                        if (confirm != true) return;

                        await _service.deleteShelter(
                          e.id,
                        );

                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Shelter deleted successfully.",
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );

    return Card(
      child: hasMoreThan10
          ? SizedBox(
        height: 500,
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: table,
        ),
      )
          : table,
    );
  }
}