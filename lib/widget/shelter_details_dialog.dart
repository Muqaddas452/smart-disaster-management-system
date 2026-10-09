import 'package:flutter/material.dart';
import '../widget/map/google_map_widget.dart';
import '../../model/shelter_model.dart';
import '../../services/shelter_service.dart';
import '../../widget/add_shelter_dialog.dart';

class ShelterDetailsDialog extends StatelessWidget {
  final ShelterModel shelter;

  ShelterDetailsDialog({
    super.key,
    required this.shelter,
  });

  final ShelterService _service = ShelterService();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(shelter.name),

      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            _item("City", shelter.city),

            _item(
              "Capacity",
              shelter.capacity.toString(),
            ),

            _item(
              "Occupied",
              shelter.occupied.toString(),
            ),

            _item(
              "Available",
              shelter.available.toString(),
            ),

            _item(
              "Status",
              shelter.status,
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

        OutlinedButton.icon(
          icon: const Icon(Icons.map),
          label: const Text("View on Map"),
          onPressed: () {
            Navigator.pop(context);

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  appBar: AppBar(
                    title: Text(shelter.name),
                  ),
                  body: GoogleMapWidget(
                    focusLatitude: shelter.latitude,
                    focusLongitude: shelter.longitude,
                    focusTitle: shelter.name,
                  ),
                ),
              ),
            );
          },
        ),

        ElevatedButton.icon(
          icon: const Icon(Icons.edit),
          label: const Text("Edit"),
          onPressed: () {
            Navigator.pop(context);

            showDialog(
              context: context,
              builder: (_) => AddShelterDialog(
                shelter: shelter,
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
                title: const Text("Delete Shelter"),
                content: const Text(
                  "Are you sure you want to delete this shelter?",
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

            await _service.deleteShelter(shelter.id);

            if (context.mounted) {
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: Colors.green,
                  content: Text(
                    "Shelter deleted successfully.",
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