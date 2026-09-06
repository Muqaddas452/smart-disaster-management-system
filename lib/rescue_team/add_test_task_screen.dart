import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// DEBUG / TESTING ONLY.
// Lets you create a dummy `tasks` document directly from the app so the
// TasksListScreen -> ViewTaskScreen -> AssignMembersScreen flow can be
// tested end-to-end before the admin (React) dashboard actually writes
// real tasks. Remove this screen (or hide it behind a debug flag) before
// final submission if you don't want it reachable in the shipped app.
class AddTestTaskScreen extends StatefulWidget {
  const AddTestTaskScreen({super.key});

  @override
  State<AddTestTaskScreen> createState() => _AddTestTaskScreenState();
}

class _AddTestTaskScreenState extends State<AddTestTaskScreen> {
  static const Color kGreen = Color(0xFF1B5E38);

  final _typeController = TextEditingController(text: 'Flood');
  final _descController = TextEditingController(text: 'Water entered in village');
  final _latController = TextEditingController(text: '31.5204');
  final _lngController = TextEditingController(text: '74.3587');
  final _addressController = TextEditingController(text: 'Sector 7, Riverside Embankment, Lahore');
  final _teamIdController = TextEditingController();

  String _priority = 'high';
  bool _isSaving = false;

  @override
  void dispose() {
    _typeController.dispose();
    _descController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _addressController.dispose();
    _teamIdController.dispose();
    super.dispose();
  }

  Future<void> _createTestTask() async {
    if (_teamIdController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the teamId you want to test with')),
      );
      return;
    }

    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lat/Lng must be valid numbers')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance.collection('tasks').add({
        'type': _typeController.text.trim(),
        'description': _descController.text.trim(),
        'lat': lat,
        'lng': lng,
        'address': _addressController.text.trim(),
        'priority': _priority,
        'reportId': 'test_${DateTime.now().millisecondsSinceEpoch}',
        'teamId': _teamIdController.text.trim(),
        'status': 'dispatched',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test task created — check My Tasks'), backgroundColor: kGreen),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5E8),
      appBar: AppBar(
        backgroundColor: kGreen,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Add Test Task (Debug)',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(10)),
              child: const Text(
                'Yeh screen sirf testing ke liye hai — asal tasks admin dashboard se banenge. Team ID (jo test karni hai) daalein, wo aapke rescueTeamUsers doc ka teamId field hona chahiye.',
                style: TextStyle(fontSize: 12, color: Colors.black87),
              ),
            ),
            const SizedBox(height: 20),
            _label('Team ID (required)'),
            _field(_teamIdController, hint: 'Paste the teamId to test with'),
            const SizedBox(height: 16),
            _label('Emergency type'),
            _field(_typeController),
            const SizedBox(height: 16),
            _label('Description'),
            _field(_descController, maxLines: 3),
            const SizedBox(height: 16),
            _label('Priority'),
            Row(
              children: ['high', 'medium', 'low'].map((p) {
                final selected = _priority == p;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(p),
                    selected: selected,
                    selectedColor: kGreen.withOpacity(0.15),
                    onSelected: (_) => setState(() => _priority = p),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _label('Latitude'),
                _field(_latController, keyboardType: TextInputType.number),
              ])),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _label('Longitude'),
                _field(_lngController, keyboardType: TextInputType.number),
              ])),
            ]),
            const SizedBox(height: 16),
            _label('Address (typed manually here for testing)'),
            _field(_addressController, maxLines: 2),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _createTestTask,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Text('Create test task',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
  );

  Widget _field(
      TextEditingController c, {
        String? hint,
        int maxLines = 1,
        TextInputType keyboardType = TextInputType.text,
      }) {
    return TextField(
      controller: c,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}