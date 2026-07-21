import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../theme/app_theme.dart';
import '../../config.dart';

class SchoolResourceReservationModal extends StatefulWidget {
  final int userId;

  const SchoolResourceReservationModal({super.key, required this.userId});

  @override
  State<SchoolResourceReservationModal> createState() => _SchoolResourceReservationModalState();
}

class _SchoolResourceReservationModalState extends State<SchoolResourceReservationModal> {
  final _titleController = TextEditingController();
  final _dateController = TextEditingController();
  final _startTimeController = TextEditingController();
  final _endTimeController = TextEditingController();
  final _purposeController = TextEditingController();
  String _selectedAsset = 'Gymnasium';
  bool _isLoading = false;

  Future<void> _submitBooking() async {
    if (_titleController.text.isEmpty || _dateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/scheduler/bookings'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'u_id': widget.userId,
          'booking_type': _selectedAsset,
          'reservation_date': _dateController.text,
          'purpose': _titleController.text,
          'destination': _purposeController.text,
          'start_time': _startTimeController.text.isEmpty ? '08:00:00' : _startTimeController.text,
          'end_time': _endTimeController.text.isEmpty ? '17:00:00' : _endTimeController.text,
          'asset_name': _selectedAsset,
        }),
      );

      if (response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('School resource reservation created successfully!')),
          );
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          final errBody = json.decode(response.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${errBody['error'] ?? 'Failed to submit'}')),
          );
        }
      }
    } catch (e) {
      debugPrint('Submission error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      backgroundColor: const Color(0xFFFFF8F8),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text('SCHOOL RESOURCE\nRESERVATION',
                    style: TextStyle(color: AppTheme.primaryRed, fontSize: 18, fontWeight: FontWeight.bold, height: 1.3),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Colors.black87, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildLabel('Resource Type'),
            DropdownButtonFormField<String>(
              value: _selectedAsset,
              items: ['Gymnasium', 'Multimedia Room', 'Van', 'Stackable Chairs', 'Folding Table']
                  .map((asset) => DropdownMenuItem(value: asset, child: Text(asset)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedAsset = val ?? 'Gymnasium'),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.red.shade100)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppTheme.primaryRed)),
              ),
            ),
            const SizedBox(height: 16),
            _buildLabel('Title / Event Name'),
            _buildTextField(controller: _titleController, hint: 'Maintenance / Event Name'),
            const SizedBox(height: 16),
            _buildLabel('Date (YYYY-MM-DD)'),
            _buildTextField(controller: _dateController, hint: '2026-07-25', suffixIcon: Icons.calendar_today_outlined),
            const SizedBox(height: 16),
            _buildLabel('Start Time (HH:MM)'),
            _buildTextField(controller: _startTimeController, hint: '08:00', suffixIcon: Icons.access_time),
            const SizedBox(height: 16),
            _buildLabel('End Time (HH:MM)'),
            _buildTextField(controller: _endTimeController, hint: '17:00', suffixIcon: Icons.access_time),
            const SizedBox(height: 16),
            _buildLabel('Purpose / Destination'),
            _buildTextField(controller: _purposeController, hint: 'Describe the purpose of the reservation', maxLines: 3),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _submitBooking,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryRed,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                elevation: 0,
              ),
              child: _isLoading 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('SUBMIT', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String hint, IconData? suffixIcon, int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black54, fontSize: 14),
        suffixIcon: suffixIcon != null ? Icon(suffixIcon, color: Colors.black87, size: 20) : null,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.red.shade100)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppTheme.primaryRed)),
      ),
    );
  }
}