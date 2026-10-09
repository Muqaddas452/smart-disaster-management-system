import 'package:flutter/material.dart';

import '../model/affected_zone_model.dart';
import '../services/affected_zone_service.dart';

class AffectedZoneFormDialog extends StatefulWidget {
  final AffectedZone? zone;

  const AffectedZoneFormDialog({
    super.key,
    this.zone,
  });

  @override
  State<AffectedZoneFormDialog> createState() =>
      _AffectedZoneFormDialogState();
}

class _AffectedZoneFormDialogState
    extends State<AffectedZoneFormDialog> {

  double getRadius(String riskLevel) {
    switch (riskLevel.trim().toLowerCase()) {
      case "low":
        return 5000; // 5 km

      case "medium":
        return 10000; // 10 km

      case "high":
        return 20000; // 20 km

      case "extreme":
        return 40000; // 40 km

      default:
        return 5000;
    }
  }

  final _formKey = GlobalKey<FormState>();

  final _service = AffectedZoneService();

  late TextEditingController zoneController;
  late TextEditingController cityController;
  late TextEditingController disasterController;
  late TextEditingController riskController;
  late TextEditingController populationController;
  late TextEditingController statusController;
  late TextEditingController latitudeController;
  late TextEditingController longitudeController;

  bool loading = false;

  @override
  void initState() {
    super.initState();

    final zone = widget.zone;

    zoneController =
        TextEditingController(text: zone?.zoneName ?? "");

    cityController =
        TextEditingController(text: zone?.city ?? "");

    disasterController =
        TextEditingController(text: zone?.disasterType ?? "");

    riskController =
        TextEditingController(text: zone?.riskLevel ?? "");

    populationController =
        TextEditingController(
            text: zone?.population.toString() ?? "");

    statusController =
        TextEditingController(text: zone?.status ?? "");

    latitudeController =
        TextEditingController(
            text: zone?.latitude.toString() ?? "");

    longitudeController =
        TextEditingController(
            text: zone?.longitude.toString() ?? "");
  }

  @override
  void dispose() {
    zoneController.dispose();
    cityController.dispose();
    disasterController.dispose();
    riskController.dispose();
    populationController.dispose();
    statusController.dispose();
    latitudeController.dispose();
    longitudeController.dispose();
    super.dispose();
  }

  Future<void> saveZone() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      loading = true;
    });

    final zone = AffectedZone(
      id: widget.zone?.id ?? "",

      zoneName: zoneController.text.trim(),

      city: cityController.text.trim(),

      disasterType: disasterController.text.trim(),

      riskLevel: riskController.text.trim(),

      population:
      int.tryParse(populationController.text) ?? 0,

      status: statusController.text.trim(),

      latitude:
      double.tryParse(latitudeController.text) ?? 0,

      longitude:
      double.tryParse(longitudeController.text) ?? 0,

      radius: getRadius(riskController.text.trim()),

      coordinates:
      "${latitudeController.text}, ${longitudeController.text}",

      predictionTime: widget.zone?.predictionTime ?? "",
    );

    try {
      if (widget.zone == null) {
        await _service.addAffectedZone(zone);
      } else {
        await _service.updateAffectedZone(zone);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }

    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  Widget field(
      String label,
      TextEditingController controller, {
        TextInputType keyboard =
            TextInputType.text,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return "Required";
          }
          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          border:
          const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.zone == null
            ? "Add Affected Zone"
            : "Edit Affected Zone",
      ),
      content: SizedBox(
        width: 450,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [

                field(
                    "Zone Name",
                    zoneController),

                field(
                    "City",
                    cityController),

                field(
                    "Disaster Type",
                    disasterController),

                field(
                    "Risk Level",
                    riskController),

                field(
                  "Population",
                  populationController,
                  keyboard:
                  TextInputType.number,
                ),

                field(
                    "Status",
                    statusController),

                field(
                  "Latitude",
                  latitudeController,
                  keyboard: const TextInputType
                      .numberWithOptions(
                    decimal: true,
                  ),
                ),

                field(
                  "Longitude",
                  longitudeController,
                  keyboard: const TextInputType
                      .numberWithOptions(
                    decimal: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [

        TextButton(
          onPressed: () =>
              Navigator.pop(context),
          child: const Text("Cancel"),
        ),

        ElevatedButton(
          onPressed:
          loading ? null : saveZone,
          child: loading
              ? const SizedBox(
            height: 18,
            width: 18,
            child:
            CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
              : Text(
            widget.zone == null
                ? "Add"
                : "Update",
          ),
        ),
      ],
    );
  }
}