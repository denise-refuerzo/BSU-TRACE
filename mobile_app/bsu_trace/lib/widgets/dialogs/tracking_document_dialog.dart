import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class TrackingDocumentDialog extends StatefulWidget {
  const TrackingDocumentDialog({super.key});
  @override
  State<TrackingDocumentDialog> createState() => _TrackingDocumentDialogState();
}

class _TrackingDocumentDialogState extends State<TrackingDocumentDialog> {
  bool _isVerified = false;
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('New Document', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextField(decoration: const InputDecoration(labelText: 'Document Title')),
            const SizedBox(height: 20),
            CheckboxListTile(
              title: const Text('Verify accuracy'),
              value: _isVerified,
              onChanged: (val) => setState(() => _isVerified = val!),
              activeColor: AppTheme.primaryRed,
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRed),
              child: const Text('Submit', style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }
}