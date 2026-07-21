import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../theme/app_theme.dart';
import '../../config.dart';

class VehicleReservationModal extends StatefulWidget {
  final Map<String, dynamic>? bookingData;

  const VehicleReservationModal({super.key, this.bookingData});

  @override
  State<VehicleReservationModal> createState() => _VehicleReservationModalState();
}

class _VehicleReservationModalState extends State<VehicleReservationModal> {
  bool _formChecked = false;
  bool _intentChecked = false;
  bool _idChecked = false;
  bool _clearanceChecked = false;
  bool _isSubmitting = false;

  bool get _isAllChecked => _formChecked && _intentChecked && _idChecked && _clearanceChecked;

  Future<void> _confirmReservation() async {
    if (widget.bookingData == null || widget.bookingData!['booking_id'] == null) {
      Navigator.pop(context);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final bookingId = widget.bookingData!['booking_id'];
      final response = await http.put(
        Uri.parse('${AppConfig.baseUrl}/scheduler/bookings/$bookingId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'status': 'Confirmed'}),
      );

      if (response.statusCode == 200) {
        if (mounted) Navigator.pop(context, true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to confirm reservation')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error confirming vehicle reservation: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestor = widget.bookingData?['requestor'] ?? 'Varsity Sports Council';
    final vehicle = widget.bookingData?['destination'] ?? widget.bookingData?['purpose'] ?? 'TOYOTA COASTER #4';
    final rawDate = widget.bookingData?['reservation_date'];
    final date = rawDate != null ? rawDate.toString().split('T')[0] : 'Dec 10, 2023';
    final startTime = widget.bookingData?['start_time'] ?? '';
    final endTime = widget.bookingData?['end_time'] ?? '';
    final timeStr = (startTime.isNotEmpty && endTime.isNotEmpty) ? ' | $startTime - $endTime' : '';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              color: AppTheme.primaryRed,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Vehicle Reservation', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(vehicle, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context), 
                    child: const Icon(Icons.close, color: Colors.white, size: 24)
                  )
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildInfo('REQUESTOR', requestor)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildInfo('DATE & TIME', '$date$timeStr')),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50.withValues(alpha: 0.5), 
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade100)
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.assignment_outlined, size: 16, color: Colors.black54),
                            SizedBox(width: 8),
                            Text('DOCUMENT CHECKLIST', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black54, letterSpacing: 0.5)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildCheckboxRow('Approved Request Form', _formChecked, (v) => setState(() => _formChecked = v!)),
                        _buildCheckboxRow('Letter of Intent', _intentChecked, (v) => setState(() => _intentChecked = v!)),
                        _buildCheckboxRow('Student/Faculty ID Photocopy', _idChecked, (v) => setState(() => _idChecked = v!)),
                        _buildCheckboxRow('Facility Clearance Slip', _clearanceChecked, (v) => setState(() => _clearanceChecked = v!)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.grey.shade200, thickness: 1),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context), 
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.primaryRed), 
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                      ), 
                      child: const Text('Cancel', style: TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold))
                    )
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (_isAllChecked && !_isSubmitting) ? _confirmReservation : null, 
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isAllChecked ? AppTheme.primaryRed : Colors.grey.shade400,
                        disabledBackgroundColor: Colors.grey.shade400,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                      ), 
                      child: _isSubmitting 
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Confirm Reservation', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))
                    )
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start, 
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.bold, letterSpacing: 0.5)), 
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87, height: 1.4)),
      ]
    );
  }
  
  Widget _buildCheckboxRow(String label, bool value, ValueChanged<bool?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 20,
            width: 20,
            child: Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: AppTheme.primaryRed,
              side: BorderSide(color: Colors.grey.shade400, width: 1.5),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 1.0),
              child: Text(label, style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.3)),
            ),
          ),
        ],
      ),
    );
  }
}