import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../model/rescue_team_model.dart';
import '../../services/rescue_team_service.dart';

class AddEditTeamDialog extends StatefulWidget {
  final RescueTeam? team;

  const AddEditTeamDialog({
    super.key,
    this.team,
  });

  @override
  State<AddEditTeamDialog> createState() =>
      _AddEditTeamDialogState();
}

class _AddEditTeamDialogState
    extends State<AddEditTeamDialog> {

  final _formKey = GlobalKey<FormState>();

  final _teamController = TextEditingController();
  final _leaderController = TextEditingController();
  final _phoneController = TextEditingController();
  final _membersController = TextEditingController();
  final _vehicleController = TextEditingController();

  final RescueTeamService _service =
  RescueTeamService();

  bool loading = false;

  @override
  void initState() {
    super.initState();

    if (widget.team != null) {
      _teamController.text = widget.team!.teamName;
      _leaderController.text = widget.team!.leader;
      _phoneController.text = widget.team!.phone;
      _membersController.text =
          widget.team!.members.toString();
      _vehicleController.text =
          widget.team!.vehicle;
    }
  }
  Future<void> save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      loading = true;
    });

    try {
      String leaderId = widget.team?.leaderId ?? "";

      if (leaderId.isEmpty ||
          widget.team?.phone != _phoneController.text.trim()) {
        final leaderQuery = await FirebaseFirestore.instance
            .collection("users")
            .where(
          "phone",
          isEqualTo: _phoneController.text.trim(),
        )
            .limit(1)
            .get();

        if (leaderQuery.docs.isEmpty) {
          throw Exception(
            "No rescue leader account found with this phone number.",
          );
        }

        leaderId = leaderQuery.docs.first.id;
      }

      final team = RescueTeam(
        id: widget.team?.id ?? "",

        teamName: _teamController.text.trim(),

        leader: _leaderController.text.trim(),

        leaderId: leaderId,

        phone: _phoneController.text.trim(),

        members: int.parse(_membersController.text),

        vehicle: _vehicleController.text.trim(),

        status: widget.team?.status ?? "Pending",

        assignedReportId:
        widget.team?.assignedReportId ?? "",

        assignedArea:
        widget.team?.assignedArea ?? "",

        latitude:
        widget.team?.latitude ?? 0,

        longitude:
        widget.team?.longitude ?? 0,

        createdAt:
        widget.team?.createdAt ?? DateTime.now(),
      );

      if (widget.team == null) {
        await _service.addRescueTeam(team);
      } else {
        await _service.updateRescueTeam(team);
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
          ),
        );
      }
    }
  }

  Widget field(
      String label,
      TextEditingController controller, {
        TextInputType type = TextInputType.text,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        keyboardType: type,
        validator: (value) {

          if (value == null || value.isEmpty) {
            return "Required";
          }

          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return AlertDialog(

      title: Text(
        widget.team == null
            ? "Add Rescue Team"
            : "Edit Rescue Team",
      ),

      content: SizedBox(

        width: 420,

        child: loading
            ? const SizedBox(
          height: 220,
          child: Center(
            child:
            CircularProgressIndicator(),
          ),
        )
            : Form(

          key: _formKey,

          child: SingleChildScrollView(

            child: Column(

              children: [

                field(
                  "Team Name",
                  _teamController,
                ),

                field(
                  "Leader Name",
                  _leaderController,
                ),

                field(
                  "Phone Number",
                  _phoneController,
                  type: TextInputType.phone,
                ),

                field(
                  "Members",
                  _membersController,
                  type: TextInputType.number,
                ),

                field(
                  "Vehicle",
                  _vehicleController,
                ),

              ],
            ),
          ),
        ),
      ),

      actions: [

        OutlinedButton(

          onPressed: () {

            Navigator.pop(context);

          },

          child: const Text("Cancel"),

        ),

        ElevatedButton(

          onPressed: save,

          child: Text(
            widget.team == null
                ? "Add Team"
                : "Update Team",
          ),

        ),

      ],
    );
  }
}