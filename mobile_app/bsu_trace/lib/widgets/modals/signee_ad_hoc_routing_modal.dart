// lib/widgets/modals/signee_ad_hoc_routing_modal.dart
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class SigneeAdHocRoutingModal extends StatelessWidget {
  const SigneeAdHocRoutingModal({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: const Color(0xFFFFFDFD), // Soft warm white/pinkish
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- DRAG HANDLE ---
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // --- HEADER ---
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back, color: AppTheme.primaryRed),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Ad-hoc Routing',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // --- SUBTITLE ---
            const Text(
              'Route this document to an office not in the standard workflow.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 24),

            // --- TARGET OFFICE DROPDOWN ---
            const Text(
              'Target Office',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.shade50.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  hint: const Text('Select Office...', style: TextStyle(fontSize: 14, color: Colors.black87)),
                  icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black54),
                  items: const [
                    DropdownMenuItem(
                      value: 'Legal Office',
                      child: Text('Legal Office', style: TextStyle(fontSize: 14)),
                    ),
                    DropdownMenuItem(
                      value: 'University President',
                      child: Text('University President', style: TextStyle(fontSize: 14)),
                    ),
                    DropdownMenuItem(
                      value: 'Quality Assurance',
                      child: Text('Quality Assurance', style: TextStyle(fontSize: 14)),
                    ),
                  ],
                  onChanged: (value) {},
                ),
              ),
            ),
            const SizedBox(height: 24),

            // --- REASON TEXT FIELD ---
            const Text(
              'Reason for Routing',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            TextField(
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Enter reason...',
                hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
                filled: true,
                fillColor: Colors.red.shade50.withOpacity(0.5),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.red.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.primaryRed),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // --- SUBMIT BUTTON ---
            ElevatedButton(
              onPressed: () {
                // Popping twice returns the user to the Pending Approvals list
                Navigator.pop(context); // Close the "Ad-hoc Routing" modal
                Navigator.pop(context); // Close the "Document Details" modal
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryRed,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: const Text(
                'Forward Document',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}