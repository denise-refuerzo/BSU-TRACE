import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class DocumentDetailsModal extends StatelessWidget {
  const DocumentDetailsModal({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: const Color(0xFFFCF6F6),
      insetPadding: const EdgeInsets.all(20),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Document Details', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryRed)),
                GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: Colors.black54))
              ],
            ),
            const SizedBox(height: 24),
            _buildLabel('TITLE'),
            const Text('Annual Procurement Plan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            
            Row(
              children: [
                Expanded(child: _buildInfoItem('STATUS', 'PENDING', isBadge: true)),
                Expanded(child: _buildInfoItem('FORM TYPE', 'APP-2024-001')),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _buildInfoItem('ORIGINATING OFFICE', 'Procurement Office')),
                Expanded(child: _buildInfoItem('NEXT OFFICE', 'Budget Office')),
              ],
            ),
            const SizedBox(height: 24),
            
            _buildLabel('TRACKING QR CODE'),
            const SizedBox(height: 12),
            Container(height: 150, decoration: BoxDecoration(border: Border.all(color: Colors.red.shade100), color: Colors.white), child: const Center(child: Text('QR Code Placeholder'))),
            
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: const Text('Close Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5));
  
  Widget _buildInfoItem(String label, String value, {bool isBadge = false}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildLabel(label),
      const SizedBox(height: 8),
      isBadge 
        ? Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(4)), child: Text(value, style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold, fontSize: 12)))
        : Text(value, style: const TextStyle(fontWeight: FontWeight.bold))
    ]
  );
}