// lib/widgets/modals/signee_history_details_modal.dart
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class SigneeHistoryDetailsModal extends StatelessWidget {
  final Map<String, dynamic> document;

  const SigneeHistoryDetailsModal({super.key, required this.document});

  @override
  Widget build(BuildContext context) {
    // Extract dynamic data from the document map
    final String qrCode = document['qr_code'] ?? 'N/A';
    final String title = document['title'] ?? 'No Title';
    final String formType = document['form_type'] ?? 'N/A';
    final String originOffice = document['origin_office'] ?? 'N/A';
    
    final String rawStatus = document['status'] ?? 'Processed';
    final String status = rawStatus.isEmpty ? 'Processed' : rawStatus[0].toUpperCase() + rawStatus.substring(1);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // --- HEADER ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'HISTORY RECORD: $qrCode', 
                        style: const TextStyle(color: Colors.black54, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title, 
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, height: 1.3, color: Colors.black87),
                      ),
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

            // --- INFO CARDS ---
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

            // --- PROCESSING ROUTE ---
            const Text(
              'PROCESSING TIMELINE',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54, letterSpacing: 0.5),
            ),
            const SizedBox(height: 16),
            
            _buildTimelineStep(
              dotColor: Colors.green,
              lineColor: Colors.green.shade300,
              title: 'Initial Submission',
              titleColor: Colors.black87,
              subtitle: 'Completed',
              isLast: false,
            ),
            _buildTimelineStep(
              dotColor: Colors.green,
              lineColor: Colors.green.shade300,
              title: 'Processed by Office',
              titleColor: Colors.black87,
              subtitle: 'Verified',
              isLast: false,
            ),
            _buildTimelineStep(
              dotColor: Colors.green,
              lineColor: Colors.transparent,
              title: 'Signee Action',
              titleColor: Colors.black87,
              subtitle: 'Status: $status',
              isLast: true,
            ),
            
            const SizedBox(height: 20),
            Divider(color: Colors.grey.shade200, thickness: 1),
            const SizedBox(height: 20),

            // --- ACTION BUTTONS ---
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Downloading digital copy...')),
                  );
                },
                icon: const Icon(Icons.download_outlined, color: Colors.white, size: 20),
                label: const Text('Download Record', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryRed,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black54, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 13, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildRequestorCard(String name, String initials) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('REQUESTOR', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black54, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: Colors.grey.shade300,
                child: Text(initials, style: const TextStyle(fontSize: 10, color: Colors.black87, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Text(name, style: const TextStyle(fontSize: 14, color: Colors.black87)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineStep({
    required Color dotColor,
    required Color lineColor,
    required String title,
    required Color titleColor,
    required String subtitle,
    required bool isLast,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                child: Center(
                  child: Icon(Icons.check, size: 10, color: Colors.white),
                ),
              ),
              if (!isLast)
                Expanded(child: Container(width: 2, color: lineColor)),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: titleColor)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}