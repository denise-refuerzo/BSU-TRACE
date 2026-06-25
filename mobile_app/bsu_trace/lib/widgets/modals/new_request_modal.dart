import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; 
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../theme/app_theme.dart';
import '../../config.dart';
import '../../services/session_manager.dart';

class NewRequestModal extends StatefulWidget {
  const NewRequestModal({super.key});

  @override
  State<NewRequestModal> createState() => _NewRequestModalState();
}

class _NewRequestModalState extends State<NewRequestModal> {
  final TextEditingController _purposeController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  String _selectedResourceType = 'Vehicle';
  
  // Logic to determine if "Today" is selected
  bool get _isToday {
    if (_selectedDate == null) return false;
    final now = DateTime.now();
    return _selectedDate!.year == now.year && 
           _selectedDate!.month == now.month && 
           _selectedDate!.day == now.day;
  }

  // Dynamic list of resources based on date
  List<String> get _resourceTypes {
    List<String> types = ['Vehicle', 'Multimedia Room', 'Gymnasium'];
    if (_isToday) {
      types.addAll(['Stackable Chairs', 'Folding Table']);
    }
    return types;
  }

  bool _isSubmitting = false;

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
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        // Safety: If date changes and the currently selected type is no longer valid, reset it
        if (!_resourceTypes.contains(_selectedResourceType)) {
          _selectedResourceType = 'Vehicle';
        }
      });
    }
  }

  Future<void> _pickTime(bool isStart) async {
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: AppTheme.primaryRed)),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) _startTime = picked;
        else _endTime = picked;
      });
    }
  }

  String _formatTimeForDb(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('HH:mm:00').format(dt);
  }

  Future<void> _submitRequest() async {
    if (_purposeController.text.trim().isEmpty || _selectedDate == null || _startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
      );
      return;
    }

    final userId = SessionManager().userId;
    if (userId == null) return;

    setState(() => _isSubmitting = true);

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/scheduler/bookings'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'u_id': userId,
          'booking_type': _selectedResourceType,
          'reservation_date': DateFormat('yyyy-MM-dd').format(_selectedDate!),
          'purpose': _purposeController.text.trim(),
          'destination': _purposeController.text.trim(),
          'start_time': _formatTimeForDb(_startTime!),
          'end_time': _formatTimeForDb(_endTime!),
          'asset_name': _selectedResourceType, // Sends the specific type directly
        }),
      );

      if (response.statusCode == 201) {
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Schedule request submitted!', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green),
          );
        }
      } else {
        String errorMessage = 'Failed to create booking';
        try {
          final errorResponse = json.decode(response.body);
          errorMessage = errorResponse['error'] ?? errorMessage;
        } catch (_) { }
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _purposeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('New Schedule Request', style: TextStyle(color: AppTheme.primaryRed, fontSize: 20, fontWeight: FontWeight.bold)),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Colors.grey),
                )
              ],
            ),
            const SizedBox(height: 20),

            const Text('Resource Type', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedResourceType,
              items: _resourceTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
              onChanged: (val) => setState(() => _selectedResourceType = val!),
              decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
            ),
            const SizedBox(height: 16),
            
            Text(_selectedResourceType == 'Vehicle' ? 'Destination / Purpose' : 'Event Purpose', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(controller: _purposeController, decoration: const InputDecoration(hintText: 'Enter details...', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8))),
            const SizedBox(height: 16),

            const Text('Date', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _pickDate,
                style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16)),
                child: Text(_selectedDate == null ? 'Select Date (dd/mm/yyyy)' : DateFormat('MMM dd, yyyy').format(_selectedDate!), style: TextStyle(color: _selectedDate == null ? Colors.grey : Colors.black87)),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Start Time', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => _pickTime(true),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: Text(_startTime == null ? '--:--' : _startTime!.format(context), style: TextStyle(color: _startTime == null ? Colors.grey : Colors.black87)),
                    ),
                  ]),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('End Time', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => _pickTime(false),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: Text(_endTime == null ? '--:--' : _endTime!.format(context), style: TextStyle(color: _endTime == null ? Colors.grey : Colors.black87)),
                    ),
                  ]),
                ),
              ],
            ),
            const SizedBox(height: 32),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), side: BorderSide(color: Colors.grey.shade400), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    child: const Text('Cancel', style: TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold)),
                  )
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitRequest,
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    child: _isSubmitting 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Submit Request', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}