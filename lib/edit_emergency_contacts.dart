import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profile_updated_screen.dart';

class EditEmergencyContactsScreen extends StatefulWidget {
  const EditEmergencyContactsScreen({super.key});

  @override
  State<EditEmergencyContactsScreen> createState() => _EditEmergencyContactsScreenState();
}

class _EditEmergencyContactsScreenState extends State<EditEmergencyContactsScreen> {
  final String _uid = FirebaseAuth.instance.currentUser!.uid;

  final TextEditingController _emNameController = TextEditingController();
  final TextEditingController _emPhoneController = TextEditingController();
  String _selectedRelation = 'Father';

  final TextEditingController _emName2Controller = TextEditingController();
  final TextEditingController _emPhone2Controller = TextEditingController();
  String _selectedRelation2 = 'Mother';
  bool _showSecondContact = false;

  bool _isLoadingData = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentData();
  }

  @override
  void dispose() {
    _emNameController.dispose();
    _emPhoneController.dispose();
    _emName2Controller.dispose();
    _emPhone2Controller.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentData() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('citizens').doc(_uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        _emNameController.text = data['emergencyContactName'] ?? '';
        _emPhoneController.text = data['emergencyContactPhone'] ?? '';

        const validRelations = ['Father', 'Mother', 'Brother', 'Sister', 'Friend', 'Spouse'];
        String dbRelation = data['emergencyContactRelation'] ?? 'Father';
        if (validRelations.contains(dbRelation)) _selectedRelation = dbRelation;

        _emName2Controller.text = data['emergencyContactName2'] ?? '';
        _emPhone2Controller.text = data['emergencyContactPhone2'] ?? '';
        if ((data['emergencyContactName2'] ?? '').isNotEmpty) _showSecondContact = true;

        String dbRelation2 = data['emergencyContactRelation2'] ?? 'Mother';
        if (validRelations.contains(dbRelation2)) _selectedRelation2 = dbRelation2;
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load: $e')));
    } finally {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('citizens').doc(_uid).update({
        'emergencyContactName': _emNameController.text.trim(),
        'emergencyContactPhone': _emPhoneController.text.trim(),
        'emergencyContactRelation': _selectedRelation,
        'emergencyContactName2': _emName2Controller.text.trim(),
        'emergencyContactPhone2': _emPhone2Controller.text.trim(),
        'emergencyContactRelation2': _selectedRelation2,
      });

      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ProfileUpdatedScreen()));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const relations = ['Father', 'Mother', 'Brother', 'Sister', 'Friend', 'Spouse'];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E38),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: const Text('Edit Emergency Contacts', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1B5E38)))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 2, blurRadius: 10, offset: const Offset(0, 3))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Contact 1', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B5E38), fontSize: 15)),
                  const SizedBox(height: 10),
                  _buildLabel('Name'),
                  const SizedBox(height: 6),
                  _buildTextField(controller: _emNameController, hintText: 'e.g. Ali Ahmed'),
                  const SizedBox(height: 14),
                  _buildLabel('Phone Number'),
                  const SizedBox(height: 6),
                  _buildTextField(controller: _emPhoneController, hintText: '+92 301 9876543', keyboardType: TextInputType.phone),
                  const SizedBox(height: 14),
                  _buildLabel('Relation'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: relations.contains(_selectedRelation) ? _selectedRelation : 'Father',
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                    ),
                    items: relations.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                    onChanged: (val) => setState(() => _selectedRelation = val!),
                  ),
                  if (_showSecondContact) ...[
                    const Divider(height: 32, thickness: 1),
                    const Text('Contact 2', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B5E38), fontSize: 15)),
                    const SizedBox(height: 10),
                    _buildLabel('Name'),
                    const SizedBox(height: 6),
                    _buildTextField(controller: _emName2Controller, hintText: 'e.g. Fatima Bibi'),
                    const SizedBox(height: 14),
                    _buildLabel('Phone Number'),
                    const SizedBox(height: 6),
                    _buildTextField(controller: _emPhone2Controller, hintText: '+92 302 1234567', keyboardType: TextInputType.phone),
                    const SizedBox(height: 14),
                    _buildLabel('Relation'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: relations.contains(_selectedRelation2) ? _selectedRelation2 : 'Mother',
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                      ),
                      items: relations.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                      onChanged: (val) => setState(() => _selectedRelation2 = val!),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (!_showSecondContact)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF1B5E38)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        minimumSize: const Size(double.infinity, 46),
                      ),
                      onPressed: () => setState(() {
                        _showSecondContact = true;
                      }),
                      icon: const Icon(Icons.add, color: Color(0xFF1B5E38)),
                      label: const Text('Add Another Contact', style: TextStyle(color: Color(0xFF1B5E38), fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveChanges,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B5E38), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('Save Changes', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String label) => Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87));

  Widget _buildTextField({required TextEditingController controller, required String hintText, TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hintText,
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      ),
    );
  }
}