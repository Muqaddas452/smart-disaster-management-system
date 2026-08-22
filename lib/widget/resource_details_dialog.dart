import 'package:flutter/material.dart';

import '../../model/resource_model.dart';
import '../../services/resource_service.dart';
import '../../widget/add_resource_dialog.dart';

class ResourceDetailsDialog extends StatelessWidget {
  final ResourceModel resource;

  ResourceDetailsDialog({
    super.key,
    required this.resource,
  });

  final ResourceService _service = ResourceService();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(resource.name),

      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            _item("Resource", resource.name),

            _item(
              "Quantity",
              resource.quantity.toString(),
            ),

            _item(
              "Unit",
              resource.unit,
            ),

            _item(
              "Location",
              resource.location,
            ),
          ],
        ),
      ),

      actions: [

        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text("Close"),
        ),

        ElevatedButton.icon(
          icon: const Icon(Icons.edit),
          label: const Text("Edit"),
          onPressed: () {

            Navigator.pop(context);

            showDialog(
              context: context,
              builder: (_) => AddResourceDialog(
                resource: resource,
              ),
            );
          },
        ),

        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
          ),
          icon: const Icon(Icons.delete),
          label: const Text("Delete"),
          onPressed: () async {

            final confirm = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text("Delete Resource"),
                content: const Text(
                  "Are you sure you want to delete this resource?",
                ),
                actions: [

                  TextButton(
                    onPressed: () {
                      Navigator.pop(context, false);
                    },
                    child: const Text("Cancel"),
                  ),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: () {
                      Navigator.pop(context, true);
                    },
                    child: const Text("Delete"),
                  ),
                ],
              ),
            );

            if (confirm != true) return;

            await _service.deleteResource(resource.id);

            if (context.mounted) {

              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: Colors.green,
                  content: Text(
                    "Resource deleted successfully.",
                  ),
                ),
              );
            }
          },
        ),
      ],
    );
  }

  Widget _item(
      String title,
      String value,
      ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [

          SizedBox(
            width: 120,
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}