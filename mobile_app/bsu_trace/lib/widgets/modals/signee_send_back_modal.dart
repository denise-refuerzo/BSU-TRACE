// lib/widgets/modals/signee_send_back_modal.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../theme/app_theme.dart';
import '../../config.dart';
import '../../services/session_manager.dart';

class SigneeSendBackModal extends StatefulWidget {
  final Map<String, dynamic> document;
  const SigneeSendBackModal({super.key, required this.document});

  @override
  State<SigneeSendBackModal> createState() => _SigneeSendBackModalState();
}

class _SigneeSendBackModalState extends State<SigneeSendBackModal> {
  final TextEditingController _commentController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submitSendBack() async {
    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide a reason for the revision.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final String qrCode = widget.document['qr_code'] ?? '';
    final userId = SessionManager().userId;

    try {
      final response = await http.put(
        Uri.parse('${AppConfig.baseUrl}/documents/$qrCode/send-back'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'reason': _commentController.text.trim(),
          'signeeUserId': userId,
        }),
      );

      if (response.statusCode == 200 && mounted) {
        Navigator.pop(context); // Close Send Back Modal
        Navigator.pop(context, true); // Close Details Modal and signal refresh
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document returned for revision.')),
        );
      } else {
        throw Exception('Failed to send back');
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error connecting to server.')),
        );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: const Color(0xFFFFFDFD),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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

            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(
                    Icons.arrow_back,
                    color: AppTheme.primaryRed,
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Send Back',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Enter specific reason detailing why this documentation is being sent back to the originator for modifications.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 24),

            // --- REASON TEXT FIELD (Replaces Dropdown) ---
            const Text(
              'Reason for Return (Revision Notes Required)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _commentController,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: 'Be specific about required changes...',
                hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
                filled: true,
                fillColor: Colors.red.shade50.withValues(alpha: 0.5),
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

            ElevatedButton(
              onPressed: _isLoading ? null : _submitSendBack,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryRed,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Return for Revision',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
