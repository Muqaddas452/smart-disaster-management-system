import 'package:flutter/material.dart';

import '../model/shelter_model.dart';
import '../model/resource_model.dart';

class ShelterStatCards extends StatelessWidget {
  final List<ShelterModel> shelters;
  final List<ResourceModel> resources;

  const ShelterStatCards({
    super.key,
    required this.shelters,
    required this.resources,
  });

  Widget card(String title, String value, IconData icon) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Icon(icon, size: 32),
              const SizedBox(height: 10),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(title),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalShelters = shelters.length;

    final openShelters =
        shelters.where((e) => e.status == "Open").length;

    final totalBeds =
    shelters.fold(0, (sum, e) => sum + e.capacity);

    final totalResources =
    resources.fold(0, (sum, e) => sum + e.quantity);

    return Row(
      children: [
        card(
          "Shelters",
          totalShelters.toString(),
          Icons.home,
        ),

        const SizedBox(width: 15),

        card(
          "Open",
          openShelters.toString(),
          Icons.check_circle,
        ),

        const SizedBox(width: 15),

        card(
          "Beds",
          totalBeds.toString(),
          Icons.bed,
        ),

        const SizedBox(width: 15),

        card(
          "Resources",
          totalResources.toString(),
          Icons.inventory,
        ),
      ],
    );
  }
}