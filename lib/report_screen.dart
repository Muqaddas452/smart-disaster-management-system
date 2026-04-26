import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'gps_access_screen.dart';
import 'report_status_screen.dart';
import 'offline_screen.dart';

class ReporteScreen extends StatefulWidget {
   const ReporteScreen({super.key});

  @override
  _ManualEmergencyReportingScreenState createState() =>
      _ManualEmergencyReportingScreenState();
}
class _ManualEmergencyReportingScreenState extends State<ReporteScreen> {

  // ── Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // ── State
  String? _selectedEmergencyType;
  String _severityLevel = 'Low';

  // Auto-detected location (in real app, use geolocator package)
  final String _autoDetectedLocation = '123 Maple Street, Springfield, IL 62704';

  // ── Constants
  static const _primaryGreen = Color(0xFF2E7D32);
  static const _lightGreen = Color(0xFFE8F5E9);
  static const _hintGreen = Color(0xFF66BB6A);
  static const _borderGreen = Color(0xFFA5D6A7);
  static const _bgColor = Color(0xFFF5F5F5);

  static const List<String> _emergencyTypes = [
    'Natural Disasters',
    'Earthquake',
    'Flood',
    'Storm'
    'Other',
  ];

  static const List<String> _severityLevels = ['Low', 'Medium', 'High'];

  // ── Dispose
  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // ── Submit
  Future<void> _handleSubmit() async {

    // Validate form
    if (!_formKey.currentState!.validate()) return;

    if (_selectedEmergencyType == null) {
      _showSnackBar('Please select an emergency type.', isError: true);
      return;
    }

    // Check Location Permission
    final status = await Permission.location.status;

    if (!status.isGranted) {
      final granted = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const GpsAccessScreen()),
      );

      if (granted != true) return;
    }

    // Check Internet
    final result = await Connectivity().checkConnectivity();
    final isOnline = result != ConnectivityResult.none;

    if (!mounted) return;

    // Navigate based on condition
    if (isOnline) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ReportStatusScreen()),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const OfflineStatusScreen()),
      );
    }
  }

void _showSnackBar(String message, {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red : _primaryGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}

// ── Build
@override
Widget build(BuildContext context) {
  return Scaffold(
      backgroundColor: _bgColor,
      appBar: _buildAppBar(context),
  body: SafeArea(
  child: Form(
  key: _formKey,
  child: SingleChildScrollView(
  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
  child: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
  _buildSubtitle(),
  const SizedBox(height: 24),
  _buildLabel('Your Name'),
  const SizedBox(height: 8),
  _buildTextField(
  controller: _nameController,
  hint: 'Enter your full name',
  keyboardType: TextInputType.name,
  validator: (v) =>
  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
  ),
  const SizedBox(height: 20),
  _buildLabel('Phone Number'),
  const SizedBox(height: 8),
  _buildTextField(
  controller: _phoneController,
  hint: 'Enter your phone number',
  keyboardType: TextInputType.phone,
  validator: (v) {
  if (v == null || v.trim().isEmpty) return 'Phone number is required';
  if (v.trim().length < 7) return 'Enter a valid phone number';
  return null;
  },
  ),
  const SizedBox(height: 20),
  _buildLabel('Emergency Type'),
  const SizedBox(height: 8),
  _buildDropdown(),
  const SizedBox(height: 20),
  _buildLabel('Description of Incident'),
  const SizedBox(height: 8),
  _buildDescriptionField(),
  const SizedBox(height: 20),
  _buildLabel('Severity Level'),
  const SizedBox(height: 12),
  _buildSeverityRow(),
  const SizedBox(height: 24),
  _buildLabel('Your Current Location (Auto Detected)'),
  const SizedBox(height: 8),
  _buildLocationTile(),
  const SizedBox(height: 32),
  _buildSubmitButton(),
  const SizedBox(height: 16),
  ],
  ),
  ),
  ),
  ),
  );
}

// ── AppBar
PreferredSizeWidget _buildAppBar(BuildContext context) {
  return AppBar(
    backgroundColor: _bgColor,
    elevation: 0,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87),
      onPressed: () => Navigator.pop(context),
    ),
    title: const Text(
      'Manual Emergency Reporting',
      style: TextStyle(
        color: Colors.black87,
        fontWeight: FontWeight.bold,
        fontSize: 18,
      ),
    ),
    centerTitle: false,
  );
}

// ── Subtitle
Widget _buildSubtitle() {
  return const Text(
    'Please provide details of the incident.',
    style: TextStyle(
      color: Colors.black54,
      fontSize: 14,
    ),
  );
}

// ── Label
Widget _buildLabel(String text) {
  return Text(
    text,
    style: const TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 15,
      color: Colors.black87,
    ),
  );
}

// ── Text Field
Widget _buildTextField({
  required TextEditingController controller,
  required String hint,
  TextInputType keyboardType = TextInputType.text,
  String? Function(String?)? validator,
}) {
  return TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    style: const TextStyle(fontSize: 14, color: Colors.black87),
    validator: validator,
    decoration: _inputDecoration(hint),
  );
}

// ── Dropdown
Widget _buildDropdown() {
  return DropdownButtonFormField<String>(
    value: _selectedEmergencyType,
    hint: const Text(
      'Select type of emergency',
      style: TextStyle(color: Colors.black45, fontSize: 14),
    ),
    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.black45),
    isExpanded: true,
    decoration: _inputDecoration(null),
    items: _emergencyTypes
        .map(
          (type) => DropdownMenuItem(
        value: type,
        child: Text(type, style: const TextStyle(fontSize: 14)),
      ),
    )
        .toList(),
    onChanged: (val) => setState(() => _selectedEmergencyType = val),
    validator: (v) => v == null ? 'Please select an emergency type' : null,
  );
}

// ── Description Field
Widget _buildDescriptionField() {
  return TextFormField(
    controller: _descriptionController,
    maxLines: 5,
    minLines: 4,
    keyboardType: TextInputType.multiline,
    style: const TextStyle(fontSize: 14, color: Colors.black87),
    validator: (v) =>
    (v == null || v.trim().isEmpty) ? 'Description is required' : null,
    decoration: _inputDecoration('Provide a detailed description'),
  );
}

// ── Severity Row
Widget _buildSeverityRow() {
  return Row(
    children: _severityLevels.map((level) {
      final isSelected = _severityLevel == level;
      return Padding(
        padding: const EdgeInsets.only(right: 24),
        child:GestureDetector(
          onTap: () => setState(() => _severityLevel = level),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Radio<String>(
                value: level,
                groupValue: _severityLevel,
                activeColor: _primaryGreen,
                onChanged: (val) => setState(() => _severityLevel = val!),
              ),
              Text(
                level,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                  isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? _primaryGreen : Colors.black54,
                ),
              ),
            ],
          ),
        )
      );
    }).toList(),
  );
}

// ── Location Tile ─────────────────────────────────────────────────────────
Widget _buildLocationTile() {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: _lightGreen,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _borderGreen),
    ),
    child: Row(
      children: [
        const Icon(Icons.location_on_rounded, color: _primaryGreen, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            _autoDetectedLocation,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    ),
  );
}

// ── Submit Button
  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        onPressed: _handleSubmit,
        child: const Text(
          'Submit Emergency Report',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

// ── Shared Input Decoration
InputDecoration _inputDecoration(String? hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: _hintGreen, fontSize: 14),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _borderGreen, width: 1.2),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _primaryGreen, width: 1.8),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.red, width: 1.2),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.red, width: 1.8),
    ),
  );
}
}