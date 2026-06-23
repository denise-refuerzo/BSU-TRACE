import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class VehicleRequestModal extends StatefulWidget {
  const VehicleRequestModal({super.key});

  @override
  State<VehicleRequestModal> createState() => _VehicleRequestModalState();
}

class _VehicleRequestModalState extends State<VehicleRequestModal> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      // This ensures the modal moves up when the keyboard opens
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Modal Handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.red.shade200, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 24),
              
              const Text('New Request: Vehicles', 
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryRed), 
                textAlign: TextAlign.center
              ),
              const SizedBox(height: 24),

              _buildFormLabel('Destination / Purpose'),
              const SizedBox(height: 8),
              _buildTextField('Enter purpose...'),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(child: _buildColumnField('Date', 'dd/mm/yyyy', Icons.calendar_today_outlined)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildColumnField('Time', '--:--', Icons.access_time)),
                ],
              ),
              const SizedBox(height: 20),

              _buildFormLabel('Preferred Vehicle Type'),
              const SizedBox(height: 8),
              _buildDropdown('Van (12 seats)'),
              
              const SizedBox(height: 32),
              
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryRed,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                ),
                child: const Text('Submit Request', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormLabel(String text) => Text(text, style: TextStyle(fontSize: 14, color: Colors.grey.shade700));

  Widget _buildTextField(String hint) => TextField(decoration: _inputDecoration(hint, null));

  Widget _buildColumnField(String label, String hint, IconData icon) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [_buildFormLabel(label), const SizedBox(height: 8), TextField(decoration: _inputDecoration(hint, icon))]
  );

  Widget _buildDropdown(String hint) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.brown.shade300)),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(hint, style: const TextStyle(color: Colors.black87)), const Icon(Icons.keyboard_arrow_down, color: Colors.grey)])
  );

  InputDecoration _inputDecoration(String hint, IconData? suffixIcon) => InputDecoration(
    hintText: hint, 
    hintStyle: const TextStyle(color: Colors.grey), 
    suffixIcon: suffixIcon != null ? Icon(suffixIcon, color: Colors.black87, size: 20) : null,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), 
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.brown.shade300)), 
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.primaryRed)), 
    filled: true, fillColor: Colors.white
  );
}