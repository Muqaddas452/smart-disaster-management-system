import 'package:flutter/material.dart';

import '../model/resource_model.dart';
import '../services/resource_service.dart';

import '../widget/resource_details_dialog.dart';
import '../widget/add_resource_dialog.dart';

class ResourceTable extends StatelessWidget {
  final List<ResourceModel> resources;

  ResourceTable({
    super.key,
    required this.resources,
  });

  final ResourceService _service = ResourceService();

  @override
  Widget build(BuildContext context) {
    final bool hasMoreThan10 = resources.length > 10;

    final Widget table = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(
            label: Text("Resource"),
          ),

          DataColumn(
            label: Text("Quantity"),
          ),

          DataColumn(
            label: Text("Unit"),
          ),

          DataColumn(
            label: Text("Location"),
          ),

          DataColumn(
            label: Text("Actions"),
          ),
        ],

        rows: resources.map((resource) {
          return DataRow(
            onSelectChanged: (_) {
              showDialog(
                context: context,
                builder: (_) => ResourceDetailsDialog(
                  resource: resource,
                ),
              );
            },

            cells: [
              DataCell(
                Text(resource.name),
              ),

              DataCell(
                Text(resource.quantity.toString()),
              ),

              DataCell(
                Text(resource.unit),
              ),

              DataCell(
                Text(resource.location),
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
                              ResourceDetailsDialog(
                                resource: resource,
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
                              AddResourceDialog(
                                resource: resource,
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
                              "Delete Resource",
                            ),

                            content: const Text(
                              "Are you sure you want to delete this resource?",
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

                        await _service.deleteResource(
                          resource.id,
                        );

                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(
                            const SnackBar(
                              backgroundColor:
                              Colors.green,
                              content: Text(
                                "Resource deleted successfully.",
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