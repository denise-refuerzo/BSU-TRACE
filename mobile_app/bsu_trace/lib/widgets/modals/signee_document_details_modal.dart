// lib/widgets/modals/signee_document_details_modal.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../theme/app_theme.dart';
import '../../config.dart';
import 'signee_send_back_modal.dart';
import 'signee_ad_hoc_routing_modal.dart';

class SigneeDocumentDetailsModal extends StatefulWidget {
  final Map<String, dynamic> document;

  const SigneeDocumentDetailsModal({super.key, required this.document});

  @override
  State<SigneeDocumentDetailsModal> createState() => _SigneeDocumentDetailsModalState();
}

class _SigneeDocumentDetailsModalState extends State<SigneeDocumentDetailsModal> {
  bool _isSigning = false;

  Future<void> _signDocument() async {
    setState(() => _isSigning = true);
    final String qrCode = widget.document['qr_code'] ?? '';

    try {
      final response = await http.put(Uri.parse('${AppConfig.baseUrl}/documents/$qrCode/sign'));

      if (response.statusCode == 200) {
        if (!mounted) return;
        // Pop and return 'true' to signal the parent screen to refresh immediately
        Navigator.pop(context, true); 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Document $qrCode successfully signed!'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      } else {
        throw Exception('Server error');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSigning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Network error. Failed to sign the document.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String qrCode = widget.document['qr_code'] ?? 'N/A';
    final String title = widget.document['title'] ?? 'No Title';
    final String formType = widget.document['form_type'] ?? 'N/A';
    final String originOffice = widget.document['origin_office'] ?? 'N/A';
    final String rawStatus = widget.document['status'] ?? 'Pending';
    final String status = rawStatus.isEmpty ? 'Pending' : rawStatus[0].toUpperCase() + rawStatus.substring(1);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: const Color(0xFFFFFDFD),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ID: $qrCode', style: const TextStyle(color: AppTheme.primaryRed, fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, height: 1.3, color: Colors.black87)),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Colors.black54),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _buildInfoCard('FORM TYPE', formType)),
                const SizedBox(width: 12),
                Expanded(child: _buildInfoCard('ORIGIN OFFICE', originOffice)),
              ],
            ),
            const SizedBox(height: 12),
            _buildRequestorCard('System Originator', 'SO'),
            const SizedBox(height: 32),
            const Text('PROCESSING ROUTE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54, letterSpacing: 0.5)),
            const SizedBox(height: 16),
            _buildTimelineStep(dotColor: Colors.green, hasOuterRing: false, lineColor: Colors.grey.shade300, title: 'Initial Submission', titleColor: Colors.black87, subtitle: 'Completed', isLast: false),
            _buildTimelineStep(dotColor: AppTheme.primaryRed, hasOuterRing: true, lineColor: Colors.grey.shade300, title: 'Current Step', titleColor: AppTheme.primaryRed, subtitle: 'Status: $status', isLast: false),
            _buildTimelineStep(dotColor: Colors.red.shade100, hasOuterRing: false, lineColor: Colors.transparent, title: 'Final Approval', titleColor: Colors.black38, subtitle: 'Next in queue', isLast: true),
            const SizedBox(height: 8),
            Divider(color: Colors.red.shade100, thickness: 1),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => showDialog(context: context, builder: (context) => const SigneeAdHocRoutingModal()),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), side: const BorderSide(color: AppTheme.primaryRed), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    child: const Text('Ad-hoc Routing', style: TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => showDialog(context: context, builder: (context) => const SigneeSendBackModal()),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), side: const BorderSide(color: AppTheme.primaryRed), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    child: const Text('Send Back', style: TextStyle(color: AppTheme.primaryRed, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Replaced the simple button with our new State-driven loading button
            ElevatedButton(
              onPressed: _isSigning ? null : _signDocument,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryRed,
                disabledBackgroundColor: Colors.red.shade200,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: _isSigning
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Sign Document', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String label, String value) {
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.red.shade50.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(8)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black54, letterSpacing: 0.5)), const SizedBox(height: 6), Text(value, style: const TextStyle(fontSize: 13, color: Colors.black87))]));
  }

  Widget _buildRequestorCard(String name, String initials) {
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.red.shade50.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(8)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('REQUESTOR', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black54, letterSpacing: 0.5)), const SizedBox(height: 8), Row(children: [CircleAvatar(radius: 14, backgroundColor: Colors.red.shade200, child: Text(initials, style: const TextStyle(fontSize: 10, color: AppTheme.primaryRed, fontWeight: FontWeight.bold))), const SizedBox(width: 12), Text(name, style: const TextStyle(fontSize: 14, color: Colors.black87))])]));
  }

  Widget _buildTimelineStep({required Color dotColor, required bool hasOuterRing, required Color lineColor, required String title, required Color titleColor, required String subtitle, required bool isLast}) {
    return IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Column(children: [Container(width: 16, height: 16, decoration: BoxDecoration(shape: BoxShape.circle, color: hasOuterRing ? Colors.white : dotColor, border: hasOuterRing ? Border.all(color: Colors.red.shade100, width: 3) : null), child: hasOuterRing ? Center(child: Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor))) : null), if (!isLast) Expanded(child: Container(width: 2, color: lineColor))]), const SizedBox(width: 16), Expanded(child: Padding(padding: const EdgeInsets.only(bottom: 24.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: titleColor)), const SizedBox(height: 2), Text(subtitle, style: TextStyle(fontSize: 11, color: isLast ? Colors.black38 : Colors.black54))])))]));
  }
}