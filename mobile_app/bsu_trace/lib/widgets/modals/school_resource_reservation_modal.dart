import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class SchoolResourceReservationModal extends StatelessWidget {
  const SchoolResourceReservationModal({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      backgroundColor: const Color(0xFFFFF8F8), // Light pinkish background tint
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- HEADER ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'SCHOOL RESOURCE\nRESERVATION',
                    style: TextStyle(
                      color: AppTheme.primaryRed,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      height: 1.3, // Line height for multi-line title
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Colors.black87, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // --- FORM FIELDS ---
            _buildLabel('Title'),
            _buildTextField(hint: 'Maintenance / Event Name'),
            const SizedBox(height: 16),

            _buildLabel('Date'),
            _buildTextField(
              hint: 'dd/mm/yyyy', 
              suffixIcon: Icons.calendar_today_outlined,
            ),
            const SizedBox(height: 16),

            _buildLabel('Start Time'),
            _buildTextField(
              hint: '--:-- --', 
              suffixIcon: Icons.access_time,
            ),
            const SizedBox(height: 16),

            _buildLabel('End Time'),
            _buildTextField(
              hint: '--:-- --', 
              suffixIcon: Icons.access_time,
            ),
            const SizedBox(height: 16),

            _buildLabel('Purpose'),
            _buildTextField(
              hint: 'Describe the purpose of the\nreservation',
              maxLines: 3, // Taller input for text area
            ),
            const SizedBox(height: 32),

            // --- SUBMIT BUTTON ---
            ElevatedButton(
              onPressed: () {
                // Handle submission logic
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryRed,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                elevation: 0,
              ),
              child: const Text(
                'SUBMIT',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- REUSABLE FORM WIDGETS ---

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildTextField({required String hint, IconData? suffixIcon, int maxLines = 1}) {
    return TextField(
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black54, fontSize: 14),
        suffixIcon: suffixIcon != null ? Icon(suffixIcon, color: Colors.black87, size: 20) : null,
        filled: true,
        fillColor: Colors.white, // White inputs contrasting with pink background
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: Colors.red.shade100),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppTheme.primaryRed),
        ),
      ),
    );
  }
}