import 'package:flutter/material.dart';

import '../../model/resource_model.dart';
import '../../services/resource_service.dart';

class AddResourceDialog extends StatefulWidget {
  final ResourceModel? resource;

  const AddResourceDialog({
    super.key,
    this.resource,
  });

  @override
  State<AddResourceDialog> createState() =>
      _AddResourceDialogState();
}

class _AddResourceDialogState
    extends State<AddResourceDialog> {

  final ResourceService _service =
  ResourceService();

  final _nameController =
  TextEditingController();

  final _quantityController =
  TextEditingController();

  final _unitController =
  TextEditingController();

  final _locationController =
  TextEditingController();

  bool loading = false;

  @override
  void initState() {
    super.initState();

    if (widget.resource != null) {

      _nameController.text =
          widget.resource!.name;

      _quantityController.text =
          widget.resource!.quantity
              .toString();

      _unitController.text =
          widget.resource!.unit;

      _locationController.text =
          widget.resource!.location;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> saveResource() async {

    setState(() {
      loading = true;
    });

    final resource = ResourceModel(
      id: widget.resource?.id ?? "",
      name: _nameController.text.trim(),
      quantity: int.tryParse(_quantityController.text) ?? 0,
      unit: _unitController.text.trim(),
      location: _locationController.text.trim(),

      createdAt:
      widget.resource?.createdAt ?? DateTime.now(),
    );

    if (widget.resource == null) {
      await _service.addResource(resource);
    } else {
      await _service.updateResource(resource);
    }

    if (!mounted) return;

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green,
        content: Text(
          widget.resource == null
              ? "Resource Added Successfully"
              : "Resource Updated Successfully",
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return AlertDialog(

      title: Text(
        widget.resource == null
            ? "Add Resource"
            : "Edit Resource",
      ),

      content: SizedBox(
        width: 420,

        child: loading
            ? const Center(
          child:
          CircularProgressIndicator(),
        )
            : Column(
          mainAxisSize:
          MainAxisSize.min,
          children: [

            TextField(
              controller:
              _nameController,
              decoration:
              const InputDecoration(
                labelText:
                "Resource Name",
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller:
              _quantityController,
              keyboardType:
              TextInputType.number,
              decoration:
              const InputDecoration(
                labelText:
                "Quantity",
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller:
              _unitController,
              decoration:
              const InputDecoration(
                labelText: "Unit",
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller:
              _locationController,
              decoration:
              const InputDecoration(
                labelText:
                "Location",
              ),
            ),
          ],
        ),
      ),

      actions: [

        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text("Cancel"),
        ),

        ElevatedButton(
          onPressed:
          loading ? null : saveResource,
          child: Text(
            widget.resource == null
                ? "Save"
                : "Update",
          ),
        ),
      ],
    );
  }
}