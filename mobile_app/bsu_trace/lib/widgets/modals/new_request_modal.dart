import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Add 'intl' package to pubspec.yaml for date formatting
import '../../theme/app_theme.dart';

class NewRequestModal extends StatefulWidget {
  const NewRequestModal({super.key});

  @override
  State<NewRequestModal> createState() => _NewRequestModalState();
}

class _NewRequestModalState extends State<NewRequestModal> {
  final TextEditingController _purposeController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String _selectedVehicle = 'Van (12 seats)';

  final List<String> _vehicleTypes = ['Van (12 seats)', 'Sedan', 'Pickup', 'SUV'];

  Future<void> _pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: AppTheme.primaryRed)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: AppTheme.primaryRed)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('New Request: Vehicles', style: TextStyle(color: AppTheme.primaryRed, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            
            // Purpose Input
            const Text('Destination / Purpose', style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(controller: _purposeController, decoration: const InputDecoration(hintText: 'Enter purpose...', border: OutlineInputBorder())),
            const SizedBox(height: 16),

            // Row for Date and Time
            Row(
              children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Date', style: TextStyle(fontWeight: FontWeight.bold)),
                    OutlinedButton(
                      onPressed: _pickDate,
                      child: Text(_selectedDate == null ? 'dd/mm/yyyy' : DateFormat('dd/MM/yyyy').format(_selectedDate!)),
                    ),
                  ]),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Time', style: TextStyle(fontWeight: FontWeight.bold)),
                    OutlinedButton(
                      onPressed: _pickTime,
                      child: Text(_selectedTime == null ? '--:-- --' : _selectedTime!.format(context)),
                    ),
                  ]),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Vehicle Dropdown
            const Text('Preferred Vehicle Type', style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButtonFormField<String>(
              value: _selectedVehicle,
              items: _vehicleTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
              onChanged: (val) => setState(() => _selectedVehicle = val!),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // TODO: Add API logic here
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const Text('Submit Request', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}