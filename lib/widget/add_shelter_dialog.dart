import 'package:flutter/material.dart';

import '../model/shelter_model.dart';
import '../services/shelter_service.dart';

class AddShelterDialog extends StatefulWidget {
  final ShelterModel? shelter;

  const AddShelterDialog({
    super.key,
    this.shelter,
  });

  @override
  State<AddShelterDialog> createState() =>
      _AddShelterDialogState();
}

class _AddShelterDialogState extends State<AddShelterDialog> {
  final ShelterService _shelterService = ShelterService();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController capacityController = TextEditingController();
  final TextEditingController occupiedController =
  TextEditingController(text: "0");

  final TextEditingController latitudeController =
  TextEditingController();

  final TextEditingController longitudeController =
  TextEditingController();

  bool loading = false;

  @override
  void initState() {
    super.initState();

    if (widget.shelter != null) {
      nameController.text = widget.shelter!.name;

      cityController.text = widget.shelter!.city;

      capacityController.text =
          widget.shelter!.capacity.toString();

      occupiedController.text =
          widget.shelter!.occupied.toString();

      latitudeController.text =
          widget.shelter!.latitude.toString();

      longitudeController.text =
          widget.shelter!.longitude.toString();
    }
  }
  @override
  void dispose() {
    nameController.dispose();
    cityController.dispose();
    capacityController.dispose();
    occupiedController.dispose();
    latitudeController.dispose();
    longitudeController.dispose();
    super.dispose();
  }

  Future<void> saveShelter() async {
    if (nameController.text.trim().isEmpty ||
        cityController.text.trim().isEmpty ||
        capacityController.text.trim().isEmpty ||
        latitudeController.text.trim().isEmpty ||
        longitudeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill all fields."),
        ),
      );
      return;
    }

    setState(() {
      loading = true;
    });

    final capacity =
        int.tryParse(capacityController.text.trim()) ?? 0;

    final occupied =
        int.tryParse(occupiedController.text.trim()) ?? 0;

    final shelter = ShelterModel(
      id: widget.shelter?.id ?? "",

      name: nameController.text.trim(),

      city: cityController.text.trim(),

      capacity:
      int.tryParse(capacityController.text.trim()) ?? 0,

      occupied:
      int.tryParse(occupiedController.text.trim()) ?? 0,

      status:
      (int.tryParse(occupiedController.text.trim()) ?? 0) >=
          (int.tryParse(capacityController.text.trim()) ?? 0)
          ? "Full"
          : "Open",

      createdAt:
      widget.shelter?.createdAt ??
          DateTime.now(),

      latitude:
      double.tryParse(latitudeController.text.trim()) ?? 0,

      longitude:
      double.tryParse(longitudeController.text.trim()) ?? 0,
    );

    if (widget.shelter == null) {

      await _shelterService.addShelter(shelter);

    } else {

      await _shelterService.updateShelter(shelter);

    }
    if (!mounted) return;

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          content: Text(
            widget.shelter == null
                ? "Shelter Added Successfully"
                : "Shelter Updated Successfully",
          ),
        )
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.shelter == null
            ? "Add Shelter"
            : "Edit Shelter",
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: "Shelter Name",
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: cityController,
                decoration: const InputDecoration(
                  labelText: "City",
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: capacityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Capacity",
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: occupiedController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Occupied",
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: latitudeController,
                keyboardType:
                const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: "Latitude",
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: longitudeController,
                keyboardType:
                const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: "Longitude",
                ),
              ),
            ],
          ),
        ),
      ),

      actions: [

        TextButton(
          onPressed: loading
              ? null
              : () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),

        ElevatedButton(
          onPressed: loading ? null : saveShelter,
          child: loading
              ? const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
              : Text(
            widget.shelter == null
                ? "Save"
                : "Update",
          ),        ),
      ],
    );
  }
}