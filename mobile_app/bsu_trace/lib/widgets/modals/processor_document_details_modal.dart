// lib/widgets/modals/processor_document_details_modal.dart
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class ProcessorDocumentDetailsModal extends StatelessWidget {
  const ProcessorDocumentDetailsModal({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text('Official Transcript Request', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: Colors.black54)),
              ],
            ),
            const Text('TR-2023-00412', style: TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),

            // Info Section
            Row(
              children: [
                Expanded(child: _buildInfo('FORM TYPE', 'Form 137-A')),
                Expanded(child: _buildInfo('STATUS', 'Incoming', isStatus: true)),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfo('ORIGINATING OFFICE', 'Registrar Office'),
            const SizedBox(height: 24),

            // QR Placeholder
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
              child: Column(
                children: [
                  Container(height: 120, width: 120, color: Colors.white, child: const Icon(Icons.qr_code, size: 80)),
                  const SizedBox(height: 12),
                  const Text('Scan to authenticate document copy', style: TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed, padding: const EdgeInsets.symmetric(vertical: 16)),
              child: const Text('Ad-hoc Verification', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), side: const BorderSide(color: AppTheme.primaryRed)),
              child: const Text('Download Digital Copy', style: TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfo(String label, String val, {bool isStatus = false}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text(val, style: TextStyle(fontWeight: FontWeight.bold, color: isStatus ? AppTheme.primaryRed : Colors.black)),
    ],
  );
}