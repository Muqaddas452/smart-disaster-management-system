import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../model/alert_model.dart';
import '../../services/alert_service.dart';

class BroadcastAlertDialog extends StatefulWidget {
  final AlertModel? alert;

  const BroadcastAlertDialog({
    super.key,
    this.alert,
  });

  @override
  State<BroadcastAlertDialog> createState() =>
      _BroadcastAlertDialogState();
}

class _BroadcastAlertDialogState
    extends State<BroadcastAlertDialog> {
  final _formKey = GlobalKey<FormState>();

  final AlertService _service = AlertService();

  final TextEditingController _messageController =
  TextEditingController();

  final TextEditingController _areaController =
  TextEditingController(text: "Lahore");

  String? disasterType = "Flood";
  String? priority = "High";

  bool loading = false;

  @override
  void initState() {
    super.initState();

    if (widget.alert != null) {
      disasterType = widget.alert!.disaster;
      priority = widget.alert!.priority;

      _areaController.text = widget.alert!.area;

      _messageController.text = widget.alert!.message;
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _areaController.dispose();

    super.dispose();
  }

  Future<void> _sendAlert() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      loading = true;
    });

    final alert = AlertModel(
      id: widget.alert?.id ?? "",

      disaster: disasterType!,

      priority: priority!,

      area: _areaController.text.trim(),

      status: "Sent",

      message: _messageController.text.trim(),

      date: widget.alert?.date ?? DateTime.now(),

      createdBy: widget.alert?.createdBy ?? "Admin",

      affectedUsers:
      widget.alert?.affectedUsers ?? 0,

      readCount:
      widget.alert?.readCount ?? 0,
    );

    try {

      if (widget.alert == null) {

        // Save Alert
        await _service.addAlert(alert);

        // Call Flask Backend
        bool success =
        await _service.sendAlertToAffectedUsers();

        if (!success) {
          throw Exception(
              "Unable to send notifications.");
        }

      } else {

        await _service.updateAlert(alert);

      }

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          content: Text(
            widget.alert == null
                ? "Alert sent successfully to affected users."
                : "Alert updated successfully.",
          ),
        ),
      );

    } catch (e) {

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(e.toString()),
        ),
      );

    } finally {

      if (mounted) {
        setState(() {
          loading = false;
        });
      }

    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              Row(
                children: [

                  const Icon(
                    Icons.campaign,
                    color: Colors.red,
                    size: 30,
                  ),

                  const SizedBox(width: 12),

                  Text(
                    widget.alert == null
                        ? "Broadcast Alert"
                        : "Edit Alert",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 25),

              DropdownButtonFormField<String>(
                value: disasterType,
                decoration: const InputDecoration(
                  labelText: "Disaster Type",
                  border: OutlineInputBorder(),
                ),
                items: const [

                  DropdownMenuItem(
                    value: "Flood",
                    child: Text("Flood"),
                  ),

                  DropdownMenuItem(
                    value: "Heavy Rain",
                    child: Text("Heavy Rain"),
                  ),

                  DropdownMenuItem(
                    value: "Heatwave",
                    child: Text("Heatwave"),
                  ),

                  DropdownMenuItem(
                    value: "Storm",
                    child: Text("Storm"),
                  ),

                  DropdownMenuItem(
                    value: "Earthquake",
                    child: Text("Earthquake"),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    disasterType = value;
                  });
                },
              ),

              const SizedBox(height: 18),

              DropdownButtonFormField<String>(
                value: priority,
                decoration: const InputDecoration(
                  labelText: "Priority",
                  border: OutlineInputBorder(),
                ),
                items: const [

                  DropdownMenuItem(
                    value: "Low",
                    child: Text("Low"),
                  ),

                  DropdownMenuItem(
                    value: "Medium",
                    child: Text("Medium"),
                  ),

                  DropdownMenuItem(
                    value: "High",
                    child: Text("High"),
                  ),

                  DropdownMenuItem(
                    value: "Critical",
                    child: Text("Critical"),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    priority = value;
                  });
                },
              ),

              const SizedBox(height: 18),

              TextFormField(
                controller: _areaController,
                decoration: const InputDecoration(
                  labelText: "Target Area",
                  hintText: "e.g. M.B.Din",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Please enter target area";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 18),

              TextFormField(
                controller: _messageController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: "Alert Message",
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Please enter alert message";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 25),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [

                  OutlinedButton(
                    onPressed: loading
                        ? null
                        : () {
                      Navigator.pop(context);
                    },
                    child: const Text("Cancel"),
                  ),

                  const SizedBox(width: 15),

                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 15,
                      ),
                    ),
                    onPressed: loading ? null : _sendAlert,

                    icon: loading
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : Icon(
                      widget.alert == null
                          ? Icons.send
                          : Icons.save,
                    ),

                    label: Text(
                      loading
                          ? "Sending..."
                          : widget.alert == null
                          ? "Send Alert"
                          : "Update Alert",
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}